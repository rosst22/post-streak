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
    @Published private(set) var posts: [Post] = []
    @Published private(set) var friends: [Friend] = []
    @Published private(set) var profile: MeProfile?
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

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-screenshot-mode") {
            loadScreenshotData()
            return
        }
        #endif

        Task { await restore() }
    }

    #if DEBUG
    private func loadScreenshotData() {
        let calendar = Calendar(identifier: .gregorian)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let today = calendar.startOfDay(for: Date())
        let heatmap = (0..<365).reversed().compactMap { offset -> DayCount? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let count = offset % 11 == 0 ? 3 : (offset % 5 == 0 ? 1 : 0)
            return DayCount(date: formatter.string(from: date), count: count)
        }

        let screenshotUserID = UUID()
        let jordanID = UUID()
        let mayaID = UUID()
        authState = .signedIn
        stats = Stats(
            currentStreak: 8,
            longestStreak: 12,
            weeklyTarget: 5,
            currentWeekPosts: 4,
            postsPerWeek: [],
            heatmap: heatmap
        )
        profile = MeProfile(
            id: screenshotUserID,
            displayName: "Ross",
            friendCode: "A7C4F91D2B6E",
            timezone: "America/Toronto",
            weeklyTarget: 5
        )
        friends = [
            Friend(friendshipID: UUID(), userID: jordanID, displayName: "Jordan", status: .accepted, direction: .incoming),
            Friend(friendshipID: UUID(), userID: mayaID, displayName: "Maya", status: .pending, direction: .incoming),
            Friend(friendshipID: UUID(), userID: UUID(), displayName: "Alex", status: .pending, direction: .outgoing)
        ]
        feed = [
            Post(
                id: UUID(), userID: jordanID, platform: .youtube,
                postedAt: Date().addingTimeInterval(-3_600), format: .video,
                url: URL(string: "https://youtube.com/watch?v=creator"),
                title: "A week of building in public", author: Author(id: jordanID, displayName: "Jordan")
            ),
            Post(
                id: UUID(), userID: mayaID, platform: .instagram,
                postedAt: Date().addingTimeInterval(-10_800), format: .reel,
                url: URL(string: "https://instagram.com/reel/creator"),
                title: "Behind the scenes", author: Author(id: mayaID, displayName: "Maya")
            )
        ]
        posts = [
            Post(
                id: UUID(), userID: screenshotUserID, platform: .instagram,
                postedAt: Date().addingTimeInterval(-7_200), format: .reel,
                url: nil, title: nil, author: nil
            ),
            Post(
                id: UUID(), userID: screenshotUserID, platform: .youtube,
                postedAt: Date().addingTimeInterval(-86_400), format: .video,
                url: nil, title: nil, author: nil
            )
        ]
    }
    #endif

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
            posts = []
            friends = []
            profile = nil
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
            posts = []
            friends = []
            profile = nil
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
            async let friendsRequest = client.friends()
            async let profileRequest = client.me()
            async let postsRequest = client.posts()
            (stats, feed, friends, profile, posts) = try await (
                statsRequest,
                feedRequest,
                friendsRequest,
                profileRequest,
                postsRequest
            )
        } catch {
            handle(error)
        }
    }

    func quickLog(_ platform: Platform) async {
        await perform {
            let post = try await client.createPost(platform: platform)
            posts.insert(post, at: 0)
            stats = try await client.stats()
            successMessage = "Logged to \(platform.label)"
        }
    }

    func delete(_ post: Post) async {
        await perform {
            try await client.deletePost(id: post.id)
            posts.removeAll { $0.id == post.id }
            stats = try await client.stats()
            successMessage = "Post removed"
        }
    }

    func updateProfile(displayName: String, weeklyTarget: Int) async {
        await perform {
            profile = try await client.updateMe(
                displayName: displayName,
                timezone: TimeZone.current.identifier,
                weeklyTarget: weeklyTarget
            )
            stats = try await client.stats()
            successMessage = "Settings saved"
        }
    }

    func sendFriendRequest(code: String) async {
        await perform {
            let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let friend = try await client.requestFriend(code: normalized)
            friends.removeAll { $0.friendshipID == friend.friendshipID }
            friends.insert(friend, at: 0)
            successMessage = "Friend request sent"
        }
    }

    func accept(_ friend: Friend) async {
        await perform {
            let accepted = try await client.acceptFriend(friendshipID: friend.friendshipID)
            friends.removeAll { $0.friendshipID == accepted.friendshipID }
            friends.insert(accepted, at: 0)
            successMessage = "You are now friends"
            feed = try await client.feed()
        }
    }

    func remove(_ friend: Friend) async {
        await perform {
            try await client.removeFriendship(id: friend.friendshipID)
            friends.removeAll { $0.friendshipID == friend.friendshipID }
            feed = try await client.feed()
            successMessage = friend.status == .accepted ? "Friend removed" : "Request removed"
        }
    }

    private func perform(_ action: () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await action()
        } catch {
            handle(error)
        }
    }

    private func handle(_ error: Error) {
        if case AppError.sessionExpired = error {
            authState = .signedOut
            stats = nil
            feed = []
            posts = []
            friends = []
            profile = nil
        }
        errorMessage = error.localizedDescription
    }
}
