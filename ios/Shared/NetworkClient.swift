import Foundation

actor NetworkClient {
    nonisolated let apiBaseURL: URL
    private let configuration: AppConfiguration
    private let keychain: KeychainStore
    private let session: URLSession

    init(
        configuration: AppConfiguration,
        session: URLSession = .shared
    ) {
        self.apiBaseURL = configuration.apiBaseURL
        self.configuration = configuration
        self.keychain = KeychainStore(accessGroup: configuration.keychainAccessGroup)
        self.session = session
    }

    func hasSession() -> Bool {
        (try? keychain.load()) != nil
    }

    func signIn(email: String, password: String) async throws {
        let tokens = try await authRequest(
            path: "auth/v1/token?grant_type=password",
            body: ["email": email, "password": password]
        ).tokens()
        try keychain.save(tokens)
    }

    func signUp(
        email: String,
        password: String,
        timezone: String,
        weeklyTarget: Int
    ) async throws {
        struct SignUpBody: Encodable {
            struct Metadata: Encodable {
                let timezone: String
                let weeklyTarget: Int

                enum CodingKeys: String, CodingKey {
                    case timezone
                    case weeklyTarget = "weekly_target"
                }
            }

            let email: String
            let password: String
            let data: Metadata
        }

        var request = try supabaseRequest(path: "auth/v1/signup", method: "POST")
        request.httpBody = try JSONEncoder().encode(
            SignUpBody(
                email: email,
                password: password,
                data: .init(
                    timezone: timezone,
                    weeklyTarget: weeklyTarget
                )
            )
        )
        let response: SupabaseTokenResponse = try await send(request)
        try keychain.save(response.tokens())
    }

    func signOut() throws {
        try keychain.clear()
    }

    func deleteAccount() async throws {
        let _: ActionResponse = try await apiRequest(path: "me", method: "DELETE")
        try keychain.clear()
    }

    func stats() async throws -> Stats {
        try await apiRequest(path: "me/stats", method: "GET")
    }

    func feed() async throws -> [Post] {
        try await apiRequest(path: "feed", method: "GET")
    }

    func report(postID: UUID, reason: ReportReason) async throws {
        struct Body: Encodable { let reason: ReportReason }
        let _: ActionResponse = try await apiRequest(
            path: "posts/\(postID)/report",
            method: "POST",
            body: Body(reason: reason)
        )
    }

    func block(userID: UUID) async throws {
        struct Body: Encodable {
            let userID: UUID
            enum CodingKeys: String, CodingKey { case userID = "user_id" }
        }
        let _: ActionResponse = try await apiRequest(
            path: "friends/block",
            method: "POST",
            body: Body(userID: userID)
        )
    }

    @discardableResult
    func createPost(
        platform: Platform,
        url: URL? = nil,
        format: PostFormat = .post,
        title: String? = nil
    ) async throws -> Post {
        try await apiRequest(
            path: "posts",
            method: "POST",
            body: PostCreate(
                platform: platform,
                postedAt: nil,
                format: format,
                url: url,
                title: title
            )
        )
    }

    private func validAccessToken() async throws -> String {
        guard var tokens = try keychain.load() else { throw AppError.notSignedIn }
        if tokens.expiresAt <= Date() {
            let refreshed = try await authRequest(
                path: "auth/v1/token?grant_type=refresh_token",
                body: ["refresh_token": tokens.refreshToken]
            )
            tokens = try refreshed.tokens()
            try keychain.save(tokens)
        }
        return tokens.accessToken
    }

    private func authRequest(path: String, body: [String: String]) async throws -> SupabaseTokenResponse {
        var request = try supabaseRequest(path: path, method: "POST")
        request.httpBody = try JSONEncoder().encode(body)
        return try await send(request)
    }

    private func supabaseRequest(path: String, method: String) throws -> URLRequest {
        let url = configuration.supabaseURL.appending(path: path)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw AppError.configuration("Could not construct the Supabase URL")
        }
        // appending(path:) percent-encodes '?', so restore the auth query explicitly.
        if let questionMark = path.firstIndex(of: "?") {
            components.path = configuration.supabaseURL.path + "/" + path[..<questionMark]
            components.percentEncodedQuery = String(path[path.index(after: questionMark)...])
        }
        guard let finalURL = components.url else { throw AppError.invalidResponse }
        var request = URLRequest(url: finalURL)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.supabasePublishableKey, forHTTPHeaderField: "apikey")
        return request
    }

    private func apiRequest<Response: Decodable>(path: String, method: String) async throws -> Response {
        var request = URLRequest(url: configuration.apiBaseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("Bearer \(try await validAccessToken())", forHTTPHeaderField: "Authorization")
        return try await send(request)
    }

    private func apiRequest<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        body: Body
    ) async throws -> Response {
        var request = URLRequest(url: configuration.apiBaseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await validAccessToken())", forHTTPHeaderField: "Authorization")
        request.httpBody = try Self.encoder.encode(body)
        return try await send(request)
    }

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AppError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let error = try? Self.decoder.decode(ServerError.self, from: data)
            throw AppError.server(
                error?.detail ?? error?.message ?? error?.errorDescription ?? "Request failed (\(http.statusCode))"
            )
        }
        do {
            return try Self.decoder.decode(Response.self, from: data)
        } catch {
            throw AppError.invalidResponse
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) { return date }
            let standard = ISO8601DateFormatter()
            standard.formatOptions = [.withInternetDateTime]
            if let date = standard.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Invalid ISO-8601 date"
            )
        }
        return decoder
    }()
}
