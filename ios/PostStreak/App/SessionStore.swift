import Foundation

@MainActor
final class SessionStore: ObservableObject {
    enum AuthState {
        case checking
        case signedOut
        case signedIn
    }

    @Published private(set) var authState: AuthState = .checking
    @Published private(set) var stats: Stats?
    @Published private(set) var feed: [Post] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    let client: NetworkClient
    let privacyURL: URL
    let termsURL: URL
    let supportURL: URL

    init(client: NetworkClient) {
        self.client = client
        self.privacyURL = client.apiBaseURL.appending(path: "privacy")
        self.termsURL = client.apiBaseURL.appending(path: "terms")
        self.supportURL = client.apiBaseURL.appending(path: "support")
        Task { await restore() }
    }

    func restore() async {
        authState = await client.hasSession() ? .signedIn : .signedOut
        if authState == .signedIn { await refresh() }
    }

    func signIn(email: String, password: String) async {
        await perform {
            try await client.signIn(email: email, password: password)
            authState = .signedIn
            await refresh()
        }
    }

    /// Returns true when Supabase requires the user to continue on the sign-in form.
    @discardableResult
    func signUp(email: String, password: String, weeklyTarget: Int) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await client.signUp(
                email: email,
                password: password,
                timezone: TimeZone.current.identifier,
                weeklyTarget: weeklyTarget
            )
            authState = .signedIn
            await refresh()
            return false
        } catch AppError.emailConfirmationRequired {
            errorMessage = AppError.emailConfirmationRequired.localizedDescription
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func signOut() async {
        do {
            try await client.signOut()
            authState = .signedOut
            stats = nil
            feed = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAccount() async {
        await perform {
            try await client.deleteAccount()
            authState = .signedOut
            stats = nil
            feed = []
            successMessage = nil
        }
    }

    func report(_ post: Post, reason: ReportReason) async {
        await perform {
            try await client.report(postID: post.id, reason: reason)
            successMessage = "Report received"
        }
    }

    func block(_ post: Post) async {
        guard let author = post.author else { return }
        await perform {
            try await client.block(userID: author.id)
            feed.removeAll { $0.userID == author.id }
            successMessage = "User blocked"
        }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let statsRequest = client.stats()
            async let feedRequest = client.feed()
            (stats, feed) = try await (statsRequest, feedRequest)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func quickLog(_ platform: Platform) async {
        await perform {
            try await client.createPost(platform: platform)
            stats = try await client.stats()
            successMessage = "Logged to \(platform.label)"
        }
    }

    private func perform(_ action: () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
