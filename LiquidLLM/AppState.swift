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
    @Published var modelSearchText = "Qwen Core AI"
    @Published var modelResults: [HuggingFaceModel] = []
    @Published var isSearchingModels = false
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
              let model = allModels.first(where: { $0.id == modelID }) else {
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
            } else {
                threads = [Self.seedThread()]
                selectedThreadID = threads.first?.id
            }
        } catch {
            threads = [Self.seedThread()]
            selectedThreadID = threads.first?.id
            statusMessage = "Could not load saved state: \(error.localizedDescription)"
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
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    func createThread() {
        let thread = ChatThread()
        threads.insert(thread, at: 0)
        selectedThreadID = thread.id
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
                    self.updateAssistantMessage(
                        id: assistantID,
                        text: "I could not generate a response.\n\n\(error.localizedDescription)",
                        isStreaming: false
                    )
                    self.isGenerating = false
                    self.statusMessage = error.localizedDescription
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
                    self.statusMessage = error.localizedDescription
                }
            }
        }
    }

    func download(_ model: HuggingFaceModel) {
        let repoID = model.id
        let token = settings.huggingFaceToken
        let root: URL
        do {
            root = try persistence.modelsDirectory
        } catch {
            statusMessage = error.localizedDescription
            return
        }

        statusMessage = "Preparing \(model.id)"
        let service = HuggingFaceDownloadService()
        Task { [weak self, service, repoID, token, root] in
            guard let self else { return }
            do {
                let localModel = try await service.downloadCoreAIBundle(
                    repoID: repoID,
                    token: token,
                    destinationRoot: root
                ) { progress in
                    self.downloadProgress[repoID] = progress
                    self.statusMessage = "Downloading \(progress.currentFile)"
                }

                await MainActor.run {
                    self.upsert(localModel)
                    self.downloadProgress[repoID] = nil
                    self.statusMessage = localModel.compatibility.isRunnableLanguageModel
                        ? "\(localModel.displayName) is ready"
                        : "\(localModel.displayName) downloaded but is not a Core AI chat bundle"
                    self.saveSoon()
                }
            } catch {
                await MainActor.run {
                    self.downloadProgress[repoID] = nil
                    self.statusMessage = error.localizedDescription
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
