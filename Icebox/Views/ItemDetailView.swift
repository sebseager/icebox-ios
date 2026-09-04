//
//  ItemDetailView.swift
//  Icebox
//

import SwiftUI
import SwiftData
import TipKit

struct ItemDetailView: View {
    @Bindable var item: SavedItem

    @Environment(\.modelContext) private var context
    @Environment(Navigator.self) private var navigator
    @Environment(OpenSettings.self) private var openSettings
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ItemCollection.name) private var allCollections: [ItemCollection]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @State private var newTagText = ""
    @State private var isArchiving = false
    @State private var archiveError: String?

    var body: some View {
        Form {
            headerSection
            collectionsSection
            tagsSection
            noteSection
            if item.type == .link {
                offlineSection
            }
            historySection
            Section {
                Button(role: .destructive) {
                    ItemDeleter.delete(item, in: context)
                    dismiss()
                } label: {
                    Label("Delete Item", systemImage: "trash")
                        .foregroundStyle(.red)
                        .wholeCellTappable()
                }
            }
        }
        .formStyle(.grouped)
        .dismissesKeyboard()
        .navigationTitle(item.isVideo ? "Video" : "Link")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    ItemOpener.open(item, navigator: navigator, settings: openSettings,
                                    openURL: openURL, context: context)
                } label: {
                    Label("Open", systemImage: "arrow.up.right.square")
                }
            }
            ToolbarItem {
                Menu {
                    Button("Open in Browser", systemImage: "safari") {
                        ItemOpener.openInBrowser(item, openURL: openURL, context: context)
                    }
                    if item.type == .link {
                        Button("Open in Reader", systemImage: "doc.plaintext") {
                            ItemOpener.openReader(item, navigator: navigator, context: context)
                        }
                    }
                    if let url = item.url {
                        ShareLink(item: url)
                        Button("Copy Link", systemImage: "doc.on.doc") {
                            copyToPasteboard(url.absoluteString)
                        }
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                if item.isVideo, let thumbnailURL = item.thumbnailURL {
                    AsyncImage(url: thumbnailURL) { image in
                        image.resizable().aspectRatio(16 / 9, contentMode: .fit)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8).fill(.quaternary).aspectRatio(16 / 9, contentMode: .fit)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityHidden(true)
                }
                TextField("Title", text: $item.title, axis: .vertical)
                    .font(.headline)
                HStack(spacing: 6) {
                    if !item.author.isEmpty {
                        Text(item.author)
                    }
                    if let duration = item.durationSeconds {
                        Text(ItemRowView.formatted(duration: duration)).monospacedDigit()
                    }
                    Text(item.siteName)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Text("Saved \(item.dateSaved, format: .dateTime.day().month().year())")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var noteSection: some View {
        Section("Note") {
            TextField("Add a note", text: $item.note, axis: .vertical)
                .lineLimit(4...10)
        }
    }

    private var tagsSection: some View {
        Section("Tags") {
            ForEach(item.tags ?? []) { tag in
                HStack {
                    Label(tag.name, systemImage: "number")
                    Spacer()
                    Button {
                        item.tags?.removeAll { $0.id == tag.id }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove tag \(tag.name)")
                }
            }
            HStack {
                TextField("Add tags", text: $newTagText)
                    .onSubmit(addTags)
                if !suggestedTags.isEmpty {
                    Menu {
                        ForEach(suggestedTags) { tag in
                            Button(tag.name) {
                                item.tags = (item.tags ?? []) + [tag]
                            }
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .accessibilityLabel("Add an existing tag")
                }
            }
        }
    }

    private var suggestedTags: [Tag] {
        let current = Set((item.tags ?? []).map(\.id))
        return allTags.filter { !current.contains($0.id) }
    }

    private func addTags() {
        // Space separated: "swift ios" becomes two tags.
        for name in newTagText.split(whereSeparator: \.isWhitespace).map(String.init) {
            if let existing = allTags.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                if !(item.tags ?? []).contains(where: { $0.id == existing.id }) {
                    item.tags = (item.tags ?? []) + [existing]
                }
            } else {
                let tag = Tag()
                tag.name = name
                context.insert(tag)
                item.tags = (item.tags ?? []) + [tag]
            }
        }
        newTagText = ""
    }

    private var collectionsSection: some View {
        Section("Collections") {
            ForEach(memberEntries, id: \.id) { entry in
                if let collection = entry.collection {
                    HStack {
                        Label(collection.name, systemImage: "square.stack")
                        Spacer()
                        Button {
                            LockService.removeEntry(entry, in: context)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove from \(collection.name)")
                    }
                }
            }
            if !availableCollections.isEmpty {
                Menu {
                    ForEach(availableCollections) { collection in
                        Button(collection.name) {
                            CaptureService.addItem(item, to: collection, in: context)
                        }
                    }
                } label: {
                    Label("Add to Collection", systemImage: "plus")
                        .wholeCellTappable()
                }
            }
        }
    }

    /// Membership rows: locked collections stay invisible here too.
    private var memberEntries: [CollectionEntry] {
        (item.entries ?? []).filter { $0.collection?.isLocked == false }
    }

    private var availableCollections: [ItemCollection] {
        let memberIDs = Set((item.entries ?? []).compactMap { $0.collection?.id })
        return allCollections.filter { !$0.isLocked && !memberIDs.contains($0.id) }
    }

    private var offlineSection: some View {
        Section("Offline") {
            if item.hasOfflineArticle {
                HStack {
                    Label("Saved offline", systemImage: "arrow.down.circle.fill")
                    Spacer()
                    if let article = item.article {
                        Text(article.dateArchived, format: .dateTime.day().month())
                            .foregroundStyle(.secondary)
                    }
                }
                Button(role: .destructive) {
                    ArchiveService.removeArchive(item, in: context)
                } label: {
                    Label("Remove Offline Copy", systemImage: "trash")
                        .foregroundStyle(.red)
                        .wholeCellTappable()
                }
            } else {
                TipView(OfflineTip())
                Button {
                    archive()
                } label: {
                    if isArchiving {
                        HStack {
                            Text("Saving…")
                            Spacer()
                            ProgressView()
                        }
                    } else {
                        Label("Save Offline", systemImage: "arrow.down.circle")
                            .wholeCellTappable()
                    }
                }
                .disabled(isArchiving)
                if let archiveError {
                    Text(archiveError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func archive() {
        isArchiving = true
        archiveError = nil
        Task {
            do {
                try await ArchiveService.archive(item, in: context)
            } catch {
                archiveError = String(localized: "Couldn't save this page for offline reading.")
            }
            isArchiving = false
        }
    }

    private var historySection: some View {
        Section("History") {
            let events = item.sortedOpenEvents
            if events.isEmpty {
                Text("Not opened yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(events.prefix(5)) { event in
                    HStack {
                        Text(event.date, format: .dateTime.day().month().year().hour().minute())
                        Spacer()
                        Text(label(for: event.method))
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
                if events.count > 5 {
                    Text("\(events.count) opens in total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func label(for method: OpenMethod) -> String {
        switch method {
        case .reader: String(localized: "Reader")
        case .browser: String(localized: "Browser")
        case .playlist: String(localized: "Playlist")
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
}
