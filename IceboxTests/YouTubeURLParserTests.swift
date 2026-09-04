//
//  YouTubeURLParserTests.swift
//  IceboxTests
//

import Foundation
import Testing
@testable import Icebox

struct YouTubeURLParserTests {

    private func id(_ s: String) -> String? {
        YouTubeURLParser.videoID(from: URL(string: s)!)
    }

    @Test func recognizesStandardWatchURLs() {
        #expect(id("https://www.youtube.com/watch?v=dQw4w9WgXcQ") == "dQw4w9WgXcQ")
        #expect(id("https://youtube.com/watch?v=dQw4w9WgXcQ") == "dQw4w9WgXcQ")
        #expect(id("https://m.youtube.com/watch?v=dQw4w9WgXcQ") == "dQw4w9WgXcQ")
        #expect(id("https://music.youtube.com/watch?v=dQw4w9WgXcQ") == "dQw4w9WgXcQ")
        #expect(id("HTTPS://WWW.YOUTUBE.COM/watch?v=dQw4w9WgXcQ") == "dQw4w9WgXcQ")
    }

    @Test func recognizesShortAndAlternateForms() {
        #expect(id("https://youtu.be/dQw4w9WgXcQ") == "dQw4w9WgXcQ")
        #expect(id("https://youtu.be/dQw4w9WgXcQ?si=abc123") == "dQw4w9WgXcQ")
        #expect(id("https://www.youtube.com/shorts/dQw4w9WgXcQ") == "dQw4w9WgXcQ")
        #expect(id("https://www.youtube.com/live/dQw4w9WgXcQ") == "dQw4w9WgXcQ")
        #expect(id("https://www.youtube.com/embed/dQw4w9WgXcQ") == "dQw4w9WgXcQ")
        #expect(id("https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ") == "dQw4w9WgXcQ")
    }

    @Test func ignoresExtraQueryParameters() {
        #expect(id("https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42s&list=PLx") == "dQw4w9WgXcQ")
        #expect(id("https://www.youtube.com/watch?app=desktop&v=dQw4w9WgXcQ") == "dQw4w9WgXcQ")
    }

    @Test func rejectsNonVideoURLs() {
        #expect(id("https://www.youtube.com/@somechannel") == nil)
        #expect(id("https://www.youtube.com/playlist?list=PLx") == nil)
        #expect(id("https://www.youtube.com/feed/subscriptions") == nil)
        #expect(id("https://example.com/watch?v=dQw4w9WgXcQ") == nil)
        #expect(id("https://notyoutube.com/watch?v=dQw4w9WgXcQ") == nil)
        #expect(id("https://fakeyoutu.be/dQw4w9WgXcQ") == nil)
        #expect(id("https://www.youtube.com/watch?v=short") == nil) // malformed id
        #expect(id("https://www.youtube.com/watch?v=waytoolongid42") == nil)
        #expect(id("https://www.youtube.com/") == nil)
    }

    @Test func isYouTubeVideoURLMatchesVideoIDPresence() {
        #expect(YouTubeURLParser.isYouTubeVideoURL(URL(string: "https://youtu.be/dQw4w9WgXcQ")!))
        #expect(!YouTubeURLParser.isYouTubeVideoURL(URL(string: "https://www.youtube.com/@channel")!))
    }

    @Test func parsesWatchVideosLists() {
        let url = URL(string: "https://www.youtube.com/watch_videos?video_ids=dQw4w9WgXcQ,abcdefghijk,AAAAAAAAAAA")!
        #expect(YouTubeURLParser.videoIDs(fromWatchVideosURL: url) == ["dQw4w9WgXcQ", "abcdefghijk", "AAAAAAAAAAA"])
        // Not a watch_videos URL
        #expect(YouTubeURLParser.videoIDs(fromWatchVideosURL: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!) == nil)
        // Junk ids are dropped
        let mixed = URL(string: "https://www.youtube.com/watch_videos?video_ids=dQw4w9WgXcQ,nope")!
        #expect(YouTubeURLParser.videoIDs(fromWatchVideosURL: mixed) == ["dQw4w9WgXcQ"])
    }

    @Test func buildsCanonicalURLs() {
        #expect(YouTubeURLParser.watchURL(videoID: "dQw4w9WgXcQ").absoluteString == "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        #expect(YouTubeURLParser.thumbnailURL(videoID: "dQw4w9WgXcQ").absoluteString == "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg")
    }
}
