//
//  HelpView.swift
//  Icebox
//
//  The findable, plain-language explanation (spec §12). Short on purpose.
//

import SwiftUI

struct HelpView: View {
    var body: some View {
        List {
            Section("Playlists") {
                Text("A collection made entirely of YouTube videos can play as a real playlist in your browser — no account needed. Tap Play on the collection to start it, or press and hold a video to play from there. Collections longer than 50 play in chunks of 50.")
            }
            Section("Collections") {
                Text("A collection can keep its items out of the library list: turn off Show Items in Library in the collection's menu. The items still live in the collection — they just stop cluttering the library.")
            }
            Section("Offline") {
                Text("Any link can be saved offline. Icebox keeps a clean, readable copy on your device that works in airplane mode, even if the page later disappears.")
            }
            Section("Sync") {
                Text("Your library lives in your own iCloud account. It syncs to your devices, survives deleting the app, and comes back on a new phone. Icebox has no account and no server, and learns nothing about you.")
            }
            Section("Locking") {
                Text("A locked collection disappears from the library, search, and statistics until you unlock it with Face ID or your passcode. Leaving the app locks it again.")
            }
            Section("Export") {
                Text("Settings → Export Library gives you everything as one JSON file you can read in a text editor. Your library outlives any app, including this one.")
            }
        }
        .navigationTitle("How Icebox Works")
    }
}
