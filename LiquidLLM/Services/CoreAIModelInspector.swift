import CoreAI
import Foundation

enum CoreAIModelInspector {
    static func inspectBundle(at directory: URL) -> CoreAICompatibility {
        var notes: [String] = []
        let metadata = readMetadata(in: directory)
        let assets = findModelAssets(in: directory)
        var functionNames: [String] = []

        for assetURL in assets {
            guard AIModelAsset.isValid(at: assetURL) else {
                notes.append("\(assetURL.lastPathComponent) is not a valid Core AI model asset.")
                continue
            }

            do {
                let asset = try AIModelAsset(contentsOf: assetURL)
                if let summary = try asset.summary(includingStatistics: false) {
                    functionNames.append(contentsOf: summary.functions.map(\.name))
                }
            } catch {
                notes.append("Could not inspect \(assetURL.lastPathComponent): \(error.localizedDescription)")
            }
        }

        if metadata == nil {
            notes.append("metadata.json is missing. CoreAILM needs a Core AI language bundle, not only raw weights.")
        }

        if assets.isEmpty {
            notes.append("No .aimodel or .aimodelc assets were found.")
        }

        let isLLM = metadata?.kind == "llm" || metadata?.kind == "vlm"
        if !isLLM, metadata != nil {
            notes.append("Bundle kind is \(metadata?.kind ?? "unknown"); chat requires llm or vlm.")
        }

        if metadata?.language == nil {
            notes.append("Language metadata is missing; tokenizer and context length cannot be resolved.")
        }

        return CoreAICompatibility(
            isRunnableLanguageModel: isLLM && metadata?.language != nil && !assets.isEmpty,
            kind: metadata?.kind,
            displayName: metadata?.name,
            tokenizer: metadata?.language?.tokenizer,
            maxContextLength: metadata?.language?.maxContextLength,
            assetCount: assets.count,
            functionNames: Array(Set(functionNames)).sorted(),
            notes: notes
        )
    }

    private static func readMetadata(in directory: URL) -> MetadataEnvelope? {
        let url = directory.appending(path: "metadata.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(MetadataEnvelope.self, from: data)
    }

    private static func findModelAssets(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var urls: [URL] = []
        for case let url as URL in enumerator {
            let ext = url.pathExtension.lowercased()
            if ext == "aimodel" || ext == "aimodelc" {
                urls.append(url)
            }
        }
        return urls
    }
}

private struct MetadataEnvelope: Decodable {
    let kind: String?
    let name: String?
    let language: LanguageBlock?
}

private struct LanguageBlock: Decodable {
    let tokenizer: String?
    let maxContextLength: Int?

    enum CodingKeys: String, CodingKey {
        case tokenizer
        case maxContextLength = "max_context_length"
    }
}
