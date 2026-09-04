//
//  SettingsView.swift
//  Icebox
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppLockManager.self) private var lock
    @Environment(OpenSettings.self) private var openSettings

    @Query(filter: #Predicate<SavedItem> { !$0.isInLockedCollection })
    private var statsItems: [SavedItem]

    @State private var showsExporter = false
    @State private var exportDocument: ExportDocument?
    @State private var includeLockedInExport = false

    var body: some View {
        @Bindable var lock = lock
        @Bindable var openSettings = openSettings

        NavigationStack {
            Form {
                Section {
                    Picker("Videos", selection: $openSettings.videoPreference) {
                        Text("Browser").tag(OpenPreference.externalBrowser)
                        #if os(iOS)
                        Text("In App").tag(OpenPreference.inAppBrowser)
                        #endif
                    }
                    Picker("Links", selection: $openSettings.linkPreference) {
                        Text("Reader").tag(OpenPreference.reader)
                        Text("Browser").tag(OpenPreference.externalBrowser)
                        #if os(iOS)
                        Text("In App").tag(OpenPreference.inAppBrowser)
                        #endif
                    }
                } header: {
                    Text("Opening")
                } footer: {
                    Text("Browser means your default browser, with all its extensions.")
                }

                Section {
                    Toggle("Require Face ID or passcode", isOn: $lock.isAppLockEnabled)
                        .disabled(!lock.canAuthenticate)
                } header: {
                    Text("Privacy")
                } footer: {
                    if !lock.canAuthenticate {
                        Text("Set a device passcode to use app lock.")
                    }
                }

                Section {
                    if lock.areLockedCollectionsRevealed {
                        Toggle("Include locked collections", isOn: $includeLockedInExport)
                    }
                    Button {
                        prepareExport()
                    } label: {
                        Label("Export Library…", systemImage: "square.and.arrow.up")
                            .wholeCellTappable()
                    }
                } header: {
                    Text("Your Data")
                } footer: {
                    Text("Everything lives in your own iCloud and syncs to your devices. Export gives you the whole library as one readable file.")
                }

                Section("Statistics") {
                    SavedOverTimeChart(items: statsItems)
                    NavigationLink {
                        StatisticsView()
                    } label: {
                        Label("All Statistics", systemImage: "chart.bar")
                    }
                }

                Section {
                    NavigationLink("How Icebox Works") {
                        HelpView()
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .fileExporter(
                isPresented: $showsExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "Icebox Export"
            ) { _ in
                exportDocument = nil
            }
        }
    }

    private func prepareExport() {
        let options = ExportOptions(includeLocked: lock.areLockedCollectionsRevealed && includeLockedInExport)
        if let data = try? LibraryExporter.export(context: context, options: options) {
            exportDocument = ExportDocument(data: data)
            showsExporter = true
        }
    }
}

struct ExportDocument: FileDocument {
    nonisolated static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
