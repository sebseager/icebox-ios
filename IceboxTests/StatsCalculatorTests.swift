//
//  StatsCalculatorTests.swift
//  IceboxTests
//

import Foundation
import SwiftData
import Testing
@testable import Icebox

@MainActor
struct StatsCalculatorTests {

    private func makeItems(_ configure: (Int, SavedItem) -> Void, count: Int) throws -> [SavedItem] {
        let context = try ModelContext(IceboxStore.makeInMemoryContainer())
        var items: [SavedItem] = []
        for i in 0..<count {
            let item = SavedItem()
            configure(i, item)
            context.insert(item)
            items.append(item)
        }
        try context.save()
        return items
    }

    @Test func savesPerMonthBucketsCorrectly() throws {
        let calendar = Calendar.current
        let now = Date()
        let items = try makeItems({ i, item in
            // 2 items this month, 1 last month, 1 long ago (outside window).
            switch i {
            case 0, 1: item.dateSaved = now
            case 2: item.dateSaved = calendar.date(byAdding: .month, value: -1, to: now)!
            default: item.dateSaved = calendar.date(byAdding: .year, value: -3, to: now)!
            }
        }, count: 4)

        let buckets = StatsCalculator.savesPerMonth(items: items, monthsBack: 3, now: now, calendar: calendar)
        #expect(buckets.count == 3)
        #expect(buckets[2].count == 2) // this month, newest last
        #expect(buckets[1].count == 1)
        #expect(buckets[0].count == 0)
        #expect(buckets.map(\.month) == buckets.map(\.month).sorted())
    }

    @Test func openAndOfflineCounts() throws {
        let items = try makeItems({ i, item in
            if i < 2 { item.lastOpened = Date() }
            if i == 0 {
                let article = OfflineArticle()
                article.contentHTML = Data("x".utf8)
                article.isFullArchive = true
                item.article = article
            }
        }, count: 5)

        #expect(StatsCalculator.openedCount(items: items) == 2)
        #expect(StatsCalculator.untouchedCount(items: items) == 3)
        #expect(StatsCalculator.offlineCount(items: items) == 1)
        #expect(StatsCalculator.offlineBytes(items: items) == 1)
    }

    @Test func topSourcesRankAndTieBreak() throws {
        let items = try makeItems({ i, item in
            item.siteName = ["youtube.com", "youtube.com", "example.com", "blog.net", "blog.net", ""][i]
        }, count: 6)

        let sources = StatsCalculator.topSources(items: items, limit: 2)
        #expect(sources.map(\.name) == ["blog.net", "youtube.com"]) // tie broken alphabetically
        #expect(sources.map(\.count) == [2, 2])
    }
}
