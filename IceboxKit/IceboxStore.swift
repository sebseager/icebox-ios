//
//  IceboxStore.swift
//  Icebox
//

import Foundation
import SwiftData

/// Builds the model container. The store file lives in the app group so the
/// share extension writes to the same library, and syncs through the user's
/// own iCloud private database. No account with us, ever (spec §3, §9).
nonisolated enum IceboxStore {
    static let appGroupID = "group.com.sebseager.Icebox"
    static let cloudKitContainerID = "iCloud.com.sebseager.Icebox"

    static var schema: Schema {
        Schema([
            SavedItem.self,
            ItemCollection.self,
            CollectionEntry.self,
            Tag.self,
            OpenEvent.self,
            OfflineArticle.self,
            SmartList.self,
        ])
    }

    static var storeURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("Icebox.store")
    }

    /// The container the app and share extension both use. Prefers the app
    /// group location with CloudKit sync; degrades to local-only storage if
    /// either is unavailable (e.g. unsigned development builds) rather than
    /// refusing to launch.
    static func makeSharedContainer() -> ModelContainer {
        if let url = storeURL {
            let cloud = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .private(cloudKitContainerID))
            if let container = try? ModelContainer(for: schema, configurations: [cloud]) {
                return container
            }
            let local = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            if let container = try? ModelContainer(for: schema, configurations: [local]) {
                return container
            }
        }
        let fallback = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [fallback])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    /// In-memory container for tests and previews.
    static func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
