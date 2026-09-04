//
//  SavedItem.swift
//  Icebox
//

import Foundation
import SwiftData

nonisolated enum ItemType: String, Codable, CaseIterable, Sendable {
    case video
    case link
}

nonisolated enum OpenMethod: String, Codable, CaseIterable, Sendable {
    case reader
    case browser
    case playlist
}

/// One saved thing. All stored properties are optional or defaulted and all
/// relationships are optional with explicit inverses, as CloudKit requires.
@Model
final class SavedItem {
    var id: UUID = UUID()
    var urlString: String = ""
    var normalizedURLString: String = ""
    var typeRaw: String = ItemType.link.rawValue
    var title: String = ""
    var note: String = ""
    /// Channel name for videos, byline for articles.
    var author: String = ""
    /// Host the link came from, e.g. "example.com".
    var siteName: String = ""
    var videoID: String?
    var durationSeconds: Int?
    var thumbnailURLString: String?
    var dateSaved: Date = Date()
    /// Denormalized from OpenEvent for cheap sorting and filtering.
    var lastOpened: Date?
    /// Reader scroll position, 0...1.
    var readingProgress: Double?
    /// Denormalized: belongs to at least one locked collection. Maintained by LockService.
    var isInLockedCollection: Bool = false
    /// Denormalized: belongs to at least one collection with
    /// `showsInLibrary == false`. Maintained by LockService.
    var isHiddenFromLibrary: Bool = false

    var tags: [Tag]? = []
    @Relationship(deleteRule: .cascade, inverse: \CollectionEntry.item)
    var entries: [CollectionEntry]? = []
    @Relationship(deleteRule: .cascade, inverse: \OpenEvent.item)
    var openEvents: [OpenEvent]? = []
    @Relationship(deleteRule: .cascade, inverse: \OfflineArticle.item)
    var article: OfflineArticle?

    init() {}

    var type: ItemType {
        get { ItemType(rawValue: typeRaw) ?? .link }
        set { typeRaw = newValue.rawValue }
    }

    var url: URL? { URL(string: urlString) }
    var thumbnailURL: URL? { thumbnailURLString.flatMap(URL.init(string:)) }
    var isVideo: Bool { type == .video }
    var hasOfflineArticle: Bool { article?.isFullArchive == true && article?.contentHTML != nil }

    var sortedOpenEvents: [OpenEvent] {
        (openEvents ?? []).sorted { $0.date > $1.date }
    }
}
