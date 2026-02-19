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

    // Upper case excluded apps - disable uppercase first char for these apps
    @Published var upperCaseExcludedApps: [ExcludedApp] = []

    var isLoadingSettings = false

    private static var liveDebugEnabled: Bool {
        let env = ProcessInfo.processInfo.environment["PHTV_LIVE_DEBUG"]
        if let env, !env.isEmpty {
            return env != "0"
        }
        return UserDefaults.standard.integer(forKey: UserDefaultsKey.liveDebug, default: 0) != 0
    }

    private func liveLog(_ message: String) {
        guard Self.liveDebugEnabled else { return }
        NSLog("[PHTV Live] %@", message)
    }

    init() {}

    // MARK: - Load/Save Settings

    private func decodeList<T: Decodable>(
        _ type: [T].Type,
        from defaults: UserDefaults,
        key: String,
        label: String
    ) -> [T] {
        guard let data = defaults.data(forKey: key) else {
            return []
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            NSLog("[AppListsState] Failed to decode %@: %@", label, error.localizedDescription)
            return []
        }
    }

    func loadSettings() {
        let defaults = UserDefaults.standard

        excludedApps = decodeList(
            [ExcludedApp].self,
            from: defaults,
            key: UserDefaultsKey.excludedApps,
            label: "excluded apps"
        )
        sendKeyStepByStepApps = decodeList(
            [SendKeyStepByStepApp].self,
            from: defaults,
            key: UserDefaultsKey.sendKeyStepByStepApps,
            label: "send key step by step apps"
        )
        upperCaseExcludedApps = decodeList(
            [ExcludedApp].self,
            from: defaults,
            key: UserDefaultsKey.upperCaseExcludedApps,
            label: "upper case excluded apps"
        )
    }

    func saveSettings() {
        SettingsObserver.shared.suspendNotifications()
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

        // Save upper case excluded apps
        do {
            let data = try JSONEncoder().encode(upperCaseExcludedApps)
            defaults.set(data, forKey: UserDefaultsKey.upperCaseExcludedApps)
        } catch {
            NSLog("[AppListsState] Failed to encode upper case excluded apps: %@", error.localizedDescription)
        }

    }

    func reloadFromDefaults() {
        let defaults = UserDefaults.standard

        let newExcludedApps = decodeList(
            [ExcludedApp].self,
            from: defaults,
            key: UserDefaultsKey.excludedApps,
            label: "excluded apps"
        )
        if newExcludedApps != excludedApps {
            excludedApps = newExcludedApps
        }

        let newSendKeyStepByStepApps = decodeList(
            [SendKeyStepByStepApp].self,
            from: defaults,
            key: UserDefaultsKey.sendKeyStepByStepApps,
            label: "send key step by step apps"
        )
        if newSendKeyStepByStepApps != sendKeyStepByStepApps {
            sendKeyStepByStepApps = newSendKeyStepByStepApps
        }

        let newUpperCaseExcludedApps = decodeList(
            [ExcludedApp].self,
            from: defaults,
            key: UserDefaultsKey.upperCaseExcludedApps,
            label: "upper case excluded apps"
        )
        if newUpperCaseExcludedApps != upperCaseExcludedApps {
            upperCaseExcludedApps = newUpperCaseExcludedApps
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
        SettingsObserver.shared.suspendNotifications()
        do {
            let data = try JSONEncoder().encode(excludedApps)
            UserDefaults.standard.set(data, forKey: UserDefaultsKey.excludedApps)

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
        SettingsObserver.shared.suspendNotifications()
        do {
            let data = try JSONEncoder().encode(sendKeyStepByStepApps)
            UserDefaults.standard.set(data, forKey: UserDefaultsKey.sendKeyStepByStepApps)

            // Notify backend with hot reload
            liveLog("posting SendKeyStepByStepAppsChanged")
            NotificationCenter.default.post(
                name: NotificationName.sendKeyStepByStepAppsChanged, object: sendKeyStepByStepApps)
        } catch {
            NSLog("[AppListsState] Failed to save send key step by step apps: %@", error.localizedDescription)
        }
    }

    // MARK: - Upper Case Excluded Apps Management

    func addUpperCaseExcludedApp(_ app: ExcludedApp) {
        if !upperCaseExcludedApps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            upperCaseExcludedApps.append(app)
            saveUpperCaseExcludedApps()
        }
    }

    func removeUpperCaseExcludedApp(_ app: ExcludedApp) {
        upperCaseExcludedApps.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
        saveUpperCaseExcludedApps()
    }

    func isAppUpperCaseExcluded(bundleIdentifier: String) -> Bool {
        return upperCaseExcludedApps.contains { $0.bundleIdentifier == bundleIdentifier }
    }

    private func saveUpperCaseExcludedApps() {
        do {
            let data = try JSONEncoder().encode(upperCaseExcludedApps)
            UserDefaults.standard.set(data, forKey: UserDefaultsKey.upperCaseExcludedApps)

            // Notify backend with hot reload
            liveLog("posting UpperCaseExcludedAppsChanged")
            NotificationCenter.default.post(
                name: NotificationName.upperCaseExcludedAppsChanged, object: upperCaseExcludedApps)
        } catch {
            NSLog("[AppListsState] Failed to save upper case excluded apps: %@", error.localizedDescription)
        }
    }

    func resetToDefaults() {
        isLoadingSettings = true
        defer { isLoadingSettings = false }

        excludedApps = []
        sendKeyStepByStepApps = []
        upperCaseExcludedApps = []

        saveSettings()
    }
}
