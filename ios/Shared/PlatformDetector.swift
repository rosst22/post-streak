import Foundation

enum PlatformDetector {
    static func detect(from url: URL) -> Platform {
        let host = (url.host ?? "").lowercased()
        if host == "instagram.com" || host.hasSuffix(".instagram.com") {
            return .instagram
        }
        if host == "tiktok.com" || host.hasSuffix(".tiktok.com") {
            return .tiktok
        }
        if host == "youtube.com" || host.hasSuffix(".youtube.com") || host == "youtu.be" {
            return .youtube
        }
        return .other
    }
}

