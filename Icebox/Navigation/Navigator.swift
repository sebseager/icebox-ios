//
//  Navigator.swift
//  Icebox
//

import Foundation
import Observation

nonisolated struct InAppPage: Identifiable {
    let id = UUID()
    let url: URL
}

/// App-wide presentation state: the reader sheet and the in-app browser.
@MainActor
@Observable
final class Navigator {
    var readerItem: SavedItem?
    var inAppPage: InAppPage?
    var importedPlaylist: ImportedPlaylist?
}

/// A playlist arriving via an icebox:// link (spec §15); RootView shows an
/// import popover for it.
nonisolated struct ImportedPlaylist: Identifiable {
    let id = UUID()
    var name: String
    var videoIDs: [String]
}
