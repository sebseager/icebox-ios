//
//  HistoryServiceTests.swift
//  IceboxTests
//

import Foundation
import SwiftData
import Testing
@testable import Icebox

@MainActor
struct HistoryServiceTests {

    @Test func openingRecordsAnEventAndBumpsLastOpened() throws {
        let context = try ModelContext(IceboxStore.makeInMemoryContainer())
        let item = SavedItem()
        context.insert(item)
        #expect(item.lastOpened == nil)

        HistoryService.recordOpen(item, method: .reader, in: context)
        HistoryService.recordOpen(item, method: .playlist, in: context)

        #expect(item.openEvents?.count == 2)
        let latest = item.sortedOpenEvents.first
        #expect(latest?.method == .playlist)
        #expect(item.lastOpened == latest?.date)
    }

    @Test func historyAccumulatesRatherThanReplacing() throws {
        let context = try ModelContext(IceboxStore.makeInMemoryContainer())
        let item = SavedItem()
        context.insert(item)
        for _ in 0..<5 {
            HistoryService.recordOpen(item, method: .browser, in: context)
        }
        #expect(item.openEvents?.count == 5)
    }
}
