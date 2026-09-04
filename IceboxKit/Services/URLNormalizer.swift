//
//  URLNormalizer.swift
//  Icebox
//

import Foundation

/// Produces a stable key for "same saved thing", so re-saving a link updates
/// the existing item instead of creating a twin. Strips tracking dress and
/// canonicalizes YouTube video URLs.
nonisolated enum URLNormalizer {

    private static let droppedParams: Set<String> = [
        "fbclid", "gclid", "dclid", "msclkid", "igshid", "si", "feature",
        "mc_cid", "mc_eid", "ref_src", "cmpid", "s_kwcid",
    ]

    static func normalized(_ url: URL) -> String {
        if let videoID = YouTubeURLParser.videoID(from: url) {
            return YouTubeURLParser.watchURL(videoID: videoID).absoluteString
        }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        components.fragment = nil

        if let items = components.queryItems {
            let kept = items.filter { item in
                let name = item.name.lowercased()
                return !name.hasPrefix("utm_") && !droppedParams.contains(name)
            }
            components.queryItems = kept.isEmpty ? nil : kept
        }

        if components.path.hasSuffix("/") {
            components.path = String(components.path.dropLast())
        }
        return components.url?.absoluteString ?? url.absoluteString
    }
}
