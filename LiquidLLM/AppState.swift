import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var threads: [ChatThread] = []
    @Published var selectedThreadID: UUID?
    @Published var localModels: [LocalModel] = [.appleFoundation]
    @Published var settings: AppSettings = .default
    @Published var composerText = ""
    @Published var isGenerating = false
    @Published var modelSearchText = "coreai"
    @Published var modelResults: [HuggingFaceModel] = []
    @Published var isSearchingModels = false
    @Published var modelVariants: [String: [HuggingFaceModelVariant]] = [:]
    @Published var loadingVariantRepoIDs: Set<String> = []
    @Published var downloadProgress: [String: ModelDownloadProgress] = [:]
    @Published var statusMessage = "Ready"

    private let persistence = AppPersistence()
    private let huggingFaceClient = HuggingFaceClient()
    private let runtime = LLMRuntime()
    private var generationTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?

    var selectedThread: ChatThread? {
        guard let selectedThreadID else { return nil }
        return threads.first { $0.id == selectedThreadID }
    }

    var selectedModel: LocalModel {
        guard let modelID = selectedThread?.selectedModelID ?? settingsSelectedModelID,
              let model = allModels.first(where: { $0.id == modelID && $0.status == .ready }) else {
            return .appleFoundation
        }
        return model
    }

    var allModels: [LocalModel] {
        var models = localModels
        if !models.contains(where: { $0.id == LocalModel.appleFoundation.id }) {
            models.insert(.appleFoundation, at: 0)
        }
        return models
    }

    private var settingsSelectedModelID: String? {
        nil
    }

    init() {
        load()
    }

    func load() {
        do {
            if let data = try persistence.load() {
                threads = data.threads.isEmpty ? [Self.seedThread()] : data.threads
                localModels = mergeSystemModel(with: data.localModels)
                settings = data.settings
                selectedThreadID = data.selectedThreadID ?? threads.first?.id
                let recoveredModels = recoverDownloadedModels()
                let refreshedModels = refreshStoredModelCompatibility()
                if recoveredModels || refreshedModels {
                    saveNow()
                }
            } else {
                threads = [Self.seedThread()]
                selectedThreadID = threads.first?.id
                if recoverDownloadedModels() {
                    saveNow()
                }
            }
        } catch {
            threads = [Self.seedThread()]
            selectedThreadID = threads.first?.id
            statusMessage = "Could not load saved state: \(readableErrorDescription(error))"
        }
    }

    func saveSoon() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            self?.saveNow()
        }
    }

    func saveNow() {
        do {
            try persistence.save(PersistedAppData(
                threads: threads,
                localModels: localModels.filter { $0.id != LocalModel.appleFoundation.id },
                settings: settings,
                selectedThreadID: selectedThreadID
            ))
        } catch {
            statusMessage = "Save failed: \(readableErrorDescription(error))"
        }
    }

    func createThread() {
        let thread = ChatThread()
        threads.insert(thread, at: 0)
        selectedThreadID = thread.id
        saveSoon()
    }

    func selectThread(_ id: UUID) {
        guard threads.contains(where: { $0.id == id }) else { return }
        selectedThreadID = id
        saveSoon()
    }

    func deleteSelectedThread() {
        guard let selectedThreadID else { return }
        threads.removeAll { $0.id == selectedThreadID }
        if threads.isEmpty {
            threads = [Self.seedThread()]
        }
        self.selectedThreadID = threads.first?.id
        saveSoon()
    }

    func selectModel(_ model: LocalModel) {
        guard model.status == .ready else {
            statusMessage = model.compatibility.notes.first ?? "\(model.displayName) is not ready."
            return
        }
        guard let index = selectedThreadIndex else { return }
        threads[index].selectedModelID = model.id == LocalModel.appleFoundation.id ? nil : model.id
        threads[index].updatedAt = Date()
        saveSoon()
    }

    func sendComposerMessage() {
        let prompt = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isGenerating, let threadIndex = selectedThreadIndex else { return }
        composerText = ""

        let userMessage = ChatMessage(role: .user, text: prompt)
        let assistantMessage = ChatMessage(role: .assistant, text: "", isStreaming: true)
        threads[threadIndex].messages.append(userMessage)
        threads[threadIndex].messages.append(assistantMessage)
        threads[threadIndex].updatedAt = Date()
        if threads[threadIndex].title == "New chat" {
            threads[threadIndex].title = Self.title(from: prompt)
        }

        let threadID = threads[threadIndex].id
        let assistantID = assistantMessage.id
        let model = selectedModel
        let activeSettings = settings
        isGenerating = true
        statusMessage = "Running \(model.displayName)"
        saveSoon()

        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = await runtime.streamReply(
                    threadID: threadID,
                    model: model,
                    prompt: prompt,
                    settings: activeSettings
                )

                var latest = ""
                for try await partial in stream {
                    latest = partial
                    await MainActor.run {
                        self.updateAssistantMessage(id: assistantID, text: latest, isStreaming: true)
                    }
                }
                await MainActor.run {
                    self.updateAssistantMessage(id: assistantID, text: latest, isStreaming: false)
                    self.isGenerating = false
                    self.statusMessage = "Ready"
                    self.markModelUsed(model)
                    self.saveSoon()
                }
            } catch {
                await MainActor.run {
                    let message = readableErrorDescription(error)
                    self.updateAssistantMessage(
                        id: assistantID,
                        text: "I could not generate a response.\n\n\(message)",
                        isStreaming: false
                    )
                    self.isGenerating = false
                    self.statusMessage = message
                    self.saveSoon()
                }
            }
        }
    }

    func stopGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        statusMessage = "Stopped"
        if let threadIndex = selectedThreadIndex,
           let messageIndex = threads[threadIndex].messages.lastIndex(where: { $0.isStreaming }) {
            threads[threadIndex].messages[messageIndex].isStreaming = false
        }
        saveSoon()
    }

    func searchModels() {
        let query = modelSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isSearchingModels = true
        statusMessage = "Searching Hugging Face"

        Task { [weak self] in
            guard let self else { return }
            do {
                let results = try await huggingFaceClient.searchModels(
                    query: query,
                    token: settings.huggingFaceToken
                )
                await MainActor.run {
                    self.modelResults = results
                    self.isSearchingModels = false
                    self.statusMessage = "\(results.count) models found"
                }
            } catch {
                await MainActor.run {
                    self.isSearchingModels = false
                    self.statusMessage = readableErrorDescription(error)
                }
            }
        }
    }

    func download(_ model: HuggingFaceModel) {
        loadVariants(for: model)
    }

    func loadVariants(for model: HuggingFaceModel) {
        let repoID = model.id
        if modelVariants[repoID] != nil || loadingVariantRepoIDs.contains(repoID) {
            return
        }

        loadingVariantRepoIDs.insert(repoID)
        statusMessage = "Inspecting \(repoID)"
        let token = settings.huggingFaceToken
        let service = HuggingFaceDownloadService()

        Task { [weak self, service, repoID, token] in
            guard let self else { return }
            do {
                let variants = try await service.variants(repoID: repoID, token: token)
                await MainActor.run {
                    self.modelVariants[repoID] = variants
                    self.loadingVariantRepoIDs.remove(repoID)
                    self.statusMessage = variants.isEmpty
                        ? "No Core AI variants found"
                        : "\(variants.count) variants found"
                }
            } catch {
                await MainActor.run {
                    self.loadingVariantRepoIDs.remove(repoID)
                    self.statusMessage = readableErrorDescription(error)
                }
            }
        }
    }

    func download(_ variant: HuggingFaceModelVariant) {
        guard variant.isChatReadyCandidate else {
            statusMessage = "\(variant.displayName) is a standalone .aimodel. This chat path needs a Core AI language bundle."
            return
        }

        let token = settings.huggingFaceToken
        let root: URL
        do {
            root = try persistence.modelsDirectory
        } catch {
            statusMessage = readableErrorDescription(error)
            return
        }

        statusMessage = "Preparing \(variant.displayName)"
        let service = HuggingFaceDownloadService()
        Task { [weak self, service, variant, token, root] in
            guard let self else { return }
            do {
                let localModel = try await service.downloadCoreAIBundle(
                    variant: variant,
                    token: token,
                    destinationRoot: root
                ) { progress in
                    self.downloadProgress[variant.id] = progress
                    self.statusMessage = "Downloading \(progress.currentFile)"
                }

                await MainActor.run {
                    self.upsert(localModel)
                    self.downloadProgress[variant.id] = nil
                    self.statusMessage = localModel.compatibility.isRunnableLanguageModel
                        ? "\(localModel.displayName) is ready"
                        : "\(localModel.displayName) downloaded but is not a Core AI chat bundle"
                    self.saveNow()
                }
            } catch {
                await MainActor.run {
                    self.downloadProgress[variant.id] = nil
                    self.statusMessage = readableErrorDescription(error)
                }
            }
        }
    }

    func deleteModel(_ model: LocalModel) {
        guard model.id != LocalModel.appleFoundation.id else {
            statusMessage = "The Apple Foundation model cannot be deleted."
            return
        }

        if isGenerating, selectedModel.id == model.id {
            stopGeneration()
        }

        let path = model.localPath
        let runtime = runtime
        statusMessage = "Deleting \(model.displayName)"
        Task.detached(priority: .userInitiated) { [weak self, runtime, modelID = model.id, displayName = model.displayName, path] in
            do {
                if let path {
                    let url = URL(filePath: path, directoryHint: .isDirectory)
                    if FileManager.default.fileExists(atPath: url.path) {
                        try FileManager.default.removeItem(at: url)
                    }
                }
                await runtime.reset(modelID: modelID)
                await MainActor.run {
                    guard let self else { return }
                    self.removeDeletedModel(id: modelID)
                    self.statusMessage = "Deleted \(displayName)"
                    self.saveNow()
                }
            } catch {
                await MainActor.run {
                    self?.statusMessage = "Could not delete \(displayName): \(readableErrorDescription(error))"
                }
            }
        }
    }

    private var selectedThreadIndex: Int? {
        guard let selectedThreadID else { return nil }
        return threads.firstIndex { $0.id == selectedThreadID }
    }

    private func updateAssistantMessage(id: UUID, text: String, isStreaming: Bool) {
        guard let threadIndex = selectedThreadIndex,
              let messageIndex = threads[threadIndex].messages.firstIndex(where: { $0.id == id }) else {
            return
        }
        threads[threadIndex].messages[messageIndex].text = text
        threads[threadIndex].messages[messageIndex].isStreaming = isStreaming
        threads[threadIndex].updatedAt = Date()
    }

    private func upsert(_ model: LocalModel) {
        if let index = localModels.firstIndex(where: { $0.id == model.id }) {
            localModels[index] = model
        } else {
            localModels.append(model)
        }
    }

    private func removeDeletedModel(id: String) {
        localModels.removeAll { $0.id == id }
        downloadProgress[id] = nil
        for index in threads.indices where threads[index].selectedModelID == id {
            threads[index].selectedModelID = nil
            threads[index].updatedAt = Date()
        }
    }

    private func refreshStoredModelCompatibility() -> Bool {
        var changed = false
        for index in localModels.indices {
            guard localModels[index].id != LocalModel.appleFoundation.id else {
                continue
            }

            guard let url = resolvedModelDirectory(for: localModels[index]) else {
                continue
            }

            let compatibility = CoreAIModelInspector.inspectBundle(at: url)
            var updated = localModels[index]
            updated.localPath = url.path
            updated.compatibility = compatibility
            updated.bytesOnDisk = HuggingFaceDownloadService.directorySize(at: url)
            if compatibility.isRunnableLanguageModel {
                updated.runtime = .coreAIBundle
                updated.status = .ready
                if let displayName = compatibility.displayName {
                    updated.displayName = displayName
                }
                updated.subtitle = "Core AI language bundle"
            } else {
                updated.runtime = .downloadedFiles
                updated.status = .unavailable
                updated.subtitle = compatibility.notes.first ?? "Invalid Core AI language bundle"
            }

            if updated != localModels[index] {
                localModels[index] = updated
                changed = true
            }
        }
        return changed
    }

    private func recoverDownloadedModels() -> Bool {
        guard let modelsDirectory = try? persistence.modelsDirectory else { return false }

        var changed = false
        var recoveredBundleURLs: [URL] = []
        for bundleURL in downloadedBundleCandidates(in: modelsDirectory) {
            if recoveredBundleURLs.contains(where: { isNestedDirectory(bundleURL, in: $0) }) {
                continue
            }

            let compatibility = CoreAIModelInspector.inspectBundle(at: bundleURL)
            guard compatibility.isRunnableLanguageModel || compatibility.kind == "llm" || compatibility.kind == "vlm" else {
                continue
            }
            guard let identity = modelIdentity(for: bundleURL, under: modelsDirectory) else {
                continue
            }
            guard !localModels.contains(where: { $0.id == identity.id }) else {
                recoveredBundleURLs.append(bundleURL)
                continue
            }

            let bytes = HuggingFaceDownloadService.directorySize(at: bundleURL)
            let model = LocalModel(
                id: identity.id,
                repoID: identity.repoID,
                displayName: compatibility.displayName ?? URL(filePath: identity.rootPath).lastPathComponent,
                subtitle: compatibility.isRunnableLanguageModel
                    ? "Core AI language bundle"
                    : compatibility.notes.first ?? "Downloaded Hugging Face files",
                localPath: bundleURL.path,
                runtime: compatibility.isRunnableLanguageModel ? .coreAIBundle : .downloadedFiles,
                status: compatibility.isRunnableLanguageModel ? .ready : .unavailable,
                bytesOnDisk: bytes,
                createdAt: identity.downloadedAt ?? creationDate(at: bundleURL) ?? Date(),
                compatibility: compatibility
            )
            localModels.append(model)
            recoveredBundleURLs.append(bundleURL)
            changed = true
        }

        return changed
    }

    private func resolvedModelDirectory(for model: LocalModel) -> URL? {
        let storedURL = model.localPath.map {
            URL(filePath: $0, directoryHint: .isDirectory)
        }
        let canonicalURL = canonicalModelDirectory(for: model)

        if let storedURL, hasCoreAIBundleMarker(at: storedURL) {
            return storedURL
        }
        if let canonicalURL, hasCoreAIBundleMarker(at: canonicalURL) {
            return canonicalURL
        }
        if let storedURL, directoryExists(at: storedURL) {
            return storedURL
        }
        if let canonicalURL, directoryExists(at: canonicalURL) {
            return canonicalURL
        }

        return canonicalURL ?? storedURL
    }

    private func canonicalModelDirectory(for model: LocalModel) -> URL? {
        guard let repoID = model.repoID,
              let rootPath = variantRootPath(from: model),
              let modelsDirectory = try? persistence.modelsDirectory else {
            return nil
        }

        return HuggingFaceDownloadService.destinationURL(
            repoID: repoID,
            rootPath: rootPath,
            under: modelsDirectory
        )
    }

    private func downloadedBundleCandidates(in modelsDirectory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: modelsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var candidates: [URL] = []
        for case let url as URL in enumerator {
            if isCoreAIAssetDirectory(url) {
                enumerator.skipDescendants()
                continue
            }

            guard directoryExists(at: url),
                  hasCoreAIBundleMarker(at: url) else {
                continue
            }
            candidates.append(url)
        }

        return candidates.sorted {
            $0.path.count < $1.path.count
        }
    }

    private func modelIdentity(
        for bundleURL: URL,
        under modelsDirectory: URL
    ) -> (id: String, repoID: String, rootPath: String, downloadedAt: Date?)? {
        if let manifest = HuggingFaceDownloadService.manifest(at: bundleURL) {
            return (
                id: manifest.variantID,
                repoID: manifest.repoID,
                rootPath: manifest.rootPath,
                downloadedAt: manifest.downloadedAt
            )
        }

        guard let relativePath = relativePath(from: bundleURL, under: modelsDirectory) else {
            return nil
        }

        let components = relativePath.split(separator: "/").map(String.init)
        guard components.count >= 2 else { return nil }
        let repoID = components[0].replacingOccurrences(of: "__", with: "/")
        let rootPath = components.dropFirst().joined(separator: "/")
        return (
            id: "\(repoID)#\(rootPath)",
            repoID: repoID,
            rootPath: rootPath,
            downloadedAt: nil
        )
    }

    private func variantRootPath(from model: LocalModel) -> String? {
        guard let separator = model.id.firstIndex(of: "#") else { return nil }
        let start = model.id.index(after: separator)
        guard start < model.id.endIndex else { return nil }
        return String(model.id[start...])
    }

    private func relativePath(from child: URL, under parent: URL) -> String? {
        let parentPath = parent.standardizedFileURL.path
        let childPath = child.standardizedFileURL.path
        let prefix = parentPath + "/"
        guard childPath.hasPrefix(prefix) else { return nil }
        return String(childPath.dropFirst(prefix.count))
    }

    private func isNestedDirectory(_ child: URL, in parent: URL) -> Bool {
        let parentPath = parent.standardizedFileURL.path
        let childPath = child.standardizedFileURL.path
        return childPath.hasPrefix(parentPath + "/")
    }

    private func hasCoreAIBundleMarker(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.appending(path: "metadata.json").path)
    }

    private func isCoreAIAssetDirectory(_ url: URL) -> Bool {
        let pathExtension = url.pathExtension.lowercased()
        return pathExtension == "aimodel" || pathExtension == "aimodelc"
    }

    private func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    private func creationDate(at url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.creationDateKey]).creationDate
    }

    private func markModelUsed(_ model: LocalModel) {
        guard let index = localModels.firstIndex(where: { $0.id == model.id }) else { return }
        localModels[index].lastUsedAt = Date()
    }

    private func mergeSystemModel(with models: [LocalModel]) -> [LocalModel] {
        var merged = models.filter { $0.id != LocalModel.appleFoundation.id }
        merged.insert(.appleFoundation, at: 0)
        return merged
    }

    private static func seedThread() -> ChatThread {
        ChatThread(
            title: "Local model lab",
            messages: [
                ChatMessage(
                    role: .assistant,
                    text: "Choose Apple Foundation or download a Core AI-ready model bundle from Hugging Face, then start chatting. Everything runs through local iOS model APIs."
                )
            ]
        )
    }

    private static func title(from prompt: String) -> String {
        let words = prompt.split(separator: " ").prefix(5).joined(separator: " ")
        return words.isEmpty ? "New chat" : words
    }
}
