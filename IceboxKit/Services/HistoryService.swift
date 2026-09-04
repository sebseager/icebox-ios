//
//  HistoryService.swift
//  Icebox
//

import Foundation
import SwiftData

/// Records every open — reader, browser hand-off, or playlist send. History
/// is per item and accumulates over years (spec §8). We only know the user
/// opened something from here; what happened afterward is not ours to know.
@MainActor
enum HistoryService {

    static func recordOpen(_ item: SavedItem, method: OpenMethod, in context: ModelContext) {
        let event = OpenEvent()
        event.method = method
        event.item = item
        context.insert(event)
        item.lastOpened = event.date
        try? context.save()
    }
}
