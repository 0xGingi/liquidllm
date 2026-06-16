import CoreAILanguageModels
import Foundation
import FoundationModels

enum LLMRuntimeError: LocalizedError {
    case missingCoreAIBundle
    case unsupportedDownloadedModel(String)
    case systemModelUnavailable(String)
    case coreAIModelLoadFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingCoreAIBundle:
            "The selected model does not have a local Core AI bundle path."
        case .unsupportedDownloadedModel(let reason):
            "This download cannot run as a local chat model yet. \(reason)"
        case .systemModelUnavailable(let reason):
            "Apple Foundation Model is unavailable. \(reason)"
        case .coreAIModelLoadFailed(let reason):
            "Core AI could not load this model bundle. \(reason)"
        }
    }
}

actor LLMRuntime {
    private struct SessionKey: Hashable {
        var threadID: UUID
        var modelID: String
        var instructionsHash: Int
    }

    private var sessions: [SessionKey: LanguageModelSession] = [:]

    func reset(threadID: UUID) {
        sessions = sessions.filter { $0.key.threadID != threadID }
    }

    func reset(modelID: String) {
        sessions = sessions.filter { $0.key.modelID != modelID }
    }

    func streamReply(
        threadID: UUID,
        model: LocalModel,
        prompt: String,
        settings: AppSettings
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let session = try await session(
                        threadID: threadID,
                        model: model,
                        settings: settings
                    )
                    let options = GenerationOptions(
                        samplingMode: nil,
                        temperature: settings.temperature,
                        maximumResponseTokens: settings.maximumTokens,
                        toolCallingMode: .disallowed
                    )
                    let stream = session.streamResponse(to: prompt, options: options)
                    var emittedSnapshot = false
                    for try await snapshot in stream {
                        emittedSnapshot = true
                        continuation.yield(snapshot.content)
                    }
                    if !emittedSnapshot {
                        let response = try await session.respond(to: prompt, options: options)
                        continuation.yield(response.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func session(
        threadID: UUID,
        model: LocalModel,
        settings: AppSettings
    ) async throws -> LanguageModelSession {
        let key = SessionKey(
            threadID: threadID,
            modelID: model.id,
            instructionsHash: settings.systemPrompt.hashValue
        )
        if let existing = sessions[key] {
            return existing
        }

        let created: LanguageModelSession
        switch model.runtime {
        case .appleFoundation:
            let systemModel = SystemLanguageModel.default
            try validateAvailability(systemModel.availability)
            created = LanguageModelSession(model: systemModel, instructions: settings.systemPrompt)

        case .coreAIBundle:
            guard let path = model.localPath else { throw LLMRuntimeError.missingCoreAIBundle }
            let url = URL(filePath: path, directoryHint: .isDirectory)
            guard FileManager.default.fileExists(atPath: url.appending(path: "metadata.json").path) else {
                throw LLMRuntimeError.coreAIModelLoadFailed("metadata.json was not found at \(url.path).")
            }
            do {
                setenv("COREAI_CHUNK_THRESHOLD", "1", 1)
                let coreModel = try await CoreAILanguageModel(resourcesAt: url)
                created = LanguageModelSession(model: coreModel, instructions: settings.systemPrompt)
            } catch {
                throw LLMRuntimeError.coreAIModelLoadFailed(readableErrorDescription(error))
            }

        case .downloadedFiles:
            let reason = model.compatibility.notes.first ?? "Expected a Core AI language bundle with metadata.json and .aimodel assets."
            throw LLMRuntimeError.unsupportedDownloadedModel(reason)
        }

        created.prewarm()
        sessions[key] = created
        return created
    }

    private func validateAvailability(_ availability: SystemLanguageModel.Availability) throws {
        switch availability {
        case .available:
            return
        case .unavailable(.deviceNotEligible):
            throw LLMRuntimeError.systemModelUnavailable("This device is not eligible for Apple Intelligence.")
        case .unavailable(.appleIntelligenceNotEnabled):
            throw LLMRuntimeError.systemModelUnavailable("Enable Apple Intelligence in Settings, then try again.")
        case .unavailable(.modelNotReady):
            throw LLMRuntimeError.systemModelUnavailable("The system model is still preparing or downloading.")
        @unknown default:
            throw LLMRuntimeError.systemModelUnavailable("The system reported an unknown availability state.")
        }
    }
}
