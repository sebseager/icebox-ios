//
//  AppLockManager.swift
//  Icebox
//

import Foundation
import LocalAuthentication
import Observation

/// Runtime lock state: whole-app lock plus per-collection unlock sessions.
/// Backgrounding the app clears everything — a locked collection is never
/// left open (spec §10).
@MainActor
@Observable
final class AppLockManager {

    private static let appLockKey = "appLockEnabled"

    var isAppLockEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.appLockKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.appLockKey)
            if newValue == false { isAppUnlocked = true }
        }
    }

    private(set) var isAppUnlocked: Bool
    private(set) var unlockedCollectionIDs: Set<UUID> = []
    /// One authentication reveals locked collections in the Collections list
    /// until the app leaves the foreground.
    private(set) var areLockedCollectionsRevealed = false

    init() {
        isAppUnlocked = !UserDefaults.standard.bool(forKey: Self.appLockKey)
    }

    var canAuthenticate: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    @discardableResult
    func unlockApp() async -> Bool {
        guard isAppLockEnabled else {
            isAppUnlocked = true
            return true
        }
        let ok = await authenticate(reason: String(localized: "Unlock Icebox"))
        if ok { isAppUnlocked = true }
        return ok
    }

    @discardableResult
    func unlockCollection(_ id: UUID) async -> Bool {
        if unlockedCollectionIDs.contains(id) { return true }
        let ok = await authenticate(reason: String(localized: "Unlock collection"))
        if ok { unlockedCollectionIDs.insert(id) }
        return ok
    }

    func isCollectionUnlocked(_ id: UUID) -> Bool {
        unlockedCollectionIDs.contains(id)
    }

    @discardableResult
    func revealLockedCollections() async -> Bool {
        if areLockedCollectionsRevealed { return true }
        let ok = await authenticate(reason: String(localized: "Show locked collections"))
        if ok { areLockedCollectionsRevealed = true }
        return ok
    }

    /// Called when the scene leaves the foreground.
    func lockEverything() {
        unlockedCollectionIDs.removeAll()
        areLockedCollectionsRevealed = false
        if isAppLockEnabled { isAppUnlocked = false }
    }

    private func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            // No passcode set on the device: locking cannot be trustworthy,
            // so don't pretend (spec §3.5).
            return false
        }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}
