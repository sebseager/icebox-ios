//
//  StatsCalculator.swift
//  Icebox
//

import Foundation

/// Aggregations behind the statistics view (spec §8). Callers pass items
/// already filtered for locked collections.
@MainActor
enum StatsCalculator {

    struct MonthBucket: Equatable {
        let month: Date
        let count: Int
    }

    struct Source: Equatable {
        let name: String
        let count: Int
    }

    /// Saves per calendar month for the last `monthsBack` months, oldest
    /// first, including empty months.
    static func savesPerMonth(items: [SavedItem], monthsBack: Int = 12,
                              now: Date = Date(), calendar: Calendar = .current) -> [MonthBucket] {
        guard monthsBack > 0, let thisMonth = calendar.dateInterval(of: .month, for: now)?.start else { return [] }
        var buckets: [Date: Int] = [:]
        var months: [Date] = []
        for offset in stride(from: monthsBack - 1, through: 0, by: -1) {
            if let month = calendar.date(byAdding: .month, value: -offset, to: thisMonth) {
                months.append(month)
                buckets[month] = 0
            }
        }
        for item in items {
            guard let month = calendar.dateInterval(of: .month, for: item.dateSaved)?.start else { continue }
            if buckets[month] != nil {
                buckets[month]! += 1
            }
        }
        return months.map { MonthBucket(month: $0, count: buckets[$0] ?? 0) }
    }

    static func openedCount(items: [SavedItem]) -> Int {
        items.count { $0.lastOpened != nil }
    }

    static func untouchedCount(items: [SavedItem]) -> Int {
        items.count { $0.lastOpened == nil }
    }

    static func totalOpens(items: [SavedItem]) -> Int {
        items.reduce(0) { $0 + ($1.openEvents?.count ?? 0) }
    }

    static func offlineCount(items: [SavedItem]) -> Int {
        items.count(where: \.hasOfflineArticle)
    }

    static func offlineBytes(items: [SavedItem]) -> Int {
        items.reduce(0) { $0 + ($1.article?.byteCount ?? 0) }
    }

    /// Where things come from, by site, most-saved first.
    static func topSources(items: [SavedItem], limit: Int = 6) -> [Source] {
        var counts: [String: Int] = [:]
        for item in items where !item.siteName.isEmpty {
            counts[item.siteName, default: 0] += 1
        }
        return counts
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(limit)
            .map { Source(name: $0.key, count: $0.value) }
    }
}
