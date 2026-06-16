import Foundation

struct AppPersistence {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    var supportDirectory: URL {
        get throws {
            let base = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directory = base.appending(path: "LiquidLLM", directoryHint: .isDirectory)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        }
    }

    var modelsDirectory: URL {
        get throws {
            let directory = try supportDirectory.appending(path: "Models", directoryHint: .isDirectory)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        }
    }

    private var dataURL: URL {
        get throws {
            try supportDirectory.appending(path: "state.json")
        }
    }

    func load() throws -> PersistedAppData? {
        let url = try dataURL
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try decoder.decode(PersistedAppData.self, from: data)
    }

    func save(_ data: PersistedAppData) throws {
        let url = try dataURL
        let payload = try encoder.encode(data)
        try payload.write(to: url, options: [.atomic])
    }
}
