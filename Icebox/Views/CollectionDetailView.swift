//
//  CollectionDetailView.swift
//  Icebox
//

import SwiftUI
import SwiftData
import TipKit

struct CollectionDetailView: View {
    @Bindable var collection: ItemCollection

    @Environment(\.modelContext) private var context
    @Environment(Navigator.self) private var navigator
    @Environment(OpenSettings.self) private var openSettings
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    @State private var showsRenameAlert = false
    @State private var renameText = ""
    @State private var showsAddItems = false
    @State private var detailItem: SavedItem?

    var body: some View {
        List {
            // Told once and quietly; dismissible, never repeated (spec §6, §12).
            if collection.isPlaylistEligible && collection.orderedEntries.count > PlaylistBuilder.maxVideosPerPlaylist {
                TipView(PlaylistChunksTip())
                    .listRowSeparator(.hidden)
            }
            Section {
                ForEach(Array(collection.orderedEntries.enumerated()), id: \.element.id) { index, entry in
                    if let item = entry.item {
                        Button {
                            // Tapping opens just this item; the playlist only
                            // starts from the Play button (or Play from Here).
                            ItemOpener.open(item, navigator: navigator, settings: openSettings,
                                            openURL: openURL, context: context)
                        } label: {
                            ItemRowView(item: item)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .leading) {
                            Button {
                                detailItem = item
                            } label: {
                                Label("Details", systemImage: "info.circle")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                LockService.removeEntry(entry, in: context)
                            } label: {
                                Label("Remove", systemImage: "minus.circle")
                            }
                        }
                        .contextMenu {
                            Button("Details", systemImage: "info.circle") { detailItem = item }
                            if collection.isPlaylistEligible {
                                Button("Play from Here", systemImage: "play.fill") {
                                    ItemOpener.openPlaylist(collection, startingAt: index,
                                                            openURL: openURL, context: context)
                                }
                            }
                            Button("Open in Browser", systemImage: "safari") {
                                ItemOpener.openInBrowser(item, openURL: openURL, context: context)
                            }
                            Button("Remove from Collection", systemImage: "minus.circle", role: .destructive) {
                                LockService.removeEntry(entry, in: context)
                            }
                        }
                    }
                }
                .onMove(perform: move)
                .onDelete { offsets in
                    let ordered = collection.orderedEntries
                    for index in offsets {
                        LockService.removeEntry(ordered[index], in: context)
                    }
                }
            }
        }
        .overlay {
            if collection.orderedEntries.isEmpty {
                ContentUnavailableView(
                    "Empty collection",
                    systemImage: "square.stack",
                    description: Text("Add things from your library, or pick this collection when saving.")
                )
            }
        }
        .navigationTitle(collection.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            // The playlist affordance exists exactly when the collection is a
            // playlist; otherwise it is simply absent (spec §6).
            if collection.isPlaylistEligible {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        ItemOpener.openPlaylist(collection, startingAt: 0, openURL: openURL, context: context)
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                }
                if let window = PlaylistBuilder.playlist(videoIDs: collection.orderedVideoIDs) {
                    ToolbarItem {
                        // A plain URL that works for anyone, no app and no
                        // account needed (spec §15).
                        ShareLink(item: window.url) {
                            Label("Share Playlist", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            ToolbarItem {
                menu
            }
        }
        .sheet(isPresented: $showsAddItems) {
            AddToCollectionView(collection: collection)
        }
        .navigationDestination(item: $detailItem) { item in
            ItemDetailView(item: item)
        }
        .alert("Rename Collection", isPresented: $showsRenameAlert) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                let name = renameText.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { collection.name = name }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var menu: some View {
        Menu {
            Button("Add Items", systemImage: "plus") { showsAddItems = true }
            Button("Rename", systemImage: "pencil") {
                renameText = collection.name
                showsRenameAlert = true
            }
            if collection.isPlaylistEligible,
               let link = ImportLink.encode(collectionName: collection.name,
                                            videoIDs: collection.orderedVideoIDs) {
                Button("Copy Link for Icebox Users", systemImage: "link") {
                    copyToPasteboard(link.absoluteString)
                }
            }
            Toggle("Show Items in Library", systemImage: "books.vertical", isOn: Binding(
                get: { collection.showsInLibrary },
                set: { LockService.setShowsInLibrary($0, for: collection, in: context) }
            ))
            Button(collection.isLocked ? "Unlock Collection" : "Lock Collection",
                   systemImage: collection.isLocked ? "lock.open" : "lock") {
                LockService.setLocked(!collection.isLocked, for: collection, in: context)
            }
            Button("Delete Collection", systemImage: "trash", role: .destructive) {
                LockService.deleteCollection(collection, in: context)
                dismiss()
            }
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
    }

    private func copyToPasteboard(_ string: String) {
        #if os(iOS)
        UIPasteboard.general.string = string
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }

    private func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let reordered = movedElements(collection.orderedEntries, fromOffsets: source, toOffset: destination)
        for (index, entry) in reordered.enumerated() {
            entry.position = Double(index)
        }
        try? context.save()
    }
}

/// Picker for adding existing library items to a collection.
private struct AddToCollectionView: View {
    let collection: ItemCollection

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    @Query(filter: #Predicate<SavedItem> { !$0.isInLockedCollection },
           sort: \SavedItem.dateSaved, order: .reverse)
    private var items: [SavedItem]

    var body: some View {
        NavigationStack {
            List(filteredItems) { item in
                Button {
                    toggle(item)
                } label: {
                    HStack {
                        ItemRowView(item: item)
                        if isMember(item) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText)
            .navigationTitle("Add Items")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var filteredItems: [SavedItem] {
        let text = searchText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return items }
        return items.filter { $0.title.localizedStandardContains(text) }
    }

    private func isMember(_ item: SavedItem) -> Bool {
        (collection.entries ?? []).contains { $0.item?.id == item.id }
    }

    private func toggle(_ item: SavedItem) {
        if let entry = (collection.entries ?? []).first(where: { $0.item?.id == item.id }) {
            LockService.removeEntry(entry, in: context)
        } else {
            CaptureService.addItem(item, to: collection, in: context)
        }
    }
}
