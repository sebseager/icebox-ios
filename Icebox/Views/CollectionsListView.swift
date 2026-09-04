//
//  CollectionsListView.swift
//  Icebox
//

import SwiftUI
import SwiftData

struct CollectionsListView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppLockManager.self) private var lock

    @Query(sort: \ItemCollection.dateCreated) private var collections: [ItemCollection]
    @Query(sort: \Tag.name) private var tags: [Tag]
    @State private var showsNewAlert = false
    @State private var newName = ""

    private var visibleCollections: [ItemCollection] {
        collections.filter { !$0.isLocked || lock.areLockedCollectionsRevealed }
    }

    var body: some View {
        NavigationStack {
            List {
                if !visibleCollections.isEmpty {
                    Section("Collections") {
                        ForEach(visibleCollections) { collection in
                            NavigationLink {
                                CollectionDetailView(collection: collection)
                            } label: {
                                HStack {
                                    Label {
                                        Text(collection.name)
                                    } icon: {
                                        Image(systemName: collection.isLocked ? "lock.square.stack" : "square.stack")
                                    }
                                    Spacer()
                                    Text("\(collection.orderedEntries.count)")
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                LockService.deleteCollection(visibleCollections[index], in: context)
                            }
                        }
                    }
                }
                if !tags.isEmpty {
                    Section("Tags") {
                        ForEach(tags) { tag in
                            NavigationLink {
                                ItemListView(filter: SearchFilter(tagName: tag.name))
                                    .navigationTitle(tag.name)
                            } label: {
                                HStack {
                                    Label(tag.name, systemImage: "number")
                                    Spacer()
                                    Text("\(visibleCount(for: tag))")
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                context.delete(tags[index])
                            }
                        }
                    }
                }
            }
            .overlay {
                if visibleCollections.isEmpty && tags.isEmpty {
                    ContentUnavailableView(
                        "No collections",
                        systemImage: "square.stack",
                        description: Text("Collections keep things in the order you choose. Tags you add to items show up here too.")
                    )
                }
            }
            .navigationTitle("Collections")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newName = ""
                        showsNewAlert = true
                    } label: {
                        Label("New Collection", systemImage: "plus")
                    }
                }
                ToolbarItem {
                    // A static control: revealing locked collections always
                    // requires authentication, and their absence from the
                    // list says nothing about whether any exist (spec §10).
                    Button {
                        Task { await lock.revealLockedCollections() }
                    } label: {
                        Label("Show Locked", systemImage: lock.areLockedCollectionsRevealed ? "lock.open" : "lock")
                    }
                    .disabled(lock.areLockedCollectionsRevealed)
                }
            }
            .alert("New Collection", isPresented: $showsNewAlert) {
                TextField("Name", text: $newName)
                Button("Create") {
                    let name = newName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    let collection = ItemCollection()
                    collection.name = name
                    context.insert(collection)
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func visibleCount(for tag: Tag) -> Int {
        (tag.items ?? []).filter { !$0.isInLockedCollection }.count
    }
}
