//
//  OnboardingView.swift
//  Icebox
//
//  Short and skippable (spec §12). Three screens stepped through with
//  Back/Next — no swiping, no typing.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var page = 0
    private let lastPage = 2

    var body: some View {
        VStack {
            HStack {
                if page > 0 {
                    Button("Back") {
                        withAnimation { page -= 1 }
                    }
                    .padding()
                }
                Spacer()
                if page < lastPage {
                    Button("Skip") { finish() }
                        .padding()
                }
            }

            Group {
                switch page {
                case 0: premisePage
                case 1: sharePage
                default: savingPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
            .id(page)

            Button(page < lastPage ? "Next" : "Start Using Icebox") {
                if page < lastPage {
                    withAnimation { page += 1 }
                } else {
                    finish()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 32)
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 520)
        #endif
    }

    private var premisePage: some View {
        pageLayout(symbol: "books.vertical.fill",
                   title: "Your library, off the record") {
            Text("Save videos and links from anywhere. Group them, play them, read them — with no account, no algorithm, and nothing tracking you.")
        }
    }

    private var sharePage: some View {
        pageLayout(symbol: "square.and.arrow.up",
                   title: "Put Icebox in your share sheet") {
            #if os(iOS)
            VStack(alignment: .leading, spacing: 10) {
                instruction(1, "In Safari or any app, tap the Share button.")
                instruction(2, "Scroll the app icons and tap More, then Edit.")
                instruction(3, "Add Icebox to Favorites and drag it to the top.")
            }
            #else
            Text("In Safari, click the Share button and choose Icebox. The first time, you may need to enable it under Edit Extensions.")
            #endif
        }
    }

    private var savingPage: some View {
        pageLayout(symbol: "link.badge.plus",
                   title: "Saving is one tap") {
            Text("Whenever you find something worth keeping, share it to Icebox. It lands in your library — and you can also add links with the + button there.")
        }
    }

    private func pageLayout(symbol: String, title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            content()
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private func instruction(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.callout.bold())
                .foregroundStyle(.tint)
            Text(text)
        }
        .multilineTextAlignment(.leading)
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "hasOnboarded")
        dismiss()
    }
}
