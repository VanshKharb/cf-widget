import Foundation

enum CodeforcesError: LocalizedError, Equatable {
    case emptyHandle
    case handleNotFound(String)
    case rateLimited
    case apiFailure(String)
    case badResponse
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .emptyHandle:
            return "Enter a Codeforces handle first."
        case .handleNotFound(let handle):
            return "No Codeforces user named “\(handle)”."
        case .rateLimited:
            return "Codeforces is rate limiting requests. Try again in a minute."
        case .apiFailure(let message):
            return message
        case .badResponse:
            return "Codeforces returned an unexpected response."
        case .transport(let message):
            return message
        }
    }
}

/// Thin async wrapper around the public Codeforces API. No key, no login: every
/// endpoint used here is world-readable.
struct CodeforcesAPI: Sendable {
    static let shared = CodeforcesAPI()

    private let baseURL = URL(string: "https://codeforces.com/api/")!
    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
            return
        }

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 75
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = ["User-Agent": "CFWidget/1.0 (iOS)"]
        self.session = URLSession(configuration: configuration)
    }

    func userInfo(handle: String) async throws -> CFUser {
        let users: [CFUser] = try await get(
            "user.info",
            query: [URLQueryItem(name: "handles", value: handle)],
            as: [CFUser].self
        )
        guard let user = users.first else { throw CodeforcesError.handleNotFound(handle) }
        return user
    }

    func ratingHistory(handle: String) async throws -> [CFRatingChange] {
        try await get(
            "user.rating",
            query: [URLQueryItem(name: "handle", value: handle)],
            as: [CFRatingChange].self
        )
    }

    /// Submissions are returned newest-first, so `from: 1` plus a `count` gives
    /// the most recent N. The API caps `count` at 10 000.
    func submissions(handle: String, count: Int) async throws -> [CFSubmission] {
        let clamped = max(1, min(count, 10_000))
        return try await get(
            "user.status",
            query: [
                URLQueryItem(name: "handle", value: handle),
                URLQueryItem(name: "from", value: "1"),
                URLQueryItem(name: "count", value: String(clamped)),
            ],
            as: [CFSubmission].self
        )
    }

    func contests(gym: Bool = false) async throws -> [CFContest] {
        try await get(
            "contest.list",
            query: [URLQueryItem(name: "gym", value: gym ? "true" : "false")],
            as: [CFContest].self
        )
    }

    // MARK: - Transport

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem], as type: T.Type) async throws -> T {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw CodeforcesError.badResponse
        }
        components.queryItems = query
        guard let url = components.url else { throw CodeforcesError.badResponse }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw CodeforcesError.transport(error.localizedDescription)
        }

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        if statusCode == 429 { throw CodeforcesError.rateLimited }

        // Codeforces reports failures with HTTP 400 *and* a JSON body, so the
        // body is worth decoding even when the status code is an error.
        let envelope: CFEnvelope<T>
        do {
            envelope = try JSONDecoder().decode(CFEnvelope<T>.self, from: data)
        } catch {
            if statusCode != 0 && !(200..<300).contains(statusCode) {
                throw CodeforcesError.apiFailure("Codeforces returned HTTP \(statusCode).")
            }
            throw CodeforcesError.badResponse
        }

        guard envelope.status == "OK", let result = envelope.result else {
            throw Self.mapFailure(comment: envelope.comment, query: query)
        }
        return result
    }

    private static func mapFailure(comment: String?, query: [URLQueryItem]) -> CodeforcesError {
        let message = comment ?? "Unknown Codeforces error."
        let handle = query.first { $0.name == "handle" || $0.name == "handles" }?.value ?? ""

        if message.localizedCaseInsensitiveContains("not found") {
            return .handleNotFound(handle)
        }
        if message.localizedCaseInsensitiveContains("limit") || message.localizedCaseInsensitiveContains("too many") {
            return .rateLimited
        }
        return .apiFailure(message)
    }
}
