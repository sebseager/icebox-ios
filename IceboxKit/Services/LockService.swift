//
//  LockService.swift
//  Icebox
//

import Foundation
import SwiftData

/// Keeps the denormalized visibility flags on SavedItem correct:
/// `isInLockedCollection` is true exactly when the item belongs to at least
/// one locked collection, and `isHiddenFromLibrary` exactly when it belongs
/// to at least one collection with `showsInLibrary == false`. Library,
/// search, statistics, Spotlight, and export filter on the lock flag, which
/// is what makes locked collections genuinely invisible (spec §10); the
/// library and search additionally filter on the hidden flag.
@MainActor
enum LockService {

    static func setLocked(_ locked: Bool, for collection: ItemCollection, in context: ModelContext) {
        collection.isLocked = locked
        refreshFlags(forItemsIn: collection)
        try? context.save()
    }

    static func setShowsInLibrary(_ shows: Bool, for collection: ItemCollection, in context: ModelContext) {
        collection.showsInLibrary = shows
        refreshFlags(forItemsIn: collection)
        try? context.save()
    }

    /// Removes a membership and keeps the removed item's flags correct.
    /// Every entry deletion in the UI goes through here.
    static func removeEntry(_ entry: CollectionEntry, in context: ModelContext) {
        let item = entry.item
        context.delete(entry)
        try? context.save()
        if let item {
            refreshFlags(for: item)
            try? context.save()
        }
    }

    /// Deletes a collection and un-hides/unlocks its former members as
    /// appropriate.
    static func deleteCollection(_ collection: ItemCollection, in context: ModelContext) {
        let members = (collection.entries ?? []).compactMap(\.item)
        context.delete(collection)
        try? context.save()
        for item in members {
            refreshFlags(for: item)
        }
        try? context.save()
    }

    /// Full recompute; run at launch to heal any flag that drifted (e.g. a
    /// sync race between devices).
    static func refreshFlags(in context: ModelContext) {
        guard let items = try? context.fetch(FetchDescriptor<SavedItem>()) else { return }
        var changed = false
        for item in items {
            let expectedLocked = belongsToLockedCollection(item)
            let expectedHidden = belongsToHiddenCollection(item)
            if item.isInLockedCollection != expectedLocked || item.isHiddenFromLibrary != expectedHidden {
                item.isInLockedCollection = expectedLocked
                item.isHiddenFromLibrary = expectedHidden
                changed = true
            }
        }
        if changed { try? context.save() }
    }

    private static func refreshFlags(forItemsIn collection: ItemCollection) {
        for entry in collection.entries ?? [] {
            guard let item = entry.item else { continue }
            refreshFlags(for: item)
        }
    }

    private static func refreshFlags(for item: SavedItem) {
        item.isInLockedCollection = belongsToLockedCollection(item)
        item.isHiddenFromLibrary = belongsToHiddenCollection(item)
    }

    private static func belongsToLockedCollection(_ item: SavedItem) -> Bool {
        (item.entries ?? []).contains { $0.collection?.isLocked == true }
    }

    private static func belongsToHiddenCollection(_ item: SavedItem) -> Bool {
        (item.entries ?? []).contains { $0.collection?.showsInLibrary == false }
    }
}
