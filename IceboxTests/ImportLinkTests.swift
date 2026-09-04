//
//  ImportLinkTests.swift
//  IceboxTests
//

import Foundation
import Testing
@testable import Icebox

struct ImportLinkTests {

    @Test func roundTripsNameAndOrder() throws {
        let url = try #require(ImportLink.encode(collectionName: "Cooking & Baking",
                                                 videoIDs: ["dQw4w9WgXcQ", "abcdefghijk"]))
        #expect(url.scheme == "icebox")
        let decoded = try #require(ImportLink.decode(url))
        #expect(decoded.name == "Cooking & Baking")
        #expect(decoded.videoIDs == ["dQw4w9WgXcQ", "abcdefghijk"])
    }

    @Test func rejectsJunk() {
        #expect(ImportLink.encode(collectionName: "x", videoIDs: []) == nil)
        #expect(ImportLink.decode(URL(string: "icebox://other?ids=dQw4w9WgXcQ")!) == nil)
        #expect(ImportLink.decode(URL(string: "https://import?ids=dQw4w9WgXcQ")!) == nil)
        #expect(ImportLink.decode(URL(string: "icebox://import?ids=nope,alsonope")!) == nil)
    }

    @Test func dropsInvalidIDsAndDefaultsName() throws {
        let decoded = try #require(ImportLink.decode(URL(string: "icebox://import?ids=dQw4w9WgXcQ,bad")!))
        #expect(decoded.videoIDs == ["dQw4w9WgXcQ"])
        #expect(!decoded.name.isEmpty)
    }
}
