//
//  CaptureService.swift
//  Icebox
//

import Foundation
import SwiftData

/// Everything needed to save one thing. The share extension, paste, drag,
/// and Shortcuts all funnel through here so capture behaves identically
/// everywhere (spec §5).
nonisolated struct CaptureInput: Sendable {
    var url: URL
    var providedTitle: String?
    var note: String = ""
    var tagNames: [String] = []
    var collectionIDs: [UUID] = []

    init(url: URL, providedTitle: String? = nil, note: String = "", tagNames: [String] = [], collectionIDs: [UUID] = []) {
        self.url = url
        self.providedTitle = providedTitle
        self.note = note
        self.tagNames = tagNames
        self.collectionIDs = collectionIDs
    }
}

@MainActor
enum CaptureService {

    /// Saves with whatever is cheaply available right now — never touches the
    /// network. Re-saving a URL updates the existing item instead of
    /// duplicating it. The result is always presentable: worst case the title
    /// is the site's host, never a bare URL.
    @discardableResult
    static func save(_ input: CaptureInput, in context: ModelContext) throws -> SavedItem {
        let normalized = URLNormalizer.normalized(input.url)

        let existing = try context.fetch(FetchDescriptor<SavedItem>(
            predicate: #Predicate { $0.normalizedURLString == normalized }
        )).first

        let item = existing ?? SavedItem()
        if existing == nil {
            item.urlString = input.url.absoluteString
            item.normalizedURLString = normalized
            item.dateSaved = Date()
            context.insert(item)
        } else {
            item.dateSaved = Date() // resurfaces in "recently saved"
        }

        let host = input.url.host()?.replacingOccurrences(of: "www.", with: "") ?? ""
        if item.siteName.isEmpty { item.siteName = host }

        if let videoID = YouTubeURLParser.videoID(from: input.url) {
            item.type = .video
            item.videoID = videoID
            if item.thumbnailURLString == nil {
                item.thumbnailURLString = YouTubeURLParser.thumbnailURL(videoID: videoID).absoluteString
            }
        }

        if let provided = input.providedTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !provided.isEmpty {
            item.title = provided
        }
        if item.title.isEmpty {
            item.title = host.isEmpty ? input.url.absoluteString : host
        }

        if !input.note.isEmpty {
            item.note = item.note.isEmpty ? input.note : item.note + "\n" + input.note
        }

        for name in input.tagNames {
            let tag = try findOrCreateTag(named: name, in: context)
            if let tag, !(item.tags ?? []).contains(where: { $0.id == tag.id }) {
                item.tags = (item.tags ?? []) + [tag]
            }
        }

        for collectionID in input.collectionIDs {
            let collection = try context.fetch(FetchDescriptor<ItemCollection>(
                predicate: #Predicate { $0.id == collectionID }
            )).first
            if let collection {
                addItem(item, to: collection, in: context)
            }
        }

        try context.save()
        return item
    }

    /// Appends the item at the end of the collection. Does nothing if it is
    /// already there.
    static func addItem(_ item: SavedItem, to collection: ItemCollection, in context: ModelContext) {
        guard !(collection.entries ?? []).contains(where: { $0.item?.id == item.id }) else { return }
        let entry = CollectionEntry()
        entry.position = collection.nextPosition
        entry.item = item
        entry.collection = collection
        context.insert(entry)
        item.isInLockedCollection = item.isInLockedCollection || collection.isLocked
        item.isHiddenFromLibrary = item.isHiddenFromLibrary || !collection.showsInLibrary
    }

    private static func findOrCreateTag(named name: String, in context: ModelContext) throws -> Tag? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let all = try context.fetch(FetchDescriptor<Tag>())
        if let existing = all.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return existing
        }
        let tag = Tag()
        tag.name = trimmed
        context.insert(tag)
        return tag
    }
}
