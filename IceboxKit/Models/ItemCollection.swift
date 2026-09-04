//
//  ItemCollection.swift
//  Icebox
//

import Foundation
import SwiftData

/// An ordered, user-named group of items. Named ItemCollection because
/// `Collection` collides with the standard library protocol.
@Model
final class ItemCollection {
    var id: UUID = UUID()
    var name: String = ""
    var dateCreated: Date = Date()
    var isLocked: Bool = false
    /// When false, items in this collection are hidden from the library and
    /// only appear inside the collection itself.
    var showsInLibrary: Bool = true

    @Relationship(deleteRule: .cascade, inverse: \CollectionEntry.collection)
    var entries: [CollectionEntry]? = []

    init() {}

    var orderedEntries: [CollectionEntry] {
        (entries ?? []).sorted { $0.position < $1.position }
    }

    var orderedItems: [SavedItem] {
        orderedEntries.compactMap(\.item)
    }

    /// A collection is a playlist exactly when it is non-empty and every item
    /// is a YouTube video. Anything else is an ordinary collection (spec §6).
    var isPlaylistEligible: Bool {
        let items = orderedItems
        return !items.isEmpty && items.allSatisfy { $0.isVideo && $0.videoID != nil }
    }

    var orderedVideoIDs: [String] {
        orderedItems.compactMap(\.videoID)
    }

    /// Position value for appending a new entry at the end.
    var nextPosition: Double {
        (orderedEntries.last?.position ?? 0) + 1
    }
}
