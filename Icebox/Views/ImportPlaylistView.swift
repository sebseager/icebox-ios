//
//  ImportPlaylistView.swift
//  Icebox
//
//  The popover shown when someone with Icebox opens a shared icebox:// link
//  (spec §15).
//

import SwiftUI
import SwiftData

struct ImportPlaylistView: View {
    let playlist: ImportedPlaylist

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var imported = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: imported ? "checkmark.circle.fill" : "square.stack.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(imported ? .green : .accentColor)
                Text(imported ? "Added to your collections" : playlist.name)
                    .font(.title3.bold())
                if !imported {
                    Text("\(playlist.videoIDs.count) videos, in the sender's order.")
                        .foregroundStyle(.secondary)
                    Button("Import") { importPlaylist() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
            .padding(32)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(imported ? "Done" : "Cancel") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 280)
        #endif
    }

    private func importPlaylist() {
        let collection = ItemCollection()
        collection.name = playlist.name
        context.insert(collection)
        for videoID in playlist.videoIDs {
            let input = CaptureInput(url: YouTubeURLParser.watchURL(videoID: videoID))
            if let item = try? CaptureService.save(input, in: context) {
                CaptureService.addItem(item, to: collection, in: context)
            }
        }
        try? context.save()
        withAnimation { imported = true }
    }
}
