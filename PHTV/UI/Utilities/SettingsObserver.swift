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

    nonisolated(unsafe) private var observer: NSObjectProtocol?
    private var lastNotificationTime: Date = Date()

    private override init() {
        super.init()
        setupObserver()
    }

    private func setupObserver() {
        // Listen on the main queue so @MainActor isolation is respected
        observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.didChangeSettings()
            }
        }
    }

    private func didChangeSettings() {
        // Debounce notifications to avoid excessive updates
        let now = Date()
        if now.timeIntervalSince(lastNotificationTime) > 0.1 {
            lastNotificationTime = now
            settingsDidChange = now
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
