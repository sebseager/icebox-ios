//
//  LibraryExporterTests.swift
//  IceboxTests
//

import Foundation
import SwiftData
import Testing
@testable import Icebox

@MainActor
struct LibraryExporterTests {

    private func seed() throws -> ModelContext {
        let context = try ModelContext(IceboxStore.makeInMemoryContainer())

        let video = try CaptureService.save(
            CaptureInput(url: URL(string: "https://youtu.be/dQw4w9WgXcQ")!, providedTitle: "A Video", tagNames: ["music"]),
            in: context)
        HistoryService.recordOpen(video, method: .playlist, in: context)

        let article = try CaptureService.save(
            CaptureInput(url: URL(string: "https://example.com/story")!, providedTitle: "A Story"), in: context)
        let offline = OfflineArticle()
        offline.plainText = "the story text"
        offline.contentHTML = Data("<p>the story text</p>".utf8)
        offline.byline = "Jane Doe"
        offline.item = article
        context.insert(offline)

        let queue = ItemCollection()
        queue.name = "Queue"
        context.insert(queue)
        CaptureService.addItem(article, to: queue, in: context)
        CaptureService.addItem(video, to: queue, in: context)

        let secretItem = try CaptureService.save(
            CaptureInput(url: URL(string: "https://example.com/secret")!, providedTitle: "Secret"), in: context)
        let vault = ItemCollection()
        vault.name = "Vault"
        context.insert(vault)
        CaptureService.addItem(secretItem, to: vault, in: context)
        LockService.setLocked(true, for: vault, in: context)

        try context.save()
        return context
    }

    private func export(_ context: ModelContext, _ options: ExportOptions = ExportOptions()) throws -> [String: Any] {
        let data = try LibraryExporter.export(context: context, options: options)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func exportIsReadableJSONWithEverything() throws {
        let context = try seed()
        let root = try export(context)

        #expect(root["formatVersion"] as? Int == 1)
        let items = try #require(root["items"] as? [[String: Any]])
        #expect(items.count == 2) // locked item excluded by default

        let video = try #require(items.first { $0["title"] as? String == "A Video" })
        #expect(video["type"] as? String == "video")
        #expect(video["videoID"] as? String == "dQw4w9WgXcQ")
        #expect((video["tags"] as? [String]) == ["music"])
        let history = try #require(video["history"] as? [[String: Any]])
        #expect(history.count == 1)
        #expect(history[0]["method"] as? String == "playlist")

        let article = try #require(items.first { $0["title"] as? String == "A Story" })
        let offline = try #require(article["article"] as? [String: Any])
        #expect(offline["plainText"] as? String == "the story text")
        #expect((offline["contentHTML"] as? String)?.contains("<p>") == true)
        #expect(offline["byline"] as? String == "Jane Doe")
    }

    @Test func collectionsCarryOrder() throws {
        let context = try seed()
        let root = try export(context)
        let collections = try #require(root["collections"] as? [[String: Any]])
        #expect(collections.count == 1) // vault hidden

        let queue = try #require(collections.first { $0["name"] as? String == "Queue" })
        let itemIDs = try #require(queue["itemIDs"] as? [String])
        #expect(itemIDs.count == 2)

        // Order must match the collection's manual order: article then video.
        let items = try #require(root["items"] as? [[String: Any]])
        let articleID = try #require(items.first { $0["title"] as? String == "A Story" }?["id"] as? String)
        let videoID = try #require(items.first { $0["title"] as? String == "A Video" }?["id"] as? String)
        #expect(itemIDs == [articleID, videoID])
    }

    @Test func lockedContentExportsOnlyOnRequest() throws {
        let context = try seed()
        let root = try export(context, ExportOptions(includeLocked: true))
        let items = try #require(root["items"] as? [[String: Any]])
        #expect(items.count == 3)
        let collections = try #require(root["collections"] as? [[String: Any]])
        #expect(collections.contains { $0["name"] as? String == "Vault" && $0["isLocked"] as? Bool == true })
    }
}
