//
//  PlaylistBuilderTests.swift
//  IceboxTests
//

import Foundation
import Testing
@testable import Icebox

struct PlaylistBuilderTests {

    private func ids(_ n: Int) -> [String] {
        (0..<n).map { String(format: "vid%08d", $0) } // 11 chars each
    }

    @Test func twelveVideosPlayFromTheTop() throws {
        let window = try #require(PlaylistBuilder.playlist(videoIDs: ids(12)))
        #expect(window.range == 0..<12)
        #expect(!window.isWindowed)
        #expect(window.url.absoluteString == "https://www.youtube.com/watch_videos?video_ids=" + ids(12).joined(separator: ","))
    }

    @Test func tappingAnItemStartsThere() throws {
        let window = try #require(PlaylistBuilder.playlist(videoIDs: ids(12), startingAt: 5))
        #expect(window.range == 5..<12)
        #expect(window.url.query()?.contains("vid00000005,") == true)
        #expect(window.url.query()?.contains("vid00000004") == false)
    }

    @Test func longCollectionsWindowRatherThanFail() throws {
        // Spec §6: tapping item 50 of 120 sends items 50 forward to the cap.
        let window = try #require(PlaylistBuilder.playlist(videoIDs: ids(120), startingAt: 49))
        #expect(window.range == 49..<99)
        #expect(window.isWindowed)

        let fromTop = try #require(PlaylistBuilder.playlist(videoIDs: ids(120)))
        #expect(fromTop.range == 0..<50)
        #expect(fromTop.isWindowed)
    }

    @Test func lastItemSendsPlainWatchURL() throws {
        let window = try #require(PlaylistBuilder.playlist(videoIDs: ids(3), startingAt: 2))
        #expect(window.range == 2..<3)
        #expect(window.url.absoluteString == "https://www.youtube.com/watch?v=vid00000002")
    }

    @Test func edgeCases() {
        #expect(PlaylistBuilder.playlist(videoIDs: []) == nil)
        #expect(PlaylistBuilder.playlist(videoIDs: ids(3), startingAt: 3) == nil)
        #expect(PlaylistBuilder.playlist(videoIDs: ids(3), startingAt: -1) == nil)
    }
}
