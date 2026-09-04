//
//  ModelTests.swift
//  IceboxTests
//

import Foundation
import SwiftData
import Testing
@testable import Icebox

@MainActor
struct ModelTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(IceboxStore.makeInMemoryContainer())
    }

    @Test func itemRoundTrip() throws {
        let context = try makeContext()
        let item = SavedItem()
        item.urlString = "https://example.com/a"
        item.title = "An Article"
        item.type = .link
        context.insert(item)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SavedItem>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.title == "An Article")
        #expect(fetched.first?.type == .link)
        #expect(fetched.first?.url == URL(string: "https://example.com/a"))
    }

    @Test func collectionOrderingFollowsPosition() throws {
        let context = try makeContext()
        let collection = ItemCollection()
        collection.name = "Queue"
        context.insert(collection)

        var titles: [String] = []
        for (i, position) in [3.0, 1.0, 2.0].enumerated() {
            let item = SavedItem()
            item.title = "Item \(i)"
            titles.append(item.title)
            context.insert(item)
            let entry = CollectionEntry()
            entry.position = position
            entry.item = item
            entry.collection = collection
            context.insert(entry)
        }
        try context.save()

        let ordered = collection.orderedItems.map(\.title)
        #expect(ordered == ["Item 1", "Item 2", "Item 0"])
    }

    @Test func deletingItemCascadesOwnedRecords() throws {
        let context = try makeContext()
        let item = SavedItem()
        context.insert(item)

        let event = OpenEvent()
        event.item = item
        context.insert(event)

        let article = OfflineArticle()
        article.item = item
        context.insert(article)

        let collection = ItemCollection()
        context.insert(collection)
        let entry = CollectionEntry()
        entry.item = item
        entry.collection = collection
        context.insert(entry)
        try context.save()

        context.delete(item)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<OpenEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<OfflineArticle>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CollectionEntry>()).isEmpty)
        // The collection itself survives.
        #expect(try context.fetch(FetchDescriptor<ItemCollection>()).count == 1)
    }

    @Test func deletingCollectionCascadesEntriesButKeepsItems() throws {
        let context = try makeContext()
        let item = SavedItem()
        context.insert(item)
        let collection = ItemCollection()
        context.insert(collection)
        let entry = CollectionEntry()
        entry.item = item
        entry.collection = collection
        context.insert(entry)
        try context.save()

        context.delete(collection)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<CollectionEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SavedItem>()).count == 1)
    }

    @Test func playlistEligibility() throws {
        let context = try makeContext()
        let collection = ItemCollection()
        context.insert(collection)
        #expect(!collection.isPlaylistEligible) // empty is not eligible

        let video = SavedItem()
        video.type = .video
        video.videoID = "dQw4w9WgXcQ"
        context.insert(video)
        let entry = CollectionEntry()
        entry.item = video
        entry.collection = collection
        context.insert(entry)
        try context.save()
        #expect(collection.isPlaylistEligible)

        let link = SavedItem()
        link.type = .link
        context.insert(link)
        let entry2 = CollectionEntry()
        entry2.position = 1
        entry2.item = link
        entry2.collection = collection
        context.insert(entry2)
        try context.save()
        #expect(!collection.isPlaylistEligible) // mixed collection is just a collection
    }

    @Test func tagsAreManyToMany() throws {
        let context = try makeContext()
        let tag = Icebox.Tag() // qualified: Testing also exports a `Tag` type
        tag.name = "physics"
        context.insert(tag)
        let a = SavedItem()
        let b = SavedItem()
        context.insert(a)
        context.insert(b)
        a.tags = [tag]
        b.tags = [tag]
        try context.save()

        #expect(tag.items?.count == 2)

        context.delete(a)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Icebox.Tag>()).count == 1)
        #expect(tag.items?.count == 1)
    }
}
