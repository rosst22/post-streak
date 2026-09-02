import Foundation

struct AppConfiguration: Sendable {
    let apiBaseURL: URL
    let supabaseURL: URL
    let supabasePublishableKey: String
    let keychainAccessGroup: String

    static func load(bundle: Bundle = .main) throws -> AppConfiguration {
        func value(_ key: String) throws -> String {
            guard let value = bundle.object(forInfoDictionaryKey: key) as? String,
                  !value.isEmpty,
                  !value.contains("$(") else {
                throw AppError.configuration("Missing \(key) in Config.xcconfig")
            }
            return value
        }

        guard let apiURL = URL(string: try value("APIBaseURL")),
              let supabaseURL = URL(string: try value("SupabaseURL")) else {
            throw AppError.configuration("APIBaseURL or SupabaseURL is not a valid URL")
        }

        return AppConfiguration(
            apiBaseURL: apiURL,
            supabaseURL: supabaseURL,
            supabasePublishableKey: try value("SupabasePublishableKey"),
            keychainAccessGroup: try value("KeychainAccessGroup")
        )
    }
}

enum AppError: LocalizedError {
    case configuration(String)
    case notSignedIn
    case invalidResponse
    case server(String)
    case keychain(OSStatus)
    case emailConfirmationRequired
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .configuration(let message), .server(let message): message
        case .notSignedIn: "Sign in before logging a post."
        case .invalidResponse: "The server returned an unreadable response."
        case .keychain(let status): "Could not access the saved session (\(status))."
        case .emailConfirmationRequired:
            "Check your email if this account is new, then sign in. If you already confirmed it, sign in now."
        case .sessionExpired: "Your session expired. Please sign in again."
        }
    }
}
