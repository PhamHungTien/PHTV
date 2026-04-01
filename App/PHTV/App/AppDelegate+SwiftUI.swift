//
//  AppDelegate+SwiftUI.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import AppKit

// Extension to bridge SwiftUI with existing Objective-C AppDelegate
extension AppDelegate {
    /// Legacy bridge observers kept for backward compatibility experiments.
    /// Main notification wiring lives in the shared AppDelegate notification layer.
    func setupLegacySwiftUINotificationBridge() {
        let center = NotificationCenter.default
        legacySwiftUINotificationTasks.forEach { $0.cancel() }
        legacySwiftUINotificationTasks = [
            makeNotificationTask(center: center, name: NotificationName.inputMethodChanged) { appDelegate, notification in
                appDelegate.handleLegacyInputMethodChanged(notification)
            },
            makeNotificationTask(center: center, name: NotificationName.codeTableChanged) { appDelegate, notification in
                appDelegate.handleLegacyCodeTableChanged(notification)
            },
            makeNotificationTask(center: center, name: NotificationName.toggleEnabled) { appDelegate, notification in
                appDelegate.handleToggleEnabled(notification)
            },
            makeNotificationTask(center: center, name: NotificationName.showConvertTool) { appDelegate, _ in
                appDelegate.handleShowConvertTool()
            },
            makeNotificationTask(center: center, name: NotificationName.openConvertTool) { appDelegate, _ in
                appDelegate.handleOpenConvertTool()
            },
            makeNotificationTask(center: center, name: NotificationName.showAbout) { appDelegate, _ in
                appDelegate.handleShowAbout()
            }
        ]
    }
    
    @objc private func handleLegacyInputMethodChanged(_ notification: Notification) {
        guard let inputMethod = notification.object as? Int else { return }
        // Runtime bridge now owns input-type state.
        PHTVLogger.shared.input("Input method changed to: \(inputMethod)")
    }

    @objc private func handleLegacyCodeTableChanged(_ notification: Notification) {
        guard let codeTable = notification.object as? Int else { return }
        // Runtime bridge now owns code-table state.
        PHTVLogger.shared.input("Code table changed to: \(codeTable)")
    }
    
    @objc private func handleToggleEnabled(_ notification: Notification) {
        guard let enabled = notification.object as? Bool else { return }
        // Toggle PHTV on/off
        PHTVLogger.shared.sync("PHTV enabled changed: \(enabled)")
    }
    
    @objc private func handleShowConvertTool() {
        // Call quickConvert to convert clipboard content
        let converted = PHTVManager.quickConvert()

        // Show notification to user
        if converted {
            // Play sound to indicate success
            NSSound.beep()
        }
    }

    @objc private func handleOpenConvertTool() {
        DispatchQueue.main.async {
            // Open settings window and navigate to System tab, then show convert tool
            if let openWindow = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix("settings") == true }) {
                // Set window level based on user preference
                let alwaysOnTop = UserDefaults.standard.bool(
                    forKey: UserDefaultsKey.settingsWindowAlwaysOnTop,
                    default: Defaults.settingsWindowAlwaysOnTop
                )
                openWindow.level = alwaysOnTop ? .floating : .normal
                
                // FIX: Ensure robust window behavior
                openWindow.hidesOnDeactivate = false
                openWindow.isMovableByWindowBackground = false
                openWindow.collectionBehavior = [.managed, .participatesInCycle, .moveToActiveSpace, .fullScreenAuxiliary]
                
                openWindow.makeKeyAndOrderFront(nil)
            } else {
                // Post notification to open settings first (will be handled by SettingsNotificationObserver)
                NotificationCenter.default.post(name: NotificationName.showSettings, object: nil)
            }
            NSApp.activate(ignoringOtherApps: true)

            // Post notification to show convert tool sheet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: NotificationName.showConvertToolSheet, object: nil)
            }
        }
    }

    @objc private func handleShowAbout() {
        // Show about window
        // Call existing method to show about
    }
    
    // Sync state to SwiftUI
    @objc func syncStateToSwiftUI() {
        DispatchQueue.main.async {
            _ = AppState.shared
            // Sync current state from Objective-C to SwiftUI
            // This will be called when settings change in Objective-C side
        }
    }
}
