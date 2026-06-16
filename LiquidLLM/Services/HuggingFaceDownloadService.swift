import Foundation

struct HuggingFaceDownloadService: Sendable {
    private let client = HuggingFaceClient()

    func downloadCoreAIBundle(
        repoID: String,
        token: String?,
        destinationRoot: URL,
        progress: @escaping @MainActor (ModelDownloadProgress) -> Void
    ) async throws -> LocalModel {
        let info = try await client.modelInfo(repoID: repoID, token: token)
        let files = Self.downloadableFiles(from: info.siblings ?? [])
        guard !files.isEmpty else { throw HuggingFaceError.noDownloadableFiles }

        let destination = destinationRoot.appending(
            path: Self.safeDirectoryName(for: repoID),
            directoryHint: .isDirectory
        )
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        for (index, file) in files.enumerated() {
            await progress(ModelDownloadProgress(
                repoID: repoID,
                completedFiles: index,
                totalFiles: files.count,
                currentFile: file.rfilename
            ))

            let remoteURL = try client.resolveURL(repoID: repoID, file: file.rfilename)
            let request = client.request(for: remoteURL, token: token)
            let (temporaryURL, response) = try await URLSession.shared.download(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw HuggingFaceError.badStatus(http.statusCode)
            }

            let localURL = destination.appending(path: file.rfilename)
            try fileManager.createDirectory(
                at: localURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if fileManager.fileExists(atPath: localURL.path) {
                try fileManager.removeItem(at: localURL)
            }
            try fileManager.moveItem(at: temporaryURL, to: localURL)
        }

        await progress(ModelDownloadProgress(
            repoID: repoID,
            completedFiles: files.count,
            totalFiles: files.count,
            currentFile: "Complete"
        ))

        let compatibility = CoreAIModelInspector.inspectBundle(at: destination)
        let bytes = Self.directorySize(at: destination)
        return LocalModel(
            id: repoID,
            repoID: repoID,
            displayName: compatibility.displayName ?? repoID.components(separatedBy: "/").last ?? repoID,
            subtitle: compatibility.isRunnableLanguageModel ? "Core AI language bundle" : "Downloaded Hugging Face files",
            localPath: destination.path,
            runtime: compatibility.isRunnableLanguageModel ? .coreAIBundle : .downloadedFiles,
            status: compatibility.isRunnableLanguageModel ? .ready : .unavailable,
            bytesOnDisk: bytes,
            createdAt: Date(),
            compatibility: compatibility
        )
    }

    static func downloadableFiles(from files: [HuggingFaceFile]) -> [HuggingFaceFile] {
        let exactNames: Set<String> = [
            "metadata.json",
            "config.json",
            "generation_config.json",
            "tokenizer.json",
            "tokenizer_config.json",
            "special_tokens_map.json",
            "vocab.json",
            "merges.txt",
            "chat_template.jinja"
        ]

        return files.filter { file in
            let path = file.rfilename
            let name = URL(filePath: path).lastPathComponent
            return exactNames.contains(name)
                || path.hasPrefix("tokenizer/")
                || path.hasSuffix(".aimodel")
                || path.contains(".aimodel/")
                || path.hasSuffix(".aimodelc")
                || path.contains(".aimodelc/")
        }
        .sorted { $0.rfilename < $1.rfilename }
    }

    static func safeDirectoryName(for repoID: String) -> String {
        repoID
            .replacingOccurrences(of: "/", with: "__")
            .replacingOccurrences(of: ":", with: "_")
    }

    static func directorySize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        return enumerator.reduce(Int64(0)) { partial, item in
            guard let fileURL = item as? URL,
                  let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) else {
                return partial
            }
            return partial + Int64(values.fileSize ?? 0)
        }
    }
}
