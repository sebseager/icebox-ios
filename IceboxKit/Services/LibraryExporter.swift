//
//  LibraryExporter.swift
//  Icebox
//

import Foundation
import SwiftData

nonisolated struct ExportOptions: Sendable {
    /// Locked collections and their items stay out of an export unless the
    /// user explicitly asks (spec §10).
    var includeLocked: Bool = false
    var includeArticleContent: Bool = true

    init(includeLocked: Bool = false, includeArticleContent: Bool = true) {
        self.includeLocked = includeLocked
        self.includeArticleContent = includeArticleContent
    }
}

/// Writes the whole library — items, collections, tags, history, offline
/// article content — as pretty-printed JSON a person can open and understand
/// in a text editor. This is how the library outlives us (spec §9).
/// Format documented in docs/export-format.md.
@MainActor
enum LibraryExporter {

    static let formatVersion = 1

    static func export(context: ModelContext, options: ExportOptions = ExportOptions()) throws -> Data {
        let iso = ISO8601DateFormatter()

        let allItems = try context.fetch(FetchDescriptor<SavedItem>(sortBy: [SortDescriptor(\.dateSaved)]))
        let items = options.includeLocked ? allItems : allItems.filter { !$0.isInLockedCollection }

        let allCollections = try context.fetch(FetchDescriptor<ItemCollection>(sortBy: [SortDescriptor(\.dateCreated)]))
        let collections = options.includeLocked ? allCollections : allCollections.filter { !$0.isLocked }

        var root: [String: Any] = [
            "formatVersion": formatVersion,
            "exportedAt": iso.string(from: Date()),
            "generator": "Icebox",
        ]

        root["items"] = items.map { item -> [String: Any] in
            var dict: [String: Any] = [
                "id": item.id.uuidString,
                "url": item.urlString,
                "type": item.typeRaw,
                "title": item.title,
                "dateSaved": iso.string(from: item.dateSaved),
            ]
            if !item.note.isEmpty { dict["note"] = item.note }
            if !item.author.isEmpty { dict["author"] = item.author }
            if !item.siteName.isEmpty { dict["siteName"] = item.siteName }
            if let videoID = item.videoID { dict["videoID"] = videoID }
            if let duration = item.durationSeconds { dict["durationSeconds"] = duration }
            if let thumb = item.thumbnailURLString { dict["thumbnailURL"] = thumb }
            if let lastOpened = item.lastOpened { dict["lastOpened"] = iso.string(from: lastOpened) }
            if let progress = item.readingProgress { dict["readingProgress"] = progress }

            let tags = (item.tags ?? []).map(\.name).sorted()
            if !tags.isEmpty { dict["tags"] = tags }

            let history = item.sortedOpenEvents.reversed().map { event in
                ["date": iso.string(from: event.date), "method": event.methodRaw]
            }
            if !history.isEmpty { dict["history"] = Array(history) }

            if let article = item.article {
                var articleDict: [String: Any] = [
                    "dateArchived": iso.string(from: article.dateArchived),
                    "plainText": article.plainText,
                ]
                if !article.byline.isEmpty { articleDict["byline"] = article.byline }
                if !article.excerpt.isEmpty { articleDict["excerpt"] = article.excerpt }
                if options.includeArticleContent, let html = article.contentHTML {
                    articleDict["contentHTML"] = String(decoding: html, as: UTF8.self)
                }
                dict["article"] = articleDict
            }
            return dict
        }

        root["collections"] = collections.map { collection -> [String: Any] in
            [
                "id": collection.id.uuidString,
                "name": collection.name,
                "dateCreated": iso.string(from: collection.dateCreated),
                "isLocked": collection.isLocked,
                "itemIDs": collection.orderedItems.map { $0.id.uuidString },
            ]
        }

        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }
}
