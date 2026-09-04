//
//  RootView.swift
//  Icebox
//

import SwiftUI
import SwiftData
import CoreSpotlight
import TipKit

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var showsOnboarding = false
    @State private var lock = AppLockManager()
    @State private var navigator = Navigator()
    @State private var openSettings = OpenSettings()

    var body: some View {
        TabView {
            Tab("Library", systemImage: "books.vertical") {
                LibraryView()
            }
            Tab("Collections", systemImage: "square.stack") {
                CollectionsListView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .environment(lock)
        .environment(navigator)
        .environment(openSettings)
        .sheet(item: $navigator.readerItem) { item in
            ReaderView(item: item)
        }
        #if os(iOS)
        .fullScreenCover(item: $navigator.inAppPage) { page in
            SafariView(url: page.url)
                .ignoresSafeArea()
        }
        #endif
        .sheet(item: $navigator.importedPlaylist) { playlist in
            ImportPlaylistView(playlist: playlist)
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showsOnboarding) {
            OnboardingView()
                .onDisappear { hasOnboarded = true }
        }
        #else
        .sheet(isPresented: $showsOnboarding) {
            OnboardingView()
                .onDisappear { hasOnboarded = true }
        }
        #endif
        .overlay {
            if !lock.isAppUnlocked {
                LockScreenView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                lock.lockEverything()
            case .active:
                Task { await EnrichmentService.enrichPending(in: context) }
            default:
                break
            }
        }
        .onOpenURL { url in
            if let decoded = ImportLink.decode(url) {
                navigator.importedPlaylist = ImportedPlaylist(name: decoded.name, videoIDs: decoded.videoIDs)
            }
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            if let item = SpotlightIndexer.item(for: activity, context: context) {
                ItemOpener.open(item, navigator: navigator, settings: openSettings,
                                openURL: openURL, context: context)
            }
        }
        .task {
            try? Tips.configure()
            LockService.refreshFlags(in: context)
            showsOnboarding = !hasOnboarded
            await EnrichmentService.enrichPending(in: context)
            await SpotlightIndexer.reindex(context: context)
        }
    }
}

private struct LockScreenView: View {
    @Environment(AppLockManager.self) private var lock

    var body: some View {
        ZStack {
            Rectangle().fill(.regularMaterial).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Icebox is locked")
                    .font(.headline)
                Button("Unlock") {
                    Task { await lock.unlockApp() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .task {
            await lock.unlockApp()
        }
    }
}

#if os(iOS)
import SafariServices

/// In-app browsing that keeps Safari's content blockers (spec §11).
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
#endif
