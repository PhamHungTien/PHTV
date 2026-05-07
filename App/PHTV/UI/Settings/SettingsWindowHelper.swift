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
        if focusExistingSettingsWindow() {
            return
        }

        NSApp.setActivationPolicy(.regular)
        openControllerBackedSettingsWindow()
    }

    @discardableResult
    private static func focusExistingSettingsWindow() -> Bool {
        for window in NSApp.windows {
            let identifier = window.identifier?.rawValue ?? ""
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

                return true
            }
        }

        return false
    }

    private static func openControllerBackedSettingsWindow() {
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

    static func configureSettingsSceneWindow(_ window: NSWindow, alwaysOnTop: Bool) {
        if window.identifier?.rawValue.hasPrefix("settings") != true {
            window.identifier = NSUserInterfaceItemIdentifier("settings-swiftui-scene")
        }
        window.title = "Cài đặt PHTV"
        window.minSize = NSSize(width: 800, height: 600)
        applyWindowConfiguration(to: window, alwaysOnTop: alwaysOnTop)
    }

    static func applyWindowConfiguration(to window: NSWindow, alwaysOnTop: Bool) {
        window.level = alwaysOnTop ? .floating : .normal
        window.hidesOnDeactivate = false
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [.managed, .participatesInCycle, .moveToActiveSpace, .fullScreenAuxiliary]
        configureNativeSettingsChrome(for: window)
        window.isOpaque = true
        window.backgroundColor = NSColor.windowBackgroundColor
    }

    private static func configureNativeSettingsChrome(for window: NSWindow) {
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        if #available(macOS 11.0, *) {
            window.toolbarStyle = .unified
        }
    }

    static func releaseSettingsWindow() {
        settingsController = nil
    }
}
