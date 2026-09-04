//
//  ArchiveService.swift
//  Icebox
//
//  Saves a link for offline reading: extract the article, inline its images
//  as data URIs, and store the self-contained result in the library so it
//  syncs and survives link rot (spec §7).
//

import Foundation
import SwiftData

@MainActor
enum ArchiveService {

    /// Total image budget per article, so one page can't bloat the library.
    static let maxImageBytes = 10 * 1024 * 1024
    static let maxSingleImageBytes = 5 * 1024 * 1024

    static func archive(_ item: SavedItem, in context: ModelContext) async throws {
        guard let url = item.url else { throw ArticleExtractor.ExtractionError.loadFailed }

        let extractor = ArticleExtractor()
        let result = try await extractor.extract(from: url)
        let content = await inlineImages(in: result.content, base: url)

        let article = item.article ?? OfflineArticle()
        article.contentHTML = Data(content.utf8)
        article.plainText = result.textContent
        article.excerpt = result.excerpt
        article.byline = result.byline
        article.dateArchived = Date()
        article.isFullArchive = true
        if article.item == nil {
            article.item = item
            context.insert(article)
        }

        // The extraction often knows more than capture did; fill blanks only.
        if item.author.isEmpty { item.author = result.byline }
        if item.title.isEmpty || item.title == item.siteName { item.title = result.title }

        try context.save()
    }

    static func removeArchive(_ item: SavedItem, in context: ModelContext) {
        if let article = item.article {
            context.delete(article)
            try? context.save()
        }
    }

    private static func inlineImages(in html: String, base: URL) async -> String {
        let sources = ReaderHTML.imageSources(in: html, base: base)
        guard !sources.isEmpty else { return html }

        var replacements: [String: String] = [:]
        var totalBytes = 0
        let session = URLSession(configuration: .ephemeral)

        for source in sources {
            guard totalBytes < maxImageBytes else { break }
            guard let (data, response) = try? await session.data(from: source.url) else { continue }
            guard data.count <= maxSingleImageBytes, totalBytes + data.count <= maxImageBytes else { continue }
            let mimeType = (response.mimeType?.hasPrefix("image/") == true ? response.mimeType : nil) ?? "image/jpeg"
            replacements[source.attribute] = ReaderHTML.dataURI(for: data, mimeType: mimeType)
            totalBytes += data.count
        }
        return ReaderHTML.replacingImageSources(in: html, with: replacements)
    }
}
