//
//  Reordering.swift
//  Icebox
//

import Foundation

/// SwiftUI `onMove` semantics as a pure function (`destination` is an offset
/// into the original array), so collection reordering is testable without a
/// view and without importing SwiftUI here.
nonisolated func movedElements<T>(_ elements: [T], fromOffsets source: IndexSet, toOffset destination: Int) -> [T] {
    let moving = source.compactMap { elements.indices.contains($0) ? elements[$0] : nil }
    var rest: [T] = []
    var insertionIndex = destination
    for (index, element) in elements.enumerated() {
        if source.contains(index) {
            if index < destination { insertionIndex -= 1 }
            continue
        }
        rest.append(element)
    }
    insertionIndex = min(max(insertionIndex, 0), rest.count)
    rest.insert(contentsOf: moving, at: insertionIndex)
    return rest
}
