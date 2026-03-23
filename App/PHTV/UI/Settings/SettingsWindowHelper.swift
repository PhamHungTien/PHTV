//
//  SettingsWindowHelper.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import AppKit

@MainActor
enum SettingsWindowHelper {
    private static var settingsController: SwiftUIWindowController?

    static func openSettingsWindow() {
        // First, try to find and show existing settings window
        for window in NSApp.windows {
            let identifier = window.identifier?.rawValue ?? ""
            // SwiftUI Window scenes have identifiers like "settings-AppWindow-1"
            if identifier.hasPrefix("settings") {
                // Set window level based on user preference
                let alwaysOnTop = UserDefaults.standard.bool(forKey: UserDefaultsKey.settingsWindowAlwaysOnTop)
                window.level = alwaysOnTop ? .floating : .normal

                // FIX: Ensure robust window behavior matching SettingsWindowContent
                window.hidesOnDeactivate = false
                window.isMovableByWindowBackground = true
                window.collectionBehavior = [.managed, .participatesInCycle, .moveToActiveSpace, .fullScreenAuxiliary]

                // Bring window to front
                window.makeKeyAndOrderFront(nil)

                // Ensure window is not minimized
                if window.isMiniaturized {
                    window.deminiaturize(nil)
                }

                // Activate app
                NSApp.activate(ignoringOtherApps: true)

                return
            }
        }

        let controller: SwiftUIWindowController
        if let existingController = settingsController {
            controller = existingController
        } else {
            let newController = SwiftUIWindowController.settingsWindow()
            settingsController = newController
            controller = newController
        }

        if let window = controller.window {
            let alwaysOnTop = UserDefaults.standard.bool(
                forKey: UserDefaultsKey.settingsWindowAlwaysOnTop,
                default: Defaults.settingsWindowAlwaysOnTop
            )
            window.level = alwaysOnTop ? .floating : .normal
            window.hidesOnDeactivate = false
            window.isMovableByWindowBackground = true
            window.collectionBehavior = [.managed, .participatesInCycle, .moveToActiveSpace, .fullScreenAuxiliary]
        }

        controller.show()
    }

    static func releaseSettingsWindow() {
        settingsController = nil
    }
}
