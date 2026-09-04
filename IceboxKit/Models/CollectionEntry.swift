//
//  CollectionEntry.swift
//  Icebox
//

import Foundation
import SwiftData

/// Join record giving an item a manual position inside one collection.
/// Positions are Doubles so a move only rewrites the entries that changed.
@Model
final class CollectionEntry {
    var id: UUID = UUID()
    var position: Double = 0
    var dateAdded: Date = Date()
    var item: SavedItem?
    var collection: ItemCollection?

    init() {}
}
