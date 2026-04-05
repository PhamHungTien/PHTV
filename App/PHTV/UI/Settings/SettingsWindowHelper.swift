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
                let alwaysOnTop = AppState.shared.settingsWindowAlwaysOnTop
                applyWindowConfiguration(to: window, alwaysOnTop: alwaysOnTop)

                // Ensure window is not minimized
                if window.isMiniaturized {
                    window.deminiaturize(nil)
                }

                // Bring window to front after its final state is restored.
                NSApp.setActivationPolicy(.regular)
                window.makeKeyAndOrderFront(nil)

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
            let alwaysOnTop = AppState.shared.settingsWindowAlwaysOnTop
            applyWindowConfiguration(to: window, alwaysOnTop: alwaysOnTop)
        }

        NSApp.setActivationPolicy(.regular)
        controller.show()
    }

    static func applyWindowConfiguration(to window: NSWindow, alwaysOnTop: Bool) {
        window.level = alwaysOnTop ? .floating : .normal
        window.hidesOnDeactivate = false
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [.managed, .participatesInCycle, .moveToActiveSpace, .fullScreenAuxiliary]

        // Keep the window visually stable when it opens from menu-bar mode.
        // A transparent settings window on macOS 26 can briefly flash around
        // the frame while the scene and activation policy are being restored.
        window.isOpaque = true
        window.backgroundColor = NSColor.windowBackgroundColor
    }

    static func releaseSettingsWindow() {
        settingsController = nil
    }
}
