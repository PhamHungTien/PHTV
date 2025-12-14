//
//  BackendSyncOptimizer.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Combine
import Foundation

/// Optimizes communication with C++ backend to ensure efficient updates
@MainActor
final class BackendSyncOptimizer: NSObject, ObservableObject {
    static let shared = BackendSyncOptimizer()

    private var pendingNotifications: Set<String> = []
    private var syncTimer: Timer?
    private let syncDebounceInterval: TimeInterval = 0.15

    private override init() {
        super.init()
        setupOptimization()
    }

    private func setupOptimization() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingChange),
            name: NSNotification.Name("HotkeyChanged"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMacroChange),
            name: NSNotification.Name("MacrosUpdated"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleExcludedAppsChange),
            name: NSNotification.Name("ExcludedAppsChanged"),
            object: nil
        )
    }

    @objc private func handleSettingChange() {
        scheduleSyncNotification("HotkeySync")
    }

    @objc private func handleMacroChange() {
        scheduleSyncNotification("MacroSync")
    }

    @objc private func handleExcludedAppsChange() {
        scheduleSyncNotification("ExcludedAppsSync")
    }

    /// Schedule a debounced sync notification
    private func scheduleSyncNotification(_ notificationName: String) {
        pendingNotifications.insert(notificationName)

        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncDebounceInterval, repeats: false) {
            [weak self] _ in
            Task { @MainActor in
                self?.flushPendingNotifications()
            }
        }
    }

    /// Send all pending notifications to backend at once
    private func flushPendingNotifications() {
        for notificationName in pendingNotifications {
            NotificationCenter.default.post(
                name: NSNotification.Name(notificationName),
                object: nil
            )
        }
        pendingNotifications.removeAll()
        syncTimer?.invalidate()
        syncTimer = nil
    }

    /// Force immediate sync without debouncing
    func syncImmediate() {
        flushPendingNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        syncTimer?.invalidate()
    }
}

/// Performance monitoring for settings operations
struct PerformanceMonitor {
    static func measureSettingsSave<T>(_ name: String, block: () -> T) -> T {
        let start = Date()
        let result = block()
        let elapsed = Date().timeIntervalSince(start)

        // Only log if it takes longer than 50ms
        if elapsed > 0.05 {
            NSLog("⚠️ [PHTV] \(name) took \(String(format: "%.0f", elapsed * 1000))ms")
        }

        return result
    }

    static func logSettings(_ name: String, settings: [String: Any]) {
        NSLog("📊 [PHTV] \(name): \(settings.count) settings saved")
    }
}
