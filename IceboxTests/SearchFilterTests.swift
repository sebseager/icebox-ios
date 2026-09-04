//
//  SearchFilterTests.swift
//  IceboxTests
//

import Foundation
import SwiftData
import Testing
@testable import Icebox

@MainActor
struct SearchFilterTests {

    /// Seeds: a video, an article with offline full text, a noted link,
    /// and an item hidden inside a locked collection.
    private func seed() throws -> ModelContext {
        let context = try ModelContext(IceboxStore.makeInMemoryContainer())

        let video = try CaptureService.save(
            CaptureInput(url: URL(string: "https://youtu.be/dQw4w9WgXcQ")!, providedTitle: "Rick Astley"), in: context)
        video.lastOpened = Date()

        let article = try CaptureService.save(
            CaptureInput(url: URL(string: "https://example.com/physics")!, providedTitle: "A Physics Story", tagNames: ["science"]),
            in: context)
        let offline = OfflineArticle()
        offline.plainText = "a long treatise on quantum gravity"
        offline.contentHTML = Data("<p>hi</p>".utf8)
        offline.isFullArchive = true
        offline.item = article
        context.insert(offline)

        _ = try CaptureService.save(
            CaptureInput(url: URL(string: "https://example.com/recipe")!, providedTitle: "Dinner", note: "make on Friday"),
            in: context)

        let secret = try CaptureService.save(
            CaptureInput(url: URL(string: "https://example.com/secret")!, providedTitle: "quantum secret"), in: context)
        let locked = ItemCollection()
        locked.name = "Private"
        context.insert(locked)
        CaptureService.addItem(secret, to: locked, in: context)
        LockService.setLocked(true, for: locked, in: context)

        try context.save()
        return context
    }

    private func fetch(_ filter: SearchFilter, _ context: ModelContext) throws -> [String] {
        try filter.results(in: context).map(\.title).sorted()
    }

    @Test func textSearchSpansTitleNoteAndOfflineFullText() throws {
        let context = try seed()
        #expect(try fetch(SearchFilter(text: "physics"), context) == ["A Physics Story"])
        #expect(try fetch(SearchFilter(text: "friday"), context) == ["Dinner"])
        // Full text of the archived article, not just metadata (spec §14).
        #expect(try fetch(SearchFilter(text: "quantum gravity"), context) == ["A Physics Story"])
    }

    @Test func lockedItemsNeverSurface() throws {
        let context = try seed()
        // "quantum" appears in the locked item's title too — it must not show.
        #expect(try fetch(SearchFilter(text: "quantum"), context) == ["A Physics Story"])
        #expect(try fetch(SearchFilter(), context).count == 3)
    }

    @Test func structuredFilters() throws {
        let context = try seed()
        #expect(try fetch(SearchFilter(type: .video), context) == ["Rick Astley"])
        #expect(try fetch(SearchFilter(tagName: "science"), context) == ["A Physics Story"])
        #expect(try fetch(SearchFilter(offlineOnly: true), context) == ["A Physics Story"])
        #expect(try fetch(SearchFilter(neverOpened: true), context) == ["A Physics Story", "Dinner"])
    }

    @Test func hiddenCollectionItemsLeaveTheLibraryButNotTheirCollection() throws {
        let context = try seed()
        let archive = ItemCollection()
        archive.name = "Archive"
        archive.showsInLibrary = false
        context.insert(archive)
        let dinner = try #require(try SearchFilter(text: "Dinner").results(in: context).first)
        CaptureService.addItem(dinner, to: archive, in: context)
        try context.save()

        // Gone from the library and plain search…
        #expect(try fetch(SearchFilter(), context) == ["A Physics Story", "Rick Astley"])
        #expect(try fetch(SearchFilter(text: "Dinner"), context).isEmpty)
        // …but still there when filtering by the collection itself.
        #expect(try fetch(SearchFilter(collectionID: archive.id), context) == ["Dinner"])
    }

    @Test func codableRoundTrip() throws {
        var filter = SearchFilter(text: "hello", type: .video, offlineOnly: true)
        filter.tagName = "science"
        let data = try #require(filter.encoded())
        #expect(SearchFilter.decode(data) == filter)
        #expect(SearchFilter.decode(nil) == nil)
    }
}
