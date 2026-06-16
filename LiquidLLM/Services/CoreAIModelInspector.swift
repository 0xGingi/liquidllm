import CoreAI
import CoreAILanguageModels
import Foundation

enum CoreAIModelInspector {
    static func inspectBundle(at directory: URL) -> CoreAICompatibility {
        var notes: [String] = []
        let metadata = readMetadata(in: directory)
        let languageBundle: LanguageBundle?
        do {
            let bundle = try LanguageBundle(at: directory)
            try bundle.bundle.verify()
            languageBundle = bundle
        } catch {
            languageBundle = nil
            notes.append(readableErrorDescription(error))
        }

        let assets = languageBundle.map(declaredAssetURLs(in:)) ?? findModelAssets(in: directory)
        var functionNames: [String] = []
        var invalidAssetCount = 0

        for assetURL in assets {
            guard AIModelAsset.isValid(at: assetURL) else {
                invalidAssetCount += 1
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

        let displayName = languageBundle?.name ?? metadata?.name
        let requiresCustomRuntime = requiresGemmaStaticInputRuntime(
            name: displayName,
            directoryName: directory.lastPathComponent
        )
        if requiresCustomRuntime {
            notes.insert(
                "This Gemma table bundle requires the zoo's custom static-input runtime, not the generic CoreAILanguageModel path.",
                at: 0
            )
        }

        return CoreAICompatibility(
            isRunnableLanguageModel: languageBundle != nil
                && !requiresCustomRuntime
                && !assets.isEmpty
                && invalidAssetCount == 0,
            kind: languageBundle?.bundle.kind.rawValue ?? metadata?.kind,
            displayName: displayName,
            tokenizer: languageBundle?.tokenizer ?? metadata?.language?.tokenizer,
            maxContextLength: languageBundle?.maxContextLength ?? metadata?.language?.maxContextLength,
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

    private static func declaredAssetURLs(in bundle: LanguageBundle) -> [URL] {
        bundle.componentKeys.compactMap { bundle.modelURL(for: $0) }
    }

    private static func requiresGemmaStaticInputRuntime(name: String?, directoryName: String) -> Bool {
        let identifier = "\(name ?? "") \(directoryName)".lowercased()
        return identifier.contains("gemma4") && identifier.contains("_tbl")
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
