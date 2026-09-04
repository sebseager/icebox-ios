//
//  ItemOpener.swift
//  Icebox
//

import SwiftUI
import SwiftData

/// Every open funnels through here so routing honors the user's per-type
/// preference (spec §11) and history records faithfully (spec §8).
@MainActor
enum ItemOpener {

    static func open(_ item: SavedItem, navigator: Navigator, settings: OpenSettings,
                     openURL: OpenURLAction, context: ModelContext) {
        guard let url = item.url else { return }
        switch item.type {
        case .video:
            route(url, preference: settings.videoPreference == .reader ? .externalBrowser : settings.videoPreference,
                  navigator: navigator, openURL: openURL)
            HistoryService.recordOpen(item, method: .browser, in: context)
        case .link:
            switch settings.linkPreference {
            case .reader:
                navigator.readerItem = item
                HistoryService.recordOpen(item, method: .reader, in: context)
            case .inAppBrowser, .externalBrowser:
                route(url, preference: settings.linkPreference, navigator: navigator, openURL: openURL)
                HistoryService.recordOpen(item, method: .browser, in: context)
            }
        }
    }

    /// Explicit "open in browser": always the real browser with the user's
    /// extension stack, regardless of preferences.
    static func openInBrowser(_ item: SavedItem, openURL: OpenURLAction, context: ModelContext) {
        guard let url = item.url else { return }
        openURL(url)
        HistoryService.recordOpen(item, method: .browser, in: context)
    }

    static func openReader(_ item: SavedItem, navigator: Navigator, context: ModelContext) {
        navigator.readerItem = item
        HistoryService.recordOpen(item, method: .reader, in: context)
    }

    /// Sends the collection to the browser as a real playlist, starting at
    /// the tapped item (spec §6).
    static func openPlaylist(_ collection: ItemCollection, startingAt index: Int,
                             openURL: OpenURLAction, context: ModelContext) {
        guard let window = PlaylistBuilder.playlist(videoIDs: collection.orderedVideoIDs, startingAt: index) else { return }
        openURL(window.url)
        let items = collection.orderedItems
        if items.indices.contains(index) {
            HistoryService.recordOpen(items[index], method: .playlist, in: context)
        }
    }

    private static func route(_ url: URL, preference: OpenPreference,
                              navigator: Navigator, openURL: OpenURLAction) {
        #if os(iOS)
        if preference == .inAppBrowser {
            navigator.inAppPage = InAppPage(url: url)
            return
        }
        #endif
        openURL(url)
    }
}
