//
//  AppListsState.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import Combine

/// Manages excluded apps and send key step by step apps
@MainActor
final class AppListsState: ObservableObject {
    // Excluded apps - auto switch to English when these apps are active
    @Published var excludedApps: [ExcludedApp] = []

    // Send key step by step apps - auto enable send key step by step when these apps are active
    @Published var sendKeyStepByStepApps: [SendKeyStepByStepApp] = []

    var isLoadingSettings = false

    private static var liveDebugEnabled: Bool {
        let env = ProcessInfo.processInfo.environment["PHTV_LIVE_DEBUG"]
        if let env, !env.isEmpty {
            return env != "0"
        }
        return UserDefaults.standard.integer(forKey: UserDefaultsKey.liveDebug) != 0
    }

    private func liveLog(_ message: String) {
        guard Self.liveDebugEnabled else { return }
        NSLog("[PHTV Live] %@", message)
    }

    init() {}

    // MARK: - Load/Save Settings

    func loadSettings() {
        let defaults = UserDefaults.standard

        // Load excluded apps
        if let data = defaults.data(forKey: UserDefaultsKey.excludedApps) {
            do {
                excludedApps = try JSONDecoder().decode([ExcludedApp].self, from: data)
            } catch {
                NSLog("[AppListsState] Failed to decode excluded apps: %@", error.localizedDescription)
                // Keep default empty array
                excludedApps = []
            }
        }

        // Load send key step by step apps
        if let data = defaults.data(forKey: UserDefaultsKey.sendKeyStepByStepApps) {
            do {
                sendKeyStepByStepApps = try JSONDecoder().decode([SendKeyStepByStepApp].self, from: data)
            } catch {
                NSLog("[AppListsState] Failed to decode send key step by step apps: %@", error.localizedDescription)
                // Keep default empty array
                sendKeyStepByStepApps = []
            }
        }
    }

    func saveSettings() {
        let defaults = UserDefaults.standard

        // Save excluded apps
        do {
            let data = try JSONEncoder().encode(excludedApps)
            defaults.set(data, forKey: UserDefaultsKey.excludedApps)
        } catch {
            NSLog("[AppListsState] Failed to encode excluded apps: %@", error.localizedDescription)
        }

        // Save send key step by step apps
        do {
            let data = try JSONEncoder().encode(sendKeyStepByStepApps)
            defaults.set(data, forKey: UserDefaultsKey.sendKeyStepByStepApps)
        } catch {
            NSLog("[AppListsState] Failed to encode send key step by step apps: %@", error.localizedDescription)
        }

        defaults.synchronize()
    }

    func reloadFromDefaults() {
        let defaults = UserDefaults.standard

        // Reload excluded apps if changed
        if let data = defaults.data(forKey: UserDefaultsKey.excludedApps) {
            do {
                let newApps = try JSONDecoder().decode([ExcludedApp].self, from: data)
                if newApps != excludedApps {
                    excludedApps = newApps
                }
            } catch {
                NSLog("[AppListsState] Failed to reload excluded apps: %@", error.localizedDescription)
            }
        }

        // Reload send key step by step apps if changed
        if let data = defaults.data(forKey: UserDefaultsKey.sendKeyStepByStepApps) {
            do {
                let newApps = try JSONDecoder().decode([SendKeyStepByStepApp].self, from: data)
                if newApps != sendKeyStepByStepApps {
                    sendKeyStepByStepApps = newApps
                }
            } catch {
                NSLog("[AppListsState] Failed to reload send key step by step apps: %@", error.localizedDescription)
            }
        }
    }

    // MARK: - Excluded Apps Management

    func addExcludedApp(_ app: ExcludedApp) {
        if !excludedApps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            excludedApps.append(app)
            saveExcludedApps()
        }
    }

    func removeExcludedApp(_ app: ExcludedApp) {
        excludedApps.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
        saveExcludedApps()
    }

    func isAppExcluded(bundleIdentifier: String) -> Bool {
        return excludedApps.contains { $0.bundleIdentifier == bundleIdentifier }
    }

    private func saveExcludedApps() {
        do {
            let data = try JSONEncoder().encode(excludedApps)
            UserDefaults.standard.set(data, forKey: UserDefaultsKey.excludedApps)
            UserDefaults.standard.synchronize()

            // Notify backend with hot reload
            liveLog("posting ExcludedAppsChanged")
            NotificationCenter.default.post(
                name: NotificationName.excludedAppsChanged, object: excludedApps)

            // Also post legacy notification for backward compatibility
            liveLog("posting ExcludedAppsChanged (legacy)")
            NotificationCenter.default.post(
                name: NotificationName.excludedAppsChanged, object: nil)
        } catch {
            NSLog("[AppListsState] Failed to save excluded apps: %@", error.localizedDescription)
        }
    }

    // MARK: - Send Key Step By Step Apps Management

    func addSendKeyStepByStepApp(_ app: SendKeyStepByStepApp) {
        if !sendKeyStepByStepApps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            sendKeyStepByStepApps.append(app)
            saveSendKeyStepByStepApps()
        }
    }

    func removeSendKeyStepByStepApp(_ app: SendKeyStepByStepApp) {
        sendKeyStepByStepApps.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
        saveSendKeyStepByStepApps()
    }

    func isAppInSendKeyStepByStepList(bundleIdentifier: String) -> Bool {
        return sendKeyStepByStepApps.contains { $0.bundleIdentifier == bundleIdentifier }
    }

    private func saveSendKeyStepByStepApps() {
        do {
            let data = try JSONEncoder().encode(sendKeyStepByStepApps)
            UserDefaults.standard.set(data, forKey: UserDefaultsKey.sendKeyStepByStepApps)
            UserDefaults.standard.synchronize()

            // Notify backend with hot reload
            liveLog("posting SendKeyStepByStepAppsChanged")
            NotificationCenter.default.post(
                name: NotificationName.sendKeyStepByStepAppsChanged, object: sendKeyStepByStepApps)
        } catch {
            NSLog("[AppListsState] Failed to save send key step by step apps: %@", error.localizedDescription)
        }
    }

    func resetToDefaults() {
        isLoadingSettings = true
        defer { isLoadingSettings = false }

        excludedApps = []
        sendKeyStepByStepApps = []

        saveSettings()
    }
}
