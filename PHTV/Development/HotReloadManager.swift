//
//  HotReloadManager.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Combine
import Foundation

/// Manages hot-reload of app data without requiring restart
@MainActor
final class HotReloadManager: NSObject, ObservableObject {
    static let shared = HotReloadManager()

    @Published var macrosUpdated: Date?
    @Published var excludedAppsUpdated: Date?
    @Published var settingsUpdated: Date?

    private var settingsObserver: NSKeyValueObservation?
    private var debounceTimer: Timer?

    private override init() {
        super.init()
        setupHotReload()
    }

    private func setupHotReload() {
        // Monitor UserDefaults for macro changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMacroChanges),
            name: NSNotification.Name("MacrosUpdated"),
            object: nil
        )

        // Monitor excluded apps changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleExcludedAppsChanges),
            name: NSNotification.Name("ExcludedAppsChanged"),
            object: nil
        )

        // Monitor settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanges),
            name: NSNotification.Name("PHTVSettingsChanged"),
            object: nil
        )
    }

    @objc private func handleMacroChanges() {
        Task { @MainActor in
            self.macrosUpdated = Date()
            // Notify backend to reload macros
            NotificationCenter.default.post(
                name: NSNotification.Name("MacroDataNeedsReload"),
                object: nil
            )
        }
    }

    @objc private func handleExcludedAppsChanges() {
        Task { @MainActor in
            self.excludedAppsUpdated = Date()
            // Notify backend to reload excluded apps
            NotificationCenter.default.post(
                name: NSNotification.Name("ExcludedAppsNeedsReload"),
                object: nil
            )
        }
    }

    @objc private func handleSettingsChanges() {
        Task { @MainActor in
            self.settingsUpdated = Date()
        }
    }

    /// Force reload all data without restarting
    func reloadAll() {
        NotificationCenter.default.post(
            name: NSNotification.Name("ReloadAllData"),
            object: nil
        )
        macrosUpdated = Date()
        excludedAppsUpdated = Date()
        settingsUpdated = Date()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
