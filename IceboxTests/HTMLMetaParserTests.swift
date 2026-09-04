//
//  HTMLMetaParserTests.swift
//  IceboxTests
//

import Foundation
import Testing
@testable import Icebox

struct HTMLMetaParserTests {

    @Test func parsesOpenGraphTags() {
        let html = """
        <html><head>
        <title>Fallback Title - Site</title>
        <meta property="og:title" content="The Real Title" />
        <meta property="og:site_name" content="Example Journal"/>
        <meta property="og:image" content="https://example.com/hero.jpg">
        <meta property="og:description" content="A short summary." />
        <meta name="author" content="Jane Doe">
        </head><body></body></html>
        """
        let meta = HTMLMetaParser.parse(html: html)
        #expect(meta.title == "The Real Title")
        #expect(meta.siteName == "Example Journal")
        #expect(meta.thumbnailURLString == "https://example.com/hero.jpg")
        #expect(meta.excerpt == "A short summary.")
        #expect(meta.author == "Jane Doe")
    }

    @Test func fallsBackToTitleTag() {
        let meta = HTMLMetaParser.parse(html: "<html><head><title>Just a Title</title></head></html>")
        #expect(meta.title == "Just a Title")
        #expect(meta.siteName == nil)
    }

    @Test func handlesReversedAttributesAndTwitterTags() {
        let html = """
        <meta content="Reversed Title" property="og:title">
        <meta name="twitter:image" content="https://example.com/tw.png">
        """
        let meta = HTMLMetaParser.parse(html: html)
        #expect(meta.title == "Reversed Title")
        #expect(meta.thumbnailURLString == "https://example.com/tw.png")
    }

    @Test func decodesHTMLEntities() {
        let html = #"<meta property="og:title" content="Tom &amp; Jerry&#39;s &quot;Best&quot; Day &mdash; yes">"#
        let meta = HTMLMetaParser.parse(html: html)
        #expect(meta.title == "Tom & Jerry's \"Best\" Day — yes")
    }

    @Test func extractsYouTubeDuration() {
        let html = #"<script>var ytInitialPlayerResponse = {"videoDetails":{"videoId":"dQw4w9WgXcQ","lengthSeconds":"213","title":"Song"}};</script>"#
        let meta = HTMLMetaParser.parse(html: html)
        #expect(meta.durationSeconds == 213)
    }

    @Test func emptyInputYieldsEmptyMetadata() {
        let meta = HTMLMetaParser.parse(html: "")
        #expect(meta == PageMetadata())
    }
}
