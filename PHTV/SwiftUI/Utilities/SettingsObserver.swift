//
//  SettingsObserver.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Combine
import Foundation

/// Monitors UserDefaults changes and notifies AppState in real-time
@MainActor
final class SettingsObserver: NSObject, ObservableObject {
    static let shared = SettingsObserver()

    @Published var settingsDidChange: Date?

    private var lastNotificationTime: Date = Date()

    private override init() {
        super.init()
        setupObserver()
    }

    private func setupObserver() {
        // Listen for NSUserDefaultsDidChangeNotification - more reliable than KVO
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: UserDefaults.standard
        )
    }

    @objc private func userDefaultsDidChange() {
        didChangeSettings()
    }

    private func didChangeSettings() {
        // Debounce notifications to avoid excessive updates
        let now = Date()
        if now.timeIntervalSince(lastNotificationTime) > 0.1 {
            lastNotificationTime = now
            Task { @MainActor in
                self.settingsDidChange = now
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
