//
//  IceboxIntents.swift
//  Icebox
//
//  Shortcuts integration (spec §14): save a link without opening the app.
//
//  Deliberately NOT an AppShortcutsProvider: that would surface "Save Link"
//  in home-screen Spotlight, where typing a URL by hand is useless. The
//  intent stays available as a building block in the Shortcuts app.
//

import AppIntents
import Foundation
import SwiftData

struct SaveLinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Save Link to Icebox"
    static let description = IntentDescription("Saves a link to your Icebox library.")

    @Parameter(title: "Link")
    var url: URL

    @Parameter(title: "Note")
    var note: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = IceboxStore.makeSharedContainer()
        let item = try CaptureService.save(
            CaptureInput(url: url, note: note ?? ""),
            in: container.mainContext
        )
        return .result(dialog: "Saved \(item.title) to Icebox.")
    }
}
