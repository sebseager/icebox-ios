//
//  URLNormalizerTests.swift
//  IceboxTests
//

import Foundation
import Testing
@testable import Icebox

struct URLNormalizerTests {

    private func norm(_ s: String) -> String {
        URLNormalizer.normalized(URL(string: s)!)
    }

    @Test func lowercasesSchemeAndHost() {
        #expect(norm("HTTPS://Example.COM/Path") == "https://example.com/Path")
    }

    @Test func stripsFragmentsAndTrackingParams() {
        #expect(norm("https://example.com/a?utm_source=x&utm_medium=y&id=7#section") == "https://example.com/a?id=7")
        #expect(norm("https://example.com/a?fbclid=123&gclid=456") == "https://example.com/a")
    }

    @Test func stripsTrailingSlash() {
        #expect(norm("https://example.com/path/") == "https://example.com/path")
        #expect(norm("https://example.com/") == "https://example.com")
    }

    @Test func preservesMeaningfulQueryOrder() {
        #expect(norm("https://example.com/a?b=2&a=1") == "https://example.com/a?b=2&a=1")
    }

    @Test func canonicalizesYouTubeVideoURLs() {
        #expect(norm("https://youtu.be/dQw4w9WgXcQ?si=xyz&t=10") == "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        #expect(norm("https://m.youtube.com/watch?v=dQw4w9WgXcQ&list=PLx") == "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        #expect(norm("https://www.youtube.com/shorts/dQw4w9WgXcQ") == "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    }

    @Test func sameContentDifferentDressNormalizesEqual() {
        #expect(norm("https://Example.com/story?utm_campaign=news#top") == norm("https://example.com/story"))
    }
}
