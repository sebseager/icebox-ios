//
//  OfflineArticle.swift
//  Icebox
//

import Foundation
import SwiftData

/// The archived, self-contained readable copy of a link. Stored in the model
/// container so it syncs through CloudKit with everything else (spec §7, §9).
@Model
final class OfflineArticle {
    var id: UUID = UUID()
    /// Complete reader HTML with images inlined as data: URIs.
    @Attribute(.externalStorage)
    var contentHTML: Data?
    /// Extracted text, used for full-text search.
    var plainText: String = ""
    var excerpt: String = ""
    var byline: String = ""
    var dateArchived: Date = Date()
    /// True only for deliberate offline saves with images inlined. A cached
    /// live extraction keeps this false so the offline badge stays honest
    /// about what the user actually has (spec §7).
    var isFullArchive: Bool = false
    var item: SavedItem?

    init() {}

    var byteCount: Int { contentHTML?.count ?? 0 }
}
