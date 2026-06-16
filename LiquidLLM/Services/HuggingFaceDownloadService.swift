import Foundation

struct HuggingFaceDownloadService: Sendable {
    private let client = HuggingFaceClient()

    func variants(repoID: String, token: String?) async throws -> [HuggingFaceModelVariant] {
        let info = try await client.modelInfo(repoID: repoID, token: token)
        return Self.variants(in: info)
    }

    func downloadCoreAIBundle(
        variant: HuggingFaceModelVariant,
        token: String?,
        destinationRoot: URL,
        progress: @escaping @MainActor (ModelDownloadProgress) -> Void
    ) async throws -> LocalModel {
        guard variant.isChatReadyCandidate else {
            throw HuggingFaceError.noDownloadableFiles
        }

        let files = variant.files
        guard !files.isEmpty else { throw HuggingFaceError.noDownloadableFiles }

        let destination = Self.destinationURL(for: variant, under: destinationRoot)
        let knownTotalBytes = variant.totalBytes
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        var completedBytes: Int64 = 0
        for (index, file) in files.enumerated() {
            let completedBytesBeforeFile = completedBytes
            await progress(ModelDownloadProgress(
                repoID: variant.id,
                completedFiles: index,
                totalFiles: files.count,
                currentFile: file.rfilename,
                completedBytes: completedBytesBeforeFile,
                totalBytes: knownTotalBytes,
                currentFileBytes: 0,
                currentFileTotalBytes: file.size,
                bytesPerSecond: 0
            ))

            let remoteURL = try client.resolveURL(repoID: variant.repoID, file: file.rfilename)
            let request = client.request(for: remoteURL, token: token)
            let temporaryURL = try await Self.download(
                request: request,
                expectedBytes: file.size
            ) { fileBytes, fileTotalBytes, bytesPerSecond in
                Task { @MainActor in
                    progress(ModelDownloadProgress(
                        repoID: variant.id,
                        completedFiles: index,
                        totalFiles: files.count,
                        currentFile: file.rfilename,
                        completedBytes: completedBytesBeforeFile + fileBytes,
                        totalBytes: knownTotalBytes,
                        currentFileBytes: fileBytes,
                        currentFileTotalBytes: fileTotalBytes,
                        bytesPerSecond: bytesPerSecond
                    ))
                }
            }

            let relativePath = Self.relativePath(file.rfilename, under: variant.rootPath)
            let localURL = destination.appending(path: relativePath)
            try fileManager.createDirectory(
                at: localURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if fileManager.fileExists(atPath: localURL.path) {
                try fileManager.removeItem(at: localURL)
            }
            try fileManager.moveItem(at: temporaryURL, to: localURL)
            completedBytes += file.size ?? Self.fileSize(at: localURL)
        }

        await progress(ModelDownloadProgress(
            repoID: variant.id,
            completedFiles: files.count,
            totalFiles: files.count,
            currentFile: "Complete",
            completedBytes: completedBytes,
            totalBytes: knownTotalBytes ?? completedBytes,
            currentFileBytes: 0,
            currentFileTotalBytes: nil,
            bytesPerSecond: 0
        ))

        try? Self.writeManifest(for: variant, to: destination)

        let compatibility = CoreAIModelInspector.inspectBundle(at: destination)
        let bytes = Self.directorySize(at: destination)
        return LocalModel(
            id: variant.id,
            repoID: variant.repoID,
            displayName: compatibility.displayName ?? variant.displayName,
            subtitle: compatibility.isRunnableLanguageModel ? "\(variant.subtitle) from Hugging Face" : "Downloaded Hugging Face files",
            localPath: destination.path,
            runtime: compatibility.isRunnableLanguageModel ? .coreAIBundle : .downloadedFiles,
            status: compatibility.isRunnableLanguageModel ? .ready : .unavailable,
            bytesOnDisk: bytes,
            createdAt: Date(),
            compatibility: compatibility
        )
    }

    static func variants(in model: HuggingFaceModel) -> [HuggingFaceModelVariant] {
        let files = downloadableFiles(from: model.siblings ?? [])
        guard !files.isEmpty else { return [] }

        let languageRoots = Set(files.compactMap { file -> String? in
            guard URL(filePath: file.rfilename).lastPathComponent == "metadata.json" else {
                return nil
            }
            let root = parentDirectory(of: file.rfilename)
            guard !root.isEmpty, !isAssetDirectory(root) else {
                return nil
            }
            return containsModelAsset(in: root, files: files) ? root : nil
        })

        let standaloneAssetRoots = Set(files.compactMap { file -> String? in
            guard let assetRoot = assetRoot(for: file.rfilename) else { return nil }
            let belongsToLanguageBundle = languageRoots.contains { languageRoot in
                isPath(assetRoot, under: languageRoot)
            }
            return belongsToLanguageBundle ? nil : assetRoot
        })

        let languageVariants = languageRoots.map { root in
            makeVariant(
                repoID: model.id,
                rootPath: root,
                kind: .languageBundle,
                files: files.filter { isPath($0.rfilename, under: root) }
            )
        }

        let standaloneVariants = standaloneAssetRoots.map { root in
            makeVariant(
                repoID: model.id,
                rootPath: root,
                kind: .standaloneAsset,
                files: files.filter { isPath($0.rfilename, under: root) }
            )
        }

        return (languageVariants + standaloneVariants).sorted { lhs, rhs in
            let lhsRank = sortRank(lhs)
            let rhsRank = sortRank(rhs)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return lhs.rootPath.localizedStandardCompare(rhs.rootPath) == .orderedAscending
        }
    }

    static func downloadableFiles(from files: [HuggingFaceFile]) -> [HuggingFaceFile] {
        let exactNames: Set<String> = [
            "metadata.json",
            "config.json",
            "generation_config.json",
            "tokenizer.json",
            "tokenizer_config.json",
            "special_tokens_map.json",
            "added_tokens.json",
            "vocab.json",
            "merges.txt",
            "chat_template.jinja"
        ]

        return files.filter { file in
            let path = file.rfilename
            let name = URL(filePath: path).lastPathComponent
            return exactNames.contains(name)
                || path.hasPrefix("tokenizer/")
                || path.contains("/tokenizer/")
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

    static func destinationURL(repoID: String, rootPath: String, under root: URL) -> URL {
        let repoDirectory = root.appending(
            path: safeDirectoryName(for: repoID),
            directoryHint: .isDirectory
        )

        return rootPath
            .split(separator: "/")
            .reduce(repoDirectory) { url, component in
                url.appending(path: safePathComponent(String(component)), directoryHint: .isDirectory)
            }
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

    static func manifest(at directory: URL) -> DownloadedModelManifest? {
        let url = directory.appending(path: DownloadedModelManifest.fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(DownloadedModelManifest.self, from: data)
    }

    private static func download(
        request: URLRequest,
        expectedBytes: Int64?,
        progress: @escaping @Sendable (Int64, Int64?, Double) -> Void
    ) async throws -> URL {
        let temporaryURL = FileManager.default.temporaryDirectory.appending(
            path: "LiquidLLM-\(UUID().uuidString)",
            directoryHint: .notDirectory
        )
        let delegate = ProgressDownloadDelegate(
            temporaryURL: temporaryURL,
            expectedBytes: expectedBytes,
            progress: progress
        )
        let session = URLSession(
            configuration: .default,
            delegate: delegate,
            delegateQueue: nil
        )
        defer { session.finishTasksAndInvalidate() }
        return try await delegate.download(request: request, session: session)
    }

    private static func writeManifest(for variant: HuggingFaceModelVariant, to directory: URL) throws {
        let manifest = DownloadedModelManifest(
            variantID: variant.id,
            repoID: variant.repoID,
            rootPath: variant.rootPath,
            downloadedAt: Date()
        )
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: directory.appending(path: DownloadedModelManifest.fileName), options: [.atomic])
    }

    private static func fileSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }

    private static func makeVariant(
        repoID: String,
        rootPath: String,
        kind: HuggingFaceModelVariantKind,
        files: [HuggingFaceFile]
    ) -> HuggingFaceModelVariant {
        let displayName = URL(filePath: rootPath).lastPathComponent
            .replacingOccurrences(of: ".aimodel", with: "")
            .replacingOccurrences(of: ".aimodelc", with: "")
        let totalBytes = files.compactMap(\.size).isEmpty ? nil : files.compactMap(\.size).reduce(0, +)
        return HuggingFaceModelVariant(
            id: "\(repoID)#\(rootPath)",
            repoID: repoID,
            rootPath: rootPath,
            displayName: displayName,
            kind: kind,
            files: files.sorted { $0.rfilename < $1.rfilename },
            totalBytes: totalBytes
        )
    }

    private static func destinationURL(for variant: HuggingFaceModelVariant, under root: URL) -> URL {
        destinationURL(repoID: variant.repoID, rootPath: variant.rootPath, under: root)
    }

    private static func relativePath(_ path: String, under root: String) -> String {
        guard isPath(path, under: root) else { return path }
        let prefix = root + "/"
        return String(path.dropFirst(prefix.count))
    }

    private static func parentDirectory(of path: String) -> String {
        let components = path.split(separator: "/").map(String.init)
        guard components.count > 1 else { return "" }
        return components.dropLast().joined(separator: "/")
    }

    private static func assetRoot(for path: String) -> String? {
        let components = path.split(separator: "/").map(String.init)
        guard let index = components.firstIndex(where: isAssetDirectory) else { return nil }
        return components.prefix(index + 1).joined(separator: "/")
    }

    private static func isAssetDirectory(_ path: String) -> Bool {
        let lowercased = path.lowercased()
        return lowercased.hasSuffix(".aimodel") || lowercased.hasSuffix(".aimodelc")
    }

    private static func containsModelAsset(in root: String, files: [HuggingFaceFile]) -> Bool {
        files.contains { file in
            guard isPath(file.rfilename, under: root) else { return false }
            return assetRoot(for: file.rfilename) != nil
        }
    }

    private static func isPath(_ path: String, under root: String) -> Bool {
        path == root || path.hasPrefix(root + "/")
    }

    private static func safePathComponent(_ component: String) -> String {
        component
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
    }

    private static func sortRank(_ variant: HuggingFaceModelVariant) -> Int {
        var rank = variant.kind == .languageBundle ? 0 : 100
        let path = variant.rootPath.lowercased()
        if path.hasPrefix("ios") { rank -= 20 }
        if path.contains("gpu-pipelined") { rank -= 10 }
        if path.contains("macos") { rank += 20 }
        return rank
    }
}

struct DownloadedModelManifest: Codable, Equatable, Sendable {
    static let fileName = ".liquid-model.json"

    var variantID: String
    var repoID: String
    var rootPath: String
    var downloadedAt: Date
}

private final class ProgressDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let temporaryURL: URL
    private let expectedBytes: Int64?
    private let progress: @Sendable (Int64, Int64?, Double) -> Void
    private var continuation: CheckedContinuation<URL, Error>?
    private var downloadedURL: URL?
    private var completionError: Error?
    private var lastSampleDate = Date()
    private var lastSampleBytes: Int64 = 0
    private var latestBytesPerSecond: Double = 0

    init(
        temporaryURL: URL,
        expectedBytes: Int64?,
        progress: @escaping @Sendable (Int64, Int64?, Double) -> Void
    ) {
        self.temporaryURL = temporaryURL
        self.expectedBytes = expectedBytes
        self.progress = progress
    }

    func download(request: URLRequest, session: URLSession) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            session.downloadTask(with: request).resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastSampleDate)
        if elapsed >= 0.45 {
            let deltaBytes = max(0, totalBytesWritten - lastSampleBytes)
            latestBytesPerSecond = Double(deltaBytes) / elapsed
            lastSampleDate = now
            lastSampleBytes = totalBytesWritten
        }

        progress(
            totalBytesWritten,
            expectedBytes(from: totalBytesExpectedToWrite),
            latestBytesPerSecond
        )
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        if let http = downloadTask.response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            completionError = HuggingFaceError.badStatus(http.statusCode)
            return
        }

        do {
            if FileManager.default.fileExists(atPath: temporaryURL.path) {
                try FileManager.default.removeItem(at: temporaryURL)
            }
            try FileManager.default.moveItem(at: location, to: temporaryURL)
            downloadedURL = temporaryURL
        } catch {
            completionError = error
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let continuation else { return }
        self.continuation = nil

        if let error {
            continuation.resume(throwing: error)
        } else if let completionError {
            continuation.resume(throwing: completionError)
        } else if let downloadedURL {
            continuation.resume(returning: downloadedURL)
        } else {
            continuation.resume(throwing: HuggingFaceError.noDownloadableFiles)
        }
    }

    private func expectedBytes(from urlSessionValue: Int64) -> Int64? {
        if urlSessionValue > 0 {
            return urlSessionValue
        }
        return expectedBytes
    }
}
