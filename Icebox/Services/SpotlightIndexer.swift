//
//  SpotlightIndexer.swift
//  Icebox
//
//  System integration where it's cheap and expected (spec §14). Locked
//  collections' items never reach Spotlight (spec §10).
//

import Foundation
import CoreSpotlight
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

@MainActor
enum SpotlightIndexer {

    static let domainIdentifier = "com.sebseager.Icebox.items"

    /// Rebuilds the index from the current library. Cheap enough to run at
    /// launch; deleting the domain first keeps removed and locked items out.
    static func reindex(context: ModelContext) async {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        let index = CSSearchableIndex.default()
        try? await index.deleteSearchableItems(withDomainIdentifiers: [domainIdentifier])

        guard let items = try? context.fetch(FetchDescriptor<SavedItem>(
            predicate: #Predicate { !$0.isInLockedCollection }
        )) else { return }

        let searchable = items.map { item -> CSSearchableItem in
            let attributes = CSSearchableItemAttributeSet(contentType: .url)
            attributes.title = item.title
            attributes.contentDescription = item.note.isEmpty ? item.siteName : item.note
            attributes.url = item.url
            if !item.author.isEmpty {
                attributes.artist = item.author
            }
            attributes.keywords = (item.tags ?? []).map(\.name)
            return CSSearchableItem(uniqueIdentifier: item.id.uuidString,
                                    domainIdentifier: domainIdentifier,
                                    attributeSet: attributes)
        }
        try? await index.indexSearchableItems(searchable)
    }

    /// Removes one item from the index immediately, so a deleted item doesn't
    /// linger in Spotlight until the next launch reindex.
    static func deindex(itemID: UUID) {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [itemID.uuidString])
    }

    /// The item a Spotlight result refers to, if it still exists and is
    /// visible.
    static func item(for userActivity: NSUserActivity, context: ModelContext) -> SavedItem? {
        guard userActivity.activityType == CSSearchableItemActionType,
              let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              let uuid = UUID(uuidString: identifier)
        else { return nil }
        return try? context.fetch(FetchDescriptor<SavedItem>(
            predicate: #Predicate { $0.id == uuid && !$0.isInLockedCollection }
        )).first
    }
}
