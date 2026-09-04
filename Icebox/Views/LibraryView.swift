//
//  LibraryView.swift
//  Icebox
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \SmartList.name) private var smartLists: [SmartList]
    @State private var searchText = ""
    @State private var typeFilter: ItemType?
    @State private var offlineOnly = false
    @State private var neverOpened = false
    @State private var showsAddSheet = false
    @State private var activeSmartList: SmartList?
    @State private var showsSaveSmartList = false
    @State private var smartListName = ""

    private var filter: SearchFilter {
        if let activeSmartList, var stored = SearchFilter.decode(activeSmartList.filterData) {
            if !searchText.isEmpty { stored.text = searchText }
            return stored
        }
        return SearchFilter(text: searchText, type: typeFilter, offlineOnly: offlineOnly, neverOpened: neverOpened)
    }

    var body: some View {
        NavigationStack {
            ItemListView(filter: filter)
                .id(filter)
                .navigationTitle(activeSmartList?.name ?? "Library")
                .searchable(text: $searchText, prompt: "Search your library")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showsAddSheet = true
                        } label: {
                            Label("Add Link", systemImage: "plus")
                        }
                    }
                    ToolbarItem {
                        filterMenu
                    }
                }
                .sheet(isPresented: $showsAddSheet) {
                    AddItemView()
                }
                .alert("New Smart List", isPresented: $showsSaveSmartList) {
                    TextField("Name", text: $smartListName)
                    Button("Save") { saveSmartList() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Keeps this filter as a list that stays current.")
                }
        }
    }

    private var filterMenu: some View {
        Menu {
            if !smartLists.isEmpty {
                Section("Smart Lists") {
                    ForEach(smartLists) { list in
                        Button {
                            activeSmartList = activeSmartList?.id == list.id ? nil : list
                        } label: {
                            if activeSmartList?.id == list.id {
                                Label(list.name, systemImage: "checkmark")
                            } else {
                                Text(list.name)
                            }
                        }
                    }
                }
            }
            if let activeSmartList {
                Button("Stop Using \(activeSmartList.name)") { self.activeSmartList = nil }
                Button("Delete \(activeSmartList.name)", role: .destructive) {
                    context.delete(activeSmartList)
                    self.activeSmartList = nil
                }
            } else {
                Picker("Type", selection: $typeFilter) {
                    Text("Everything").tag(ItemType?.none)
                    Text("Videos").tag(ItemType?.some(.video))
                    Text("Links").tag(ItemType?.some(.link))
                }
                Toggle("Saved Offline", isOn: $offlineOnly)
                Toggle("Never Opened", isOn: $neverOpened)
                if filterIsActive {
                    Button("Save as Smart List…", systemImage: "plus.square.on.square") {
                        smartListName = ""
                        showsSaveSmartList = true
                    }
                }
            }
        } label: {
            Label("Filter", systemImage: filterIsActive || activeSmartList != nil
                  ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }

    private var filterIsActive: Bool {
        typeFilter != nil || offlineOnly || neverOpened
    }

    private func saveSmartList() {
        let name = smartListName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let list = SmartList()
        list.name = name
        list.filterData = filter.encoded()
        context.insert(list)
    }
}

/// The item list for a given filter. Rows open on tap — the library is for
/// getting back to things, and detail is one swipe away.
struct ItemListView: View {
    @Environment(\.modelContext) private var context
    @Environment(Navigator.self) private var navigator
    @Environment(OpenSettings.self) private var openSettings
    @Environment(\.openURL) private var openURL

    @Query private var items: [SavedItem]
    @State private var detailItem: SavedItem?
    private let filter: SearchFilter

    init(filter: SearchFilter) {
        self.filter = filter
        var descriptor = FetchDescriptor<SavedItem>(predicate: filter.predicate)
        descriptor.sortBy = [SortDescriptor(\.dateSaved, order: .reverse)]
        _items = Query(descriptor)
    }

    var body: some View {
        let visible = items.filter(filter.matchesStructuredFilters)
        List {
            ForEach(visible) { item in
                Button {
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
                        ItemDeleter.delete(item, in: context)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button("Details", systemImage: "info.circle") { detailItem = item }
                    Button("Open in Browser", systemImage: "safari") {
                        ItemOpener.openInBrowser(item, openURL: openURL, context: context)
                    }
                    if item.type == .link {
                        Button("Open in Reader", systemImage: "doc.plaintext") {
                            ItemOpener.openReader(item, navigator: navigator, context: context)
                        }
                        if !item.hasOfflineArticle {
                            Button("Save Offline", systemImage: "arrow.down.circle") {
                                Task { try? await ArchiveService.archive(item, in: context) }
                            }
                        }
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        ItemDeleter.delete(item, in: context)
                    }
                }
            }
        }
        .overlay {
            if visible.isEmpty {
                if filter.isEmpty {
                    ContentUnavailableView(
                        "Nothing saved yet",
                        systemImage: "tray",
                        description: Text("Share a link from any app, or tap + to paste one.")
                    )
                } else {
                    ContentUnavailableView.search
                }
            }
        }
        .navigationDestination(item: $detailItem) { item in
            ItemDetailView(item: item)
        }
    }
}
