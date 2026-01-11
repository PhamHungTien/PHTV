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
    static func openSettingsWindow() {
        NSLog("[SettingsWindowHelper] openSettingsWindow called")

        // First, try to find and show existing settings window
        for window in NSApp.windows {
            let identifier = window.identifier?.rawValue ?? ""
            // SwiftUI Window scenes have identifiers like "settings-AppWindow-1"
            if identifier.hasPrefix("settings") {
                NSLog("[SettingsWindowHelper] Found existing settings window: %@", identifier)

                // Set window level based on user preference
                let alwaysOnTop = UserDefaults.standard.bool(forKey: "vSettingsWindowAlwaysOnTop")
                window.level = alwaysOnTop ? .floating : .normal
                
                // FIX: Ensure robust window behavior matching SettingsWindowContent
                window.hidesOnDeactivate = false
                window.isMovableByWindowBackground = true
                window.collectionBehavior = [.managed, .participatesInCycle, .moveToActiveSpace, .fullScreenAuxiliary]
                
                NSLog("[SettingsWindowHelper] Set window.level = %@", alwaysOnTop ? ".floating" : ".normal")

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

        NSLog("[SettingsWindowHelper] No existing window found, triggering openWindow")

        // Trigger the window opening via notification that SettingsWindowOpener listens to
        SettingsWindowOpener.shared.requestOpenWindow()
    }
}
