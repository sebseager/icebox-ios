//
//  SearchFilter.swift
//  Icebox
//

import Foundation
import SwiftData

/// One value describing a search: free text plus structured filters. Smart
/// lists persist an encoded SearchFilter and stay current (spec §14). Every
/// query it runs excludes items in locked collections (spec §10).
///
/// The free-text match (including offline full text) runs in the store via
/// `predicate`; the structured filters are cheap scalar checks applied in
/// memory — one giant #Predicate exceeds the macro type-checker's budget.
nonisolated struct SearchFilter: Codable, Hashable, Sendable {
    var text: String = ""
    var type: ItemType? = nil
    var tagName: String? = nil
    var collectionID: UUID? = nil
    var offlineOnly: Bool = false
    var savedAfter: Date? = nil
    var savedBefore: Date? = nil
    var openedAfter: Date? = nil
    var neverOpened: Bool = false

    init(text: String = "", type: ItemType? = nil, tagName: String? = nil, collectionID: UUID? = nil,
         offlineOnly: Bool = false, savedAfter: Date? = nil, savedBefore: Date? = nil,
         openedAfter: Date? = nil, neverOpened: Bool = false) {
        self.text = text
        self.type = type
        self.tagName = tagName
        self.collectionID = collectionID
        self.offlineOnly = offlineOnly
        self.savedAfter = savedAfter
        self.savedBefore = savedBefore
        self.openedAfter = openedAfter
        self.neverOpened = neverOpened
    }

    var isEmpty: Bool { self == SearchFilter() }

    /// Lock exclusion plus free-text match; suitable for @Query. (The
    /// hidden-collection exclusion lives in `matchesStructuredFilters` —
    /// one more clause here exceeds the #Predicate type-checker budget.)
    var predicate: Predicate<SavedItem> {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !text.isEmpty
        return #Predicate<SavedItem> { item in
            item.isInLockedCollection == false
            && (!hasText
                || item.title.localizedStandardContains(text)
                || item.note.localizedStandardContains(text)
                || item.author.localizedStandardContains(text)
                || item.siteName.localizedStandardContains(text)
                || item.urlString.localizedStandardContains(text)
                || item.article?.plainText.localizedStandardContains(text) == true)
        }
    }

    /// The structured half; `results(in:)` and list views apply this after
    /// the store-side predicate.
    func matchesStructuredFilters(_ item: SavedItem) -> Bool {
        // Items in hidden collections stay out of the library and search,
        // but filtering by a specific collection still shows its items.
        if item.isHiddenFromLibrary && collectionID == nil { return false }
        if let type, item.type != type { return false }
        if let tagName, !tagName.isEmpty {
            let hit = (item.tags ?? []).contains { $0.name.caseInsensitiveCompare(tagName) == .orderedSame }
            if !hit { return false }
        }
        if let collectionID {
            let hit = (item.entries ?? []).contains { $0.collection?.id == collectionID }
            if !hit { return false }
        }
        if offlineOnly && !item.hasOfflineArticle { return false }
        if let savedAfter, item.dateSaved < savedAfter { return false }
        if let savedBefore, item.dateSaved > savedBefore { return false }
        if let openedAfter, (item.lastOpened ?? .distantPast) < openedAfter { return false }
        if neverOpened && item.lastOpened != nil { return false }
        return true
    }

    /// Full search: newest saved first.
    func results(in context: ModelContext) throws -> [SavedItem] {
        var descriptor = FetchDescriptor<SavedItem>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.dateSaved, order: .reverse)]
        return try context.fetch(descriptor).filter(matchesStructuredFilters)
    }

    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func decode(_ data: Data?) -> SearchFilter? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(SearchFilter.self, from: data)
    }
}
