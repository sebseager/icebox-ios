//
//  ViewHelpers.swift
//  Icebox
//

import SwiftUI

extension View {

    /// Standard keyboard behavior for editable screens: dragging the scroll
    /// view pulls the keyboard down interactively, and tapping the background
    /// dismisses it.
    func dismissesKeyboard() -> some View {
        self
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { endEditing() }
    }

    private func endEditing() {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        #elseif os(macOS)
        NSApp.keyWindow?.makeFirstResponder(nil)
        #endif
    }

    /// Makes a button or menu row's entire cell the hit target, not just its
    /// label.
    func wholeCellTappable() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
    }
}
