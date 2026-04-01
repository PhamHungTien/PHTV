//
//  SettingsObserver.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

/// Monitors UserDefaults changes and notifies AppState in real-time
@MainActor
final class SettingsObserver {
    static let shared = SettingsObserver()

    private var observationTask: Task<Void, Never>?
    private var lastNotificationTime: Date = Date()
    private var suppressUntil: Date?

    private init() {
        setupObserver()
    }

    private func setupObserver() {
        observationTask?.cancel()
        observationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await _ in NotificationCenter.default.notifications(
                named: UserDefaults.didChangeNotification,
                object: UserDefaults.standard
            ) {
                guard !Task.isCancelled else { break }
                self.didChangeSettings()
            }
        }
    }

    private func didChangeSettings() {
        if let suppressUntil, Date() < suppressUntil {
            return
        }
        // Debounce notifications to avoid excessive updates
        let now = Date()
        if now.timeIntervalSince(lastNotificationTime) > 0.1 {
            lastNotificationTime = now
            NotificationCenter.default.post(
                name: NotificationName.settingsObserverDidChange,
                object: nil
            )
        }
    }

    /// Temporarily suppress external settings notifications for local writes.
    func suspendNotifications(for interval: TimeInterval = 0.4) {
        suppressUntil = Date().addingTimeInterval(interval)
    }

}
