//
//  IceboxApp.swift
//  Icebox
//

import SwiftUI
import SwiftData

@main
struct IceboxApp: App {
    private let container = IceboxStore.makeSharedContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
