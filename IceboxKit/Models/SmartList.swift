//
//  SmartList.swift
//  Icebox
//

import Foundation
import SwiftData

/// A saved filter that stays current, in the Reminders mold (spec §14).
/// `filterData` is a Codable-encoded SearchFilter.
@Model
final class SmartList {
    var id: UUID = UUID()
    var name: String = ""
    var dateCreated: Date = Date()
    var filterData: Data?

    init() {}
}
