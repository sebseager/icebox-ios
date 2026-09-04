//
//  OpenSettingsTests.swift
//  IceboxTests
//

import Foundation
import Testing
@testable import Icebox

@MainActor
struct OpenSettingsTests {

    private func freshDefaults() -> UserDefaults {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func defaultsAreBrowserForVideoReaderForLinks() {
        let settings = OpenSettings(defaults: freshDefaults())
        #expect(settings.videoPreference == .externalBrowser)
        #expect(settings.linkPreference == .reader)
    }

    @Test func preferencesPersist() {
        let defaults = freshDefaults()
        let settings = OpenSettings(defaults: defaults)
        settings.videoPreference = .inAppBrowser
        settings.linkPreference = .externalBrowser

        let reloaded = OpenSettings(defaults: defaults)
        #expect(reloaded.videoPreference == .inAppBrowser)
        #expect(reloaded.linkPreference == .externalBrowser)
    }
}
