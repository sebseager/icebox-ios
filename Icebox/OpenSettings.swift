//
//  OpenSettings.swift
//  Icebox
//

import Foundation
import Observation

/// How each content type opens (spec §11). The user chose their browser and
/// its extensions; the default hands links to it. Reader is the default for
/// links because that's the calm path; video defaults to the browser where
/// the user's player extensions live.
nonisolated enum OpenPreference: String, Codable, CaseIterable, Sendable {
    case reader
    case inAppBrowser
    case externalBrowser
}

@MainActor
@Observable
final class OpenSettings {

    private static let videoKey = "openPreference.video"
    private static let linkKey = "openPreference.link"

    private let defaults: UserDefaults

    var videoPreference: OpenPreference {
        didSet { defaults.set(videoPreference.rawValue, forKey: Self.videoKey) }
    }
    var linkPreference: OpenPreference {
        didSet { defaults.set(linkPreference.rawValue, forKey: Self.linkKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        videoPreference = defaults.string(forKey: Self.videoKey).flatMap(OpenPreference.init) ?? .externalBrowser
        linkPreference = defaults.string(forKey: Self.linkKey).flatMap(OpenPreference.init) ?? .reader
    }
}
