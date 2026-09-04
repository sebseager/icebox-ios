//
//  Tag.swift
//  Icebox
//

import Foundation
import SwiftData

/// A flat, freely applied label. Tags are for finding; collections are for
/// sequencing (spec §4).
@Model
final class Tag {
    var id: UUID = UUID()
    var name: String = ""

    @Relationship(inverse: \SavedItem.tags)
    var items: [SavedItem]? = []

    init() {}
}
