//
//  ItemDeleter.swift
//  Icebox
//

import Foundation
import SwiftData

/// Every item deletion in the UI goes through here so nothing outlives the
/// item: SwiftData cascades remove its collection entries, open history, and
/// offline copy (including the archived HTML), and the Spotlight entry goes
/// with it.
@MainActor
enum ItemDeleter {

    static func delete(_ item: SavedItem, in context: ModelContext) {
        let id = item.id
        context.delete(item)
        try? context.save()
        SpotlightIndexer.deindex(itemID: id)
    }
}
