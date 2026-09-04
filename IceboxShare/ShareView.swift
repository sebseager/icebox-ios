//
//  ShareView.swift
//  IceboxShare
//
//  One tap to save with sensible defaults; collections, tags, and note are
//  there without being required. Never waits on the network (spec §5).
//  Laid out as a full form so it looks right at whatever size the host
//  presents the sheet.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ShareView: View {
    let extensionContext: NSExtensionContext?

    private enum Phase {
        case loading
        case ready
        case saved
        case failed(String)
    }

    private enum Field {
        case title, tags, note
    }

    @State private var phase: Phase = .loading
    @State private var url: URL?
    @State private var title: String = ""
    @State private var note: String = ""
    @State private var tagText: String = ""
    @State private var selectedCollectionIDs: [UUID] = []
    @State private var collections: [(id: UUID, name: String)] = []
    @State private var container: ModelContainer?
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Icebox")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { cancel() }
                    }
                    if case .ready = phase {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") { save() }
                        }
                    }
                }
        }
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text(message).font(.callout).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready, .saved:
            // Saving keeps the form in place; only the bottom button changes,
            // then the sheet dismisses on its own.
            form
        }
    }

    private var isSaved: Bool {
        if case .saved = phase { return true }
        return false
    }

    private var form: some View {
        Form {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    thumbnail
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Title", text: $title, axis: .vertical)
                            .lineLimit(2)
                            .font(.body.weight(.medium))
                            .focused($focusedField, equals: .title)
                        Text(url?.host() ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !collections.isEmpty {
                Section("Collections") {
                    // Same membership row as the item detail view: name on
                    // the left, removal X on the right.
                    ForEach(selectedCollections, id: \.id) { collection in
                        HStack {
                            Label(collection.name, systemImage: "square.stack")
                            Spacer()
                            Button {
                                selectedCollectionIDs.removeAll { $0 == collection.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove from \(collection.name)")
                        }
                    }
                    .onDelete { offsets in
                        selectedCollectionIDs.remove(atOffsets: offsets)
                    }
                    // Stays put beneath the chosen collections.
                    if !availableCollections.isEmpty {
                        Menu {
                            ForEach(availableCollections, id: \.id) { collection in
                                Button(collection.name) {
                                    selectedCollectionIDs.append(collection.id)
                                }
                            }
                        } label: {
                            Label("Add to Collection", systemImage: "plus")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(.rect)
                        }
                    }
                }
            }

            Section("Tags") {
                TextField("Tags", text: $tagText)
                    .focused($focusedField, equals: .tags)
            }

            Section("Note") {
                TextField("Add a note", text: $note, axis: .vertical)
                    .lineLimit(4...10)
                    .focused($focusedField, equals: .note)
            }
        }
        .formStyle(.grouped)
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture { focusedField = nil }
        .safeAreaInset(edge: .bottom) {
            Button(action: save) {
                Group {
                    if isSaved {
                        Label("Saved", systemImage: "checkmark")
                    } else {
                        Text("Save to Icebox")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            // Not .disabled(): the button keeps its native prominent blue
            // while "Saved" shows; it just stops accepting taps.
            .allowsHitTesting(!isSaved)
            .padding()
            #if os(iOS)
            .background(Color(.systemGroupedBackground))
            #else
            .background(Color(nsColor: .windowBackgroundColor))
            #endif
        }
    }

    private var selectedCollections: [(id: UUID, name: String)] {
        selectedCollectionIDs.compactMap { id in collections.first { $0.id == id } }
    }

    private var availableCollections: [(id: UUID, name: String)] {
        collections.filter { !selectedCollectionIDs.contains($0.id) }
    }

    @ViewBuilder
    private var thumbnail: some View {
        let shape = RoundedRectangle(cornerRadius: 8)
        if let url, let videoID = YouTubeURLParser.videoID(from: url) {
            AsyncImage(url: YouTubeURLParser.thumbnailURL(videoID: videoID)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                shape.fill(.quaternary)
                    .overlay(Image(systemName: "play.rectangle").foregroundStyle(.secondary))
            }
            .frame(width: 72, height: 40)
            .clipShape(shape)
        } else {
            shape.fill(.quaternary)
                .overlay(Image(systemName: "link").foregroundStyle(.secondary))
                .frame(width: 44, height: 40)
        }
    }

    // MARK: - Behavior

    private func load() async {
        // Everything here is local: attachments the host app already has,
        // and whatever the URL itself encodes. No fetches.
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            phase = .failed(String(localized: "Nothing to save."))
            return
        }

        var foundURL: URL?
        var foundTitle: String?

        for item in items {
            if foundTitle == nil, let text = item.attributedContentText?.string,
               !text.isEmpty, URL(string: text)?.scheme == nil {
                foundTitle = text
            }
            for provider in item.attachments ?? [] {
                if foundURL == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier)
                    if let url = loaded as? URL, url.scheme?.hasPrefix("http") == true {
                        foundURL = url
                    }
                } else if foundURL == nil, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
                    if let text = loaded as? String,
                       let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
                       url.scheme?.hasPrefix("http") == true {
                        foundURL = url
                    }
                }
            }
            if foundTitle == nil, let itemTitle = item.attributedTitle?.string, !itemTitle.isEmpty {
                foundTitle = itemTitle
            }
        }

        guard let foundURL else {
            phase = .failed(String(localized: "No link found in what was shared."))
            return
        }

        url = foundURL
        title = foundTitle ?? ""

        let container = IceboxStore.makeSharedContainer()
        self.container = container
        let context = container.mainContext
        if let all = try? context.fetch(FetchDescriptor<ItemCollection>(sortBy: [SortDescriptor(\.name)])) {
            // Locked collections stay invisible here too (spec §10).
            collections = all.filter { !$0.isLocked }.map { ($0.id, $0.name) }
        }
        phase = .ready
    }

    private func save() {
        guard let url, let container else { return }
        let tags = tagText.split(whereSeparator: \.isWhitespace).map(String.init)
        let input = CaptureInput(
            url: url,
            providedTitle: title.isEmpty ? nil : title,
            note: note,
            tagNames: tags,
            collectionIDs: selectedCollectionIDs
        )
        do {
            try CaptureService.save(input, in: container.mainContext)
            withAnimation { phase = .saved }
            Task {
                try? await Task.sleep(for: .seconds(0.7))
                extensionContext?.completeRequest(returningItems: [])
            }
        } catch {
            phase = .failed(String(localized: "Couldn't save. Try again from the app."))
        }
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
    }
}
