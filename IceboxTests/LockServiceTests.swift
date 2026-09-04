//
//  LockServiceTests.swift
//  IceboxTests
//

import Foundation
import SwiftData
import Testing
@testable import Icebox

@MainActor
struct LockServiceTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(IceboxStore.makeInMemoryContainer())
    }

    private func addItem(to collection: ItemCollection, in context: ModelContext) -> SavedItem {
        let item = SavedItem()
        context.insert(item)
        let entry = CollectionEntry()
        entry.item = item
        entry.collection = collection
        context.insert(entry)
        return item
    }

    @Test func lockingACollectionHidesItsItems() throws {
        let context = try makeContext()
        let collection = ItemCollection()
        context.insert(collection)
        let item = addItem(to: collection, in: context)
        try context.save()
        #expect(!item.isInLockedCollection)

        LockService.setLocked(true, for: collection, in: context)
        #expect(collection.isLocked)
        #expect(item.isInLockedCollection)

        LockService.setLocked(false, for: collection, in: context)
        #expect(!item.isInLockedCollection)
    }

    @Test func itemInTwoLockedCollectionsStaysHiddenUntilBothUnlock() throws {
        let context = try makeContext()
        let a = ItemCollection()
        let b = ItemCollection()
        context.insert(a)
        context.insert(b)
        let item = addItem(to: a, in: context)
        let entry = CollectionEntry()
        entry.item = item
        entry.collection = b
        context.insert(entry)
        try context.save()

        LockService.setLocked(true, for: a, in: context)
        LockService.setLocked(true, for: b, in: context)
        LockService.setLocked(false, for: a, in: context)
        #expect(item.isInLockedCollection) // still in locked b

        LockService.setLocked(false, for: b, in: context)
        #expect(!item.isInLockedCollection)
    }

    @Test func refreshFixesStaleFlags() throws {
        let context = try makeContext()
        let collection = ItemCollection()
        collection.isLocked = true
        collection.showsInLibrary = false
        context.insert(collection)
        let hidden = addItem(to: collection, in: context)

        let loose = SavedItem()
        loose.isInLockedCollection = true // stale — belongs to nothing
        loose.isHiddenFromLibrary = true
        context.insert(loose)
        try context.save()

        LockService.refreshFlags(in: context)
        #expect(hidden.isInLockedCollection)
        #expect(hidden.isHiddenFromLibrary)
        #expect(!loose.isInLockedCollection)
        #expect(!loose.isHiddenFromLibrary)
    }

    @Test func hidingACollectionHidesItsItemsFromLibrary() throws {
        let context = try makeContext()
        let collection = ItemCollection()
        context.insert(collection)
        let item = addItem(to: collection, in: context)
        try context.save()
        #expect(!item.isHiddenFromLibrary)

        LockService.setShowsInLibrary(false, for: collection, in: context)
        #expect(!collection.showsInLibrary)
        #expect(item.isHiddenFromLibrary)

        LockService.setShowsInLibrary(true, for: collection, in: context)
        #expect(!item.isHiddenFromLibrary)
    }

    @Test func addingToHiddenCollectionHidesImmediately() throws {
        let context = try makeContext()
        let collection = ItemCollection()
        collection.showsInLibrary = false
        context.insert(collection)
        let item = SavedItem()
        context.insert(item)
        try context.save()

        CaptureService.addItem(item, to: collection, in: context)
        #expect(item.isHiddenFromLibrary)
    }

    @Test func removingEntryRecomputesFlags() throws {
        let context = try makeContext()
        let collection = ItemCollection()
        collection.isLocked = true
        collection.showsInLibrary = false
        context.insert(collection)
        let item = addItem(to: collection, in: context)
        try context.save()
        LockService.refreshFlags(in: context)
        #expect(item.isInLockedCollection)
        #expect(item.isHiddenFromLibrary)

        let entry = try #require((collection.entries ?? []).first)
        LockService.removeEntry(entry, in: context)
        #expect(!item.isInLockedCollection)
        #expect(!item.isHiddenFromLibrary)
        #expect(try context.fetch(FetchDescriptor<CollectionEntry>()).isEmpty)
    }

    @Test func deletingCollectionUnhidesFormerMembers() throws {
        let context = try makeContext()
        let collection = ItemCollection()
        collection.showsInLibrary = false
        context.insert(collection)
        let item = addItem(to: collection, in: context)
        try context.save()
        LockService.refreshFlags(in: context)
        #expect(item.isHiddenFromLibrary)

        LockService.deleteCollection(collection, in: context)
        #expect(!item.isHiddenFromLibrary)
        #expect(try context.fetch(FetchDescriptor<ItemCollection>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SavedItem>()).count == 1)
    }
}
