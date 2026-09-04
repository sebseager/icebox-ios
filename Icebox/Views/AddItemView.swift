//
//  AddItemView.swift
//  Icebox
//

import SwiftUI
import SwiftData

/// Paste or type one or more links; each becomes an item (spec §5).
struct AddItemView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""

    private var urls: [URL] {
        text.split(whereSeparator: \.isWhitespace)
            .compactMap { URL(string: String($0)) }
            .filter { $0.scheme?.hasPrefix("http") == true }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Paste links here", text: $text, axis: .vertical)
                        .lineLimit(3...10)
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                    Button {
                        if let pasted = pasteboardString(), !pasted.isEmpty {
                            text = text.isEmpty ? pasted : text + "\n" + pasted
                        }
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                            .wholeCellTappable()
                    }
                } footer: {
                    if urls.count > 1 {
                        Text("\(urls.count) links found")
                    }
                }
            }
            .formStyle(.grouped)
            .dismissesKeyboard()
            .navigationTitle("Add Links")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(urls.count > 1 ? "Save All" : "Save") { saveAll() }
                        .disabled(urls.isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 280)
        #endif
    }

    private func saveAll() {
        for url in urls {
            _ = try? CaptureService.save(CaptureInput(url: url), in: context)
        }
        dismiss()
    }

    private func pasteboardString() -> String? {
        #if os(iOS)
        UIPasteboard.general.string
        #elseif os(macOS)
        NSPasteboard.general.string(forType: .string)
        #endif
    }
}
