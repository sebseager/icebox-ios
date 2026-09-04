//
//  OpenEvent.swift
//  Icebox
//

import Foundation
import SwiftData

/// One open of one item: reader view, browser hand-off, or playlist send.
/// History is per item and persists indefinitely (spec §8).
@Model
final class OpenEvent {
    var id: UUID = UUID()
    var date: Date = Date()
    var methodRaw: String = OpenMethod.browser.rawValue
    var item: SavedItem?

    init() {}

    var method: OpenMethod {
        get { OpenMethod(rawValue: methodRaw) ?? .browser }
        set { methodRaw = newValue.rawValue }
    }
}
