import Foundation

enum HuggingFaceError: LocalizedError {
    case invalidURL
    case badStatus(Int)
    case noDownloadableFiles

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The Hugging Face URL could not be built."
        case .badStatus(let status):
            "Hugging Face returned HTTP \(status)."
        case .noDownloadableFiles:
            "This repository does not expose Core AI bundle files or tokenizer resources."
        }
    }
}

struct HuggingFaceClient: Sendable {
    func searchModels(query: String, token: String?) async throws -> [HuggingFaceModel] {
        var components = URLComponents(string: "https://huggingface.co/api/models")
        components?.queryItems = [
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "filter", value: "text-generation"),
            URLQueryItem(name: "sort", value: "downloads"),
            URLQueryItem(name: "direction", value: "-1"),
            URLQueryItem(name: "limit", value: "24")
        ]
        guard let url = components?.url else { throw HuggingFaceError.invalidURL }
        return try await decode([HuggingFaceModel].self, from: url, token: token)
    }

    func modelInfo(repoID: String, token: String?) async throws -> HuggingFaceModel {
        guard let encodedRepo = repoID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://huggingface.co/api/models/\(encodedRepo)") else {
            throw HuggingFaceError.invalidURL
        }
        return try await decode(HuggingFaceModel.self, from: url, token: token)
    }

    func resolveURL(repoID: String, file: String) throws -> URL {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove("/")
        let encodedFile = file
            .split(separator: "/")
            .map { String($0).addingPercentEncoding(withAllowedCharacters: allowed) ?? String($0) }
            .joined(separator: "/")

        guard let encodedRepo = repoID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://huggingface.co/\(encodedRepo)/resolve/main/\(encodedFile)") else {
            throw HuggingFaceError.invalidURL
        }
        return url
    }

    func request(for url: URL, token: String?) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        if let token, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func decode<T: Decodable>(_ type: T.Type, from url: URL, token: String?) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request(for: url, token: token))
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw HuggingFaceError.badStatus(http.statusCode)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
