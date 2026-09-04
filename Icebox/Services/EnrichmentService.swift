//
//  EnrichmentService.swift
//  Icebox
//
//  Capture never waits on the network (spec §5); anything slower than
//  instant lands here and runs in the app afterward. YouTube metadata comes
//  from the public oEmbed endpoint — no key, no account (spec §3.1).
//

import Foundation
import SwiftData

@MainActor
enum EnrichmentService {

    /// Items tried this session, so a failing URL isn't hammered.
    private static var attempted = Set<UUID>()

    private struct OEmbed: Codable {
        var title: String?
        var author_name: String?
        var thumbnail_url: String?
    }

    static func needsEnrichment(_ item: SavedItem) -> Bool {
        switch item.type {
        case .video:
            return item.author.isEmpty || item.durationSeconds == nil || item.title == item.siteName
        case .link:
            return item.title == item.siteName || item.title.isEmpty
        }
    }

    static func enrichPending(in context: ModelContext) async {
        guard let items = try? context.fetch(FetchDescriptor<SavedItem>(
            sortBy: [SortDescriptor(\.dateSaved, order: .reverse)]
        )) else { return }

        for item in items where needsEnrichment(item) && !attempted.contains(item.id) {
            attempted.insert(item.id)
            await enrich(item, in: context)
        }
    }

    static func enrich(_ item: SavedItem, in context: ModelContext) async {
        switch item.type {
        case .video:
            await enrichVideo(item)
        case .link:
            await enrichLink(item)
        }
        try? context.save()
    }

    private static func enrichVideo(_ item: SavedItem) async {
        guard let videoID = item.videoID else { return }

        if let data = await fetch(YouTubeURLParser.oEmbedURL(videoID: videoID)),
           let oembed = try? JSONDecoder().decode(OEmbed.self, from: data) {
            if let title = oembed.title, !title.isEmpty,
               item.title.isEmpty || item.title == item.siteName {
                item.title = title
            }
            if let author = oembed.author_name, item.author.isEmpty {
                item.author = author
            }
            if let thumb = oembed.thumbnail_url, item.thumbnailURLString == nil {
                item.thumbnailURLString = thumb
            }
        }

        // Duration isn't in oEmbed; best effort from the watch page.
        if item.durationSeconds == nil,
           let data = await fetch(YouTubeURLParser.watchURL(videoID: videoID)),
           let html = String(data: data, encoding: .utf8) {
            item.durationSeconds = HTMLMetaParser.parse(html: html).durationSeconds
        }
    }

    private static func enrichLink(_ item: SavedItem) async {
        guard let url = item.url, let data = await fetch(url),
              let html = String(data: data, encoding: .utf8) else { return }
        let meta = HTMLMetaParser.parse(html: html)
        if let title = meta.title, !title.isEmpty,
           item.title.isEmpty || item.title == item.siteName {
            item.title = title
        }
        if let author = meta.author, item.author.isEmpty {
            item.author = author
        }
        if let thumb = meta.thumbnailURLString, item.thumbnailURLString == nil {
            item.thumbnailURLString = thumb
        }
    }

    private static func fetch(_ url: URL) async -> Data? {
        var request = URLRequest(url: url, timeoutInterval: 12)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) != false else {
            return nil
        }
        return data
    }
}
