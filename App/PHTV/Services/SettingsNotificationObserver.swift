//
//  SettingsNotificationObserver.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation
import AppKit

@MainActor
final class SettingsNotificationObserver {
    static let shared = SettingsNotificationObserver()
    private var showSettingsTask: Task<Void, Never>?
    private var createSettingsWindowTask: Task<Void, Never>?

    private init() {
        setupObservers()
    }

    private func setupObservers() {
        showSettingsTask = Task { @MainActor in
            for await _ in NotificationCenter.default.notifications(named: NotificationName.showSettings) {
                guard !Task.isCancelled else { break }
                SettingsWindowHelper.openSettingsWindow()
            }
        }

        createSettingsWindowTask = Task { @MainActor in
            for await _ in NotificationCenter.default.notifications(named: NotificationName.createSettingsWindow) {
                guard !Task.isCancelled else { break }
                SettingsWindowHelper.openSettingsWindow()
            }
        }
    }

}

@MainActor
func openSettingsWindow(with appState: AppState) {
    SettingsWindowHelper.openSettingsWindow()
}
