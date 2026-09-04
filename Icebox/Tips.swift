//
//  Tips.swift
//  Icebox
//
//  Contextual tips in the native idiom: shown where the feature lives, at
//  the moment it becomes relevant, dismissible, never repeated (spec §12).
//

import Foundation
import TipKit

/// Told once and quietly that long collections send in chunks (spec §6).
struct PlaylistChunksTip: Tip {
    var title: Text {
        Text("Plays in chunks")
    }
    var message: Text? {
        Text("Long collections play \(PlaylistBuilder.maxVideosPerPlaylist) videos at a time, starting from where you choose.")
    }
    var image: Image? {
        Image(systemName: "play.square.stack")
    }
}

/// Offline saving, surfaced on a link's detail page.
struct OfflineTip: Tip {
    var title: Text {
        Text("Keep it forever")
    }
    var message: Text? {
        Text("Save Offline keeps a readable copy that works in airplane mode, even if the page disappears.")
    }
    var image: Image? {
        Image(systemName: "arrow.down.circle")
    }
}
