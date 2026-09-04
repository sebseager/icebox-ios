//
//  HTMLMetaParser.swift
//  Icebox
//

import Foundation

nonisolated struct PageMetadata: Equatable, Sendable {
    var title: String?
    var siteName: String?
    var author: String?
    var thumbnailURLString: String?
    var excerpt: String?
    var durationSeconds: Int?

    init(title: String? = nil, siteName: String? = nil, author: String? = nil,
         thumbnailURLString: String? = nil, excerpt: String? = nil, durationSeconds: Int? = nil) {
        self.title = title
        self.siteName = siteName
        self.author = author
        self.thumbnailURLString = thumbnailURLString
        self.excerpt = excerpt
        self.durationSeconds = durationSeconds
    }
}

/// Pulls the cheap, useful metadata out of a page's HTML head: Open Graph,
/// Twitter cards, plain meta tags, the title tag, and (best effort) a YouTube
/// watch page's duration. Pure string work; no parsing dependency.
nonisolated enum HTMLMetaParser {

    static func parse(html: String) -> PageMetadata {
        guard !html.isEmpty else { return PageMetadata() }
        let tags = metaTags(in: html)

        func first(_ keys: [String]) -> String? {
            for key in keys {
                if let value = tags[key], !value.isEmpty { return value }
            }
            return nil
        }

        var meta = PageMetadata()
        meta.title = first(["og:title", "twitter:title"]) ?? titleTag(in: html)
        meta.siteName = first(["og:site_name"])
        meta.author = first(["author", "article:author", "twitter:creator"])
        meta.thumbnailURLString = first(["og:image", "og:image:url", "twitter:image", "twitter:image:src"])
        meta.excerpt = first(["og:description", "twitter:description", "description"])
        meta.durationSeconds = lengthSeconds(in: html)
        return meta
    }

    // MARK: - Pieces

    /// All `<meta>` tags as `property/name → decoded content`.
    private static func metaTags(in html: String) -> [String: String] {
        var result: [String: String] = [:]
        let tagPattern = /<meta\b[^>]*>/.ignoresCase()
        let attrPattern = /([\w:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/

        for match in html.matches(of: tagPattern) {
            let tag = String(match.0)
            var attrs: [String: String] = [:]
            for attr in tag.matches(of: attrPattern) {
                let name = String(attr.1).lowercased()
                let value = attr.2.map(String.init) ?? attr.3.map(String.init) ?? ""
                attrs[name] = value
            }
            guard let key = attrs["property"] ?? attrs["name"] ?? attrs["itemprop"],
                  let content = attrs["content"] else { continue }
            let lowered = key.lowercased()
            if result[lowered] == nil {
                result[lowered] = decodeEntities(content)
            }
        }
        return result
    }

    private static func titleTag(in html: String) -> String? {
        guard let match = html.firstMatch(of: /<title[^>]*>([\s\S]*?)<\/title>/.ignoresCase()) else { return nil }
        let title = decodeEntities(String(match.1)).trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    /// Best-effort duration from a YouTube watch page's player JSON.
    private static func lengthSeconds(in html: String) -> Int? {
        guard let match = html.firstMatch(of: /"lengthSeconds"\s*:\s*"(\d+)"/) else { return nil }
        return Int(match.1)
    }

    // MARK: - Entities

    private static let namedEntities: [String: String] = [
        "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}",
        "mdash": "\u{2014}", "ndash": "\u{2013}", "hellip": "\u{2026}",
        "lsquo": "\u{2018}", "rsquo": "\u{2019}", "ldquo": "\u{201C}", "rdquo": "\u{201D}",
        "copy": "\u{00A9}", "reg": "\u{00AE}", "trade": "\u{2122}", "amp": "&",
    ]

    static func decodeEntities(_ string: String) -> String {
        guard string.contains("&") else { return string }
        var result = ""
        var remainder = Substring(string)
        while let amp = remainder.firstIndex(of: "&") {
            result += remainder[..<amp]
            remainder = remainder[amp...]
            guard let semi = remainder.firstIndex(of: ";"),
                  remainder.distance(from: remainder.startIndex, to: semi) <= 10 else {
                result += String(remainder.first!)
                remainder = remainder.dropFirst()
                continue
            }
            let body = remainder[remainder.index(after: remainder.startIndex)..<semi]
            var decoded: String?
            if body.hasPrefix("#x") || body.hasPrefix("#X") {
                decoded = UInt32(body.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init).map(String.init)
            } else if body.hasPrefix("#") {
                decoded = UInt32(body.dropFirst()).flatMap(Unicode.Scalar.init).map(String.init)
            } else {
                decoded = namedEntities[String(body)]
            }
            if let decoded {
                result += decoded
                remainder = remainder[remainder.index(after: semi)...]
            } else {
                result += String(remainder.first!)
                remainder = remainder.dropFirst()
            }
        }
        result += remainder
        return result
    }
}
