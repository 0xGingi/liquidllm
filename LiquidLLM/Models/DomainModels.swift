import Foundation

enum MessageRole: String, Codable, CaseIterable, Sendable {
    case user
    case assistant
    case system
}

struct ChatMessage: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var role: MessageRole
    var text: String
    var createdAt: Date
    var tokenCount: Int?
    var isStreaming: Bool

    init(
        id: UUID = UUID(),
        role: MessageRole,
        text: String,
        createdAt: Date = Date(),
        tokenCount: Int? = nil,
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.tokenCount = tokenCount
        self.isStreaming = isStreaming
    }
}

struct ChatThread: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var messages: [ChatMessage]
    var selectedModelID: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "New chat",
        messages: [ChatMessage] = [],
        selectedModelID: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.selectedModelID = selectedModelID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum LocalModelRuntime: String, Codable, Sendable {
    case appleFoundation
    case coreAIBundle
    case downloadedFiles
}

enum LocalModelStatus: String, Codable, Sendable {
    case ready
    case downloading
    case unavailable
    case failed
}

struct CoreAICompatibility: Codable, Equatable, Sendable {
    var isRunnableLanguageModel: Bool
    var kind: String?
    var displayName: String?
    var tokenizer: String?
    var maxContextLength: Int?
    var assetCount: Int
    var functionNames: [String]
    var notes: [String]

    static let system = CoreAICompatibility(
        isRunnableLanguageModel: true,
        kind: "system",
        displayName: "Apple Foundation Model",
        tokenizer: nil,
        maxContextLength: 4096,
        assetCount: 0,
        functionNames: [],
        notes: ["Built into Apple Intelligence through Foundation Models."]
    )
}

struct LocalModel: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var repoID: String?
    var displayName: String
    var subtitle: String
    var localPath: String?
    var runtime: LocalModelRuntime
    var status: LocalModelStatus
    var bytesOnDisk: Int64
    var createdAt: Date
    var lastUsedAt: Date?
    var compatibility: CoreAICompatibility

    static let appleFoundation = LocalModel(
        id: "apple.foundation.default",
        repoID: nil,
        displayName: "Apple Foundation",
        subtitle: "On-device system language model",
        localPath: nil,
        runtime: .appleFoundation,
        status: .ready,
        bytesOnDisk: 0,
        createdAt: Date(),
        compatibility: .system
    )
}

struct AppSettings: Codable, Equatable, Sendable {
    var systemPrompt: String
    var temperature: Double
    var maximumTokens: Int
    var huggingFaceToken: String

    static let `default` = AppSettings(
        systemPrompt: "You are Liquid, a concise local assistant. Prefer practical answers, disclose uncertainty, and keep private data on device.",
        temperature: 0.7,
        maximumTokens: 768,
        huggingFaceToken: ""
    )
}

struct HuggingFaceModel: Identifiable, Decodable, Hashable, Sendable {
    let id: String
    let author: String?
    let downloads: Int?
    let likes: Int?
    let tags: [String]?
    let pipelineTag: String?
    let lastModified: String?
    let siblings: [HuggingFaceFile]?

    enum CodingKeys: String, CodingKey {
        case id
        case modelID = "modelId"
        case author
        case downloads
        case likes
        case tags
        case pipelineTag = "pipeline_tag"
        case lastModified
        case siblings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .modelID)
            ?? container.decode(String.self, forKey: .id)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        downloads = try container.decodeIfPresent(Int.self, forKey: .downloads)
        likes = try container.decodeIfPresent(Int.self, forKey: .likes)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        pipelineTag = try container.decodeIfPresent(String.self, forKey: .pipelineTag)
        lastModified = try container.decodeIfPresent(String.self, forKey: .lastModified)
        siblings = try container.decodeIfPresent([HuggingFaceFile].self, forKey: .siblings)
    }

    init(
        id: String,
        author: String? = nil,
        downloads: Int? = nil,
        likes: Int? = nil,
        tags: [String]? = nil,
        pipelineTag: String? = nil,
        lastModified: String? = nil,
        siblings: [HuggingFaceFile]? = nil
    ) {
        self.id = id
        self.author = author
        self.downloads = downloads
        self.likes = likes
        self.tags = tags
        self.pipelineTag = pipelineTag
        self.lastModified = lastModified
        self.siblings = siblings
    }
}

struct HuggingFaceFile: Codable, Hashable, Sendable {
    let rfilename: String
    let size: Int64?
}

struct ModelDownloadProgress: Equatable, Sendable {
    var repoID: String
    var completedFiles: Int
    var totalFiles: Int
    var currentFile: String

    var fractionCompleted: Double {
        guard totalFiles > 0 else { return 0 }
        return min(1, Double(completedFiles) / Double(totalFiles))
    }
}

struct PersistedAppData: Codable, Sendable {
    var threads: [ChatThread]
    var localModels: [LocalModel]
    var settings: AppSettings
    var selectedThreadID: UUID?
}
