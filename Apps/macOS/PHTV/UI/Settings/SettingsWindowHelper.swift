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
        if focusExistingSettingsWindow() {
            return
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        openNativeSettingsWindow()
    }

    @discardableResult
    private static func focusExistingSettingsWindow() -> Bool {
        for window in NSApp.windows {
            let identifier = window.identifier?.rawValue ?? ""
            if identifier.hasPrefix("settings") || identifier == "com_apple_SwiftUI_Settings_window" {
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

    private static func openNativeSettingsWindow() {
        if let appMenu = NSApp.mainMenu?.items.first?.submenu {
            for item in appMenu.items {
                if item.keyEquivalent == "," {
                    appMenu.performActionForItem(at: appMenu.index(of: item))
                    return
                }
            }
        }
        
        // Fallback
        if #available(macOS 13.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    static func configureSettingsSceneWindow(_ window: NSWindow, alwaysOnTop: Bool) {
        if window.identifier?.rawValue.hasPrefix("settings") != true && window.identifier?.rawValue != "com_apple_SwiftUI_Settings_window" {
            window.identifier = NSUserInterfaceItemIdentifier("settings-swiftui-scene")
        }
        window.title = "Cài đặt PHTV"
        let minimumSize = NSSize(
            width: SettingsLayout.windowMinSize.width,
            height: SettingsLayout.windowMinSize.height
        )
        window.minSize = minimumSize
        window.contentMinSize = minimumSize
        applyWindowConfiguration(to: window, alwaysOnTop: alwaysOnTop)
    }

    static func applyWindowConfiguration(to window: NSWindow, alwaysOnTop: Bool) {
        window.level = alwaysOnTop ? .floating : .normal
        window.hidesOnDeactivate = false
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [.managed, .participatesInCycle, .moveToActiveSpace, .fullScreenAuxiliary]
        restoreNativeSettingsChrome(for: window)
    }

    private static func restoreNativeSettingsChrome(for window: NSWindow) {
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        if #available(macOS 11.0, *) {
            window.toolbarStyle = .unified
        }
    }

    static func releaseSettingsWindow() {
    }
}
