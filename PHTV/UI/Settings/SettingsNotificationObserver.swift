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
    private var observers: [Any] = []

    private init() {
        setupObservers()
    }

    private func setupObservers() {
        // Listen for ShowSettings notification
        let showSettingsObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowSettings"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                SettingsWindowHelper.openSettingsWindow()
            }
        }
        observers.append(showSettingsObserver)

        // Listen for CreateSettingsWindow notification
        let createWindowObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CreateSettingsWindow"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                SettingsWindowHelper.openSettingsWindow()
            }
        }
        observers.append(createWindowObserver)
    }
}

@MainActor
func openSettingsWindow(with appState: AppState) {
    SettingsWindowHelper.openSettingsWindow()
}
