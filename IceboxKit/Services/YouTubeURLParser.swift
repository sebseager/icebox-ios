//
//  YouTubeURLParser.swift
//  Icebox
//

import Foundation

/// Recognizes YouTube video URLs in every common dress and extracts the
/// 11-character video ID. Everything here works from the URL alone — no
/// network, no API, no account (spec §3.1).
nonisolated enum YouTubeURLParser {

    private static let videoHosts: Set<String> = [
        "youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com",
        "youtube-nocookie.com", "www.youtube-nocookie.com",
    ]
    private static let shortHost = "youtu.be"

    private static func isValidID(_ id: String) -> Bool {
        id.count == 11 && id.allSatisfy { $0.isLetter && $0.isASCII || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    /// The video ID, or nil if this isn't a single-video YouTube URL.
    static func videoID(from url: URL) -> String? {
        guard let host = url.host()?.lowercased() else { return nil }
        let pathParts = url.path().split(separator: "/").map(String.init)

        if host == shortHost {
            guard let first = pathParts.first, isValidID(first) else { return nil }
            return first
        }

        guard videoHosts.contains(host) else { return nil }

        if pathParts.first == "watch" {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let v = components.queryItems?.first(where: { $0.name == "v" })?.value,
                  isValidID(v)
            else { return nil }
            return v
        }

        if pathParts.count >= 2, ["shorts", "live", "embed", "v"].contains(pathParts[0]), isValidID(pathParts[1]) {
            return pathParts[1]
        }
        return nil
    }

    static func isYouTubeVideoURL(_ url: URL) -> Bool {
        videoID(from: url) != nil
    }

    /// Parses the IDs out of an account-free `watch_videos` playlist URL.
    /// Returns nil if the URL isn't one; invalid IDs are dropped.
    static func videoIDs(fromWatchVideosURL url: URL) -> [String]? {
        guard let host = url.host()?.lowercased(),
              videoHosts.contains(host) || host == shortHost,
              url.path() == "/watch_videos",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let list = components.queryItems?.first(where: { $0.name == "video_ids" })?.value
        else { return nil }
        return list.split(separator: ",").map(String.init).filter(isValidID)
    }

    static func watchURL(videoID: String) -> URL {
        URL(string: "https://www.youtube.com/watch?v=\(videoID)")!
    }

    static func thumbnailURL(videoID: String) -> URL {
        URL(string: "https://i.ytimg.com/vi/\(videoID)/hqdefault.jpg")!
    }

    /// The public oEmbed endpoint — metadata with no key and no account.
    static func oEmbedURL(videoID: String) -> URL {
        URL(string: "https://www.youtube.com/oembed?format=json&url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3D\(videoID)")!
    }
}
