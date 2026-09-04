//
//  StatisticsView.swift
//  Icebox
//
//  Personal and reflective, not gamified. No streaks, no nagging, no guilt
//  about the backlog (spec §8). Lives in Settings: the saves-over-time chart
//  shows there, and this view has everything else.
//

import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Query(filter: #Predicate<SavedItem> { !$0.isInLockedCollection })
    private var items: [SavedItem]

    var body: some View {
        List {
            summarySection
            Section("Saved over the last year") {
                SavedOverTimeChart(items: items)
            }
            sourcesSection
        }
        .navigationTitle("Statistics")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var summarySection: some View {
        Section {
            LabeledContent("Saved", value: "\(items.count)")
            LabeledContent("Opened at least once", value: "\(StatsCalculator.openedCount(items: items))")
            LabeledContent("Waiting quietly", value: "\(StatsCalculator.untouchedCount(items: items))")
            LabeledContent("Total opens", value: "\(StatsCalculator.totalOpens(items: items))")
            LabeledContent("Saved offline") {
                Text("\(StatsCalculator.offlineCount(items: items)) · \(StatsCalculator.offlineBytes(items: items).formatted(.byteCount(style: .file)))")
            }
        }
    }

    private var sourcesSection: some View {
        Section("Where things come from") {
            let sources = StatsCalculator.topSources(items: items)
            if sources.isEmpty {
                Text("No sources yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sources, id: \.name) { source in
                    LabeledContent(source.name, value: "\(source.count)")
                }
            }
        }
    }
}

/// The one glanceable graph: saves per month for the last year. Shown in
/// Settings and again in the full statistics view.
struct SavedOverTimeChart: View {
    let items: [SavedItem]

    var body: some View {
        let buckets = StatsCalculator.savesPerMonth(items: items)
        if buckets.allSatisfy({ $0.count == 0 }) {
            Text("Nothing yet — your first saves will show up here.")
                .foregroundStyle(.secondary)
        } else {
            Chart(buckets, id: \.month) { bucket in
                BarMark(
                    x: .value("Month", bucket.month, unit: .month),
                    y: .value("Saved", bucket.count)
                )
                .foregroundStyle(.tint)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 3)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.narrow))
                }
            }
            .frame(height: 160)
            .padding(.vertical, 4)
        }
    }
}
