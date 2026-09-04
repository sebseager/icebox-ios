//
//  ItemRowView.swift
//  Icebox
//

import SwiftUI

struct ItemRowView: View {
    let item: SavedItem

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.body)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(subtitle)
                        .lineLimit(1)
                    if let duration = item.durationSeconds {
                        Text(Self.formatted(duration: duration))
                            .monospacedDigit()
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                // Items never opened simply don't show it (spec §8).
                if let lastOpened = item.lastOpened {
                    Text("Opened \(lastOpened, format: .relative(presentation: .named))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)

            if item.hasOfflineArticle {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
                    .accessibilityLabel("Saved offline")
            }
        }
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        if !item.author.isEmpty { return item.author }
        if !item.siteName.isEmpty { return item.siteName }
        return item.url?.host() ?? ""
    }

    @ViewBuilder
    private var thumbnail: some View {
        let shape = RoundedRectangle(cornerRadius: 6)
        if item.isVideo, let url = item.thumbnailURL {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                shape.fill(.quaternary)
            }
            .frame(width: 68, height: 38)
            .clipShape(shape)
            .accessibilityHidden(true)
        } else {
            shape.fill(.quaternary)
                .overlay(
                    Image(systemName: item.hasOfflineArticle ? "doc.text" : "link")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                )
                .frame(width: 38, height: 38)
                .accessibilityHidden(true)
        }
    }

    static func formatted(duration seconds: Int) -> String {
        let duration = Duration.seconds(seconds)
        let pattern: Duration.TimeFormatStyle.Pattern = seconds >= 3600 ? .hourMinuteSecond : .minuteSecond
        return duration.formatted(.time(pattern: pattern))
    }
}
