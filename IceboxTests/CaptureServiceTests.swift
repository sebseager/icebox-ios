//
//  CaptureServiceTests.swift
//  IceboxTests
//

import Foundation
import SwiftData
import Testing
@testable import Icebox

@MainActor
struct CaptureServiceTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(IceboxStore.makeInMemoryContainer())
    }

    @Test func savingAYouTubeURLMakesACompleteVideoItem() throws {
        let context = try makeContext()
        let input = CaptureInput(url: URL(string: "https://youtu.be/dQw4w9WgXcQ?si=track")!,
                                 providedTitle: "Never Gonna Give You Up")
        let item = try CaptureService.save(input, in: context)

        #expect(item.type == .video)
        #expect(item.videoID == "dQw4w9WgXcQ")
        #expect(item.title == "Never Gonna Give You Up")
        #expect(item.thumbnailURLString == "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg")
        #expect(item.normalizedURLString == "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    }

    @Test func savingAPlainLinkNeverLooksBroken() throws {
        let context = try makeContext()
        // No title provided — falls back to the host, never a bare URL (spec §5).
        let item = try CaptureService.save(CaptureInput(url: URL(string: "https://example.com/some/post")!), in: context)
        #expect(item.type == .link)
        #expect(item.title == "example.com")
        #expect(item.siteName == "example.com")
        #expect(!item.title.isEmpty)
    }

    @Test func resavingTheSameURLUpdatesInsteadOfDuplicating() throws {
        let context = try makeContext()
        let first = try CaptureService.save(
            CaptureInput(url: URL(string: "https://example.com/a?utm_source=mail")!, providedTitle: "A", tagNames: ["one"]),
            in: context)
        let second = try CaptureService.save(
            CaptureInput(url: URL(string: "https://example.com/a")!, tagNames: ["two"]),
            in: context)

        #expect(first.id == second.id)
        #expect(try context.fetch(FetchDescriptor<SavedItem>()).count == 1)
        #expect(Set((second.tags ?? []).map(\.name)) == ["one", "two"])
        #expect(second.title == "A") // existing title not clobbered by a titleless re-save
    }

    @Test func tagsFindOrCreateCaseInsensitively() throws {
        let context = try makeContext()
        _ = try CaptureService.save(CaptureInput(url: URL(string: "https://a.example")!, tagNames: ["Physics"]), in: context)
        _ = try CaptureService.save(CaptureInput(url: URL(string: "https://b.example")!, tagNames: ["physics"]), in: context)
        #expect(try context.fetch(FetchDescriptor<Icebox.Tag>()).count == 1)
    }

    @Test func savingIntoACollectionAppendsInOrder() throws {
        let context = try makeContext()
        let collection = ItemCollection()
        collection.name = "Queue"
        context.insert(collection)
        try context.save()

        let a = try CaptureService.save(CaptureInput(url: URL(string: "https://a.example")!, collectionIDs: [collection.id]), in: context)
        let b = try CaptureService.save(CaptureInput(url: URL(string: "https://b.example")!, collectionIDs: [collection.id]), in: context)

        #expect(collection.orderedItems.map(\.id) == [a.id, b.id])
    }

    @Test func addItemToCollectionIsIdempotent() throws {
        let context = try makeContext()
        let collection = ItemCollection()
        context.insert(collection)
        let item = try CaptureService.save(CaptureInput(url: URL(string: "https://a.example")!), in: context)
        CaptureService.addItem(item, to: collection, in: context)
        CaptureService.addItem(item, to: collection, in: context)
        #expect(collection.orderedEntries.count == 1)
    }
}
