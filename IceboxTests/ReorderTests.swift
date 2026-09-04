//
//  ReorderTests.swift
//  IceboxTests
//

import Foundation
import SwiftData
import Testing
@testable import Icebox

struct ReorderTests {

    @Test func moveSemanticsMatchSwiftUI() {
        #expect(movedElements([0, 1, 2, 3], fromOffsets: [1], toOffset: 3) == [0, 2, 1, 3])
        #expect(movedElements([0, 1, 2, 3], fromOffsets: [3], toOffset: 0) == [3, 0, 1, 2])
        #expect(movedElements([0, 1, 2, 3], fromOffsets: [0, 2], toOffset: 4) == [1, 3, 0, 2])
        #expect(movedElements([0], fromOffsets: [0], toOffset: 0) == [0])
    }

    @MainActor
    @Test func reorderingRewritesPositionsInOrder() throws {
        let context = try ModelContext(IceboxStore.makeInMemoryContainer())
        let collection = ItemCollection()
        context.insert(collection)
        var titles: [String] = []
        for i in 0..<4 {
            let item = SavedItem()
            item.title = "Item \(i)"
            titles.append(item.title)
            context.insert(item)
            let entry = CollectionEntry()
            entry.position = Double(i)
            entry.item = item
            entry.collection = collection
            context.insert(entry)
        }
        try context.save()

        // Simulate what CollectionDetailView does on move.
        let reordered = movedElements(collection.orderedEntries, fromOffsets: [0], toOffset: 3)
        for (index, entry) in reordered.enumerated() {
            entry.position = Double(index)
        }
        try context.save()

        #expect(collection.orderedItems.map(\.title) == ["Item 1", "Item 2", "Item 0", "Item 3"])
    }
}
