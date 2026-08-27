import Foundation

enum Platform: String, Codable, CaseIterable, Identifiable, Sendable {
    case instagram
    case tiktok
    case youtube
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .instagram: "Instagram"
        case .tiktok: "TikTok"
        case .youtube: "YouTube"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .instagram: "camera"
        case .tiktok: "music.note"
        case .youtube: "play.rectangle.fill"
        case .other: "link"
        }
    }
}

enum PostFormat: String, Codable, Sendable {
    case post
    case reel
    case story
    case video
    case short
    case other
}

enum ReportReason: String, Codable, CaseIterable, Identifiable, Sendable {
    case spam
    case harassment
    case hateSpeech = "hate_speech"
    case sexualContent = "sexual_content"
    case violence
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spam: "Spam"
        case .harassment: "Harassment"
        case .hateSpeech: "Hate speech"
        case .sexualContent: "Sexual content"
        case .violence: "Violence or threats"
        case .other: "Other"
        }
    }
}

struct PostCreate: Encodable, Sendable {
    let platform: Platform
    let postedAt: Date?
    let format: PostFormat
    let url: URL?
    let title: String?

    enum CodingKeys: String, CodingKey {
        case platform
        case postedAt = "posted_at"
        case format
        case url
        case title
    }
}

struct Author: Decodable, Sendable {
    let id: UUID
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

struct Post: Decodable, Identifiable, Sendable {
    let id: UUID
    let userID: UUID
    let platform: Platform
    let postedAt: Date
    let format: PostFormat
    let url: URL?
    let title: String?
    let author: Author?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case platform
        case postedAt = "posted_at"
        case format
        case url
        case title
        case author
    }
}

struct WeekCount: Decodable, Sendable {
    let weekStart: String
    let count: Int

    enum CodingKeys: String, CodingKey {
        case weekStart = "week_start"
        case count
    }
}

struct DayCount: Decodable, Identifiable, Sendable {
    let date: String
    let count: Int
    var id: String { date }
}

struct Stats: Decodable, Sendable {
    let currentStreak: Int
    let longestStreak: Int
    let weeklyTarget: Int
    let currentWeekPosts: Int
    let postsPerWeek: [WeekCount]
    let heatmap: [DayCount]

    enum CodingKeys: String, CodingKey {
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case weeklyTarget = "weekly_target"
        case currentWeekPosts = "current_week_posts"
        case postsPerWeek = "posts_per_week"
        case heatmap
    }
}

struct SessionTokens: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

struct SupabaseTokenResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }

    func tokens() throws -> SessionTokens {
        guard let accessToken, let refreshToken, let expiresIn else {
            throw AppError.emailConfirmationRequired
        }
        return SessionTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(expiresIn - 60)
        )
    }
}

struct ServerError: Decodable {
    let detail: String?
    let message: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case detail
        case message
        case errorDescription = "error_description"
    }
}

struct ActionResponse: Decodable, Sendable {
    let message: String
}
