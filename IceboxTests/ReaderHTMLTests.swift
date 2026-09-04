//
//  ReaderHTMLTests.swift
//  IceboxTests
//

import Foundation
import Testing
@testable import Icebox

struct ReaderHTMLTests {

    @Test func pageWrapsContentAndEscapesChrome() {
        let page = ReaderHTML.page(contentHTML: "<p>Hello <em>world</em></p>",
                                   title: "Tom & Jerry <3", byline: "Jane")
        #expect(page.contains("<p>Hello <em>world</em></p>"))
        #expect(page.contains("Tom &amp; Jerry &lt;3"))
        #expect(page.contains("Jane"))
        #expect(page.contains("prefers-color-scheme: dark"))
        #expect(page.contains("viewport"))
        #expect(page.contains("font-size: 19px"))
    }

    @Test func pageRespectsTypographyOptions() {
        let serif = ReaderHTML.page(contentHTML: "", title: "T", byline: "", fontSize: 23, useSerif: true)
        #expect(serif.contains("font-size: 23px"))
        #expect(serif.contains("ui-serif"))
        let sans = ReaderHTML.page(contentHTML: "", title: "T", byline: "")
        #expect(sans.contains("-apple-system"))
    }

    @Test func findsImageSourcesResolvingRelativeURLs() {
        let html = """
        <img src="https://example.com/a.jpg">
        <img class="x" src='/relative/b.png' alt="b">
        <img src="data:image/gif;base64,AAA">
        <img src="https://example.com/a.jpg">
        """
        let sources = ReaderHTML.imageSources(in: html, base: URL(string: "https://example.com/story/page"))
        #expect(sources.map(\.url.absoluteString) == [
            "https://example.com/a.jpg",
            "https://example.com/relative/b.png",
        ])
        #expect(sources.map(\.attribute) == ["https://example.com/a.jpg", "/relative/b.png"])
    }

    @Test func replacesSourcesExactly() {
        let html = #"<img src="/a.jpg"><img src="/b.jpg">"#
        let out = ReaderHTML.replacingImageSources(in: html, with: ["/a.jpg": "data:image/jpeg;base64,QUJD"])
        #expect(out == #"<img src="data:image/jpeg;base64,QUJD"><img src="/b.jpg">"#)
    }

    @Test func buildsDataURIs() {
        #expect(ReaderHTML.dataURI(for: Data("ABC".utf8), mimeType: "image/png") == "data:image/png;base64,QUJD")
    }
}
