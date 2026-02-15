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
    
    @objc func setupSwiftUIBridge() {
        // Subscribe to notifications from SwiftUI
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInputMethodChanged(_:)),
            name: NotificationName.inputMethodChanged,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCodeTableChanged(_:)),
            name: NotificationName.codeTableChanged,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToggleEnabled(_:)),
            name: NotificationName.toggleEnabled,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowConvertTool),
            name: NotificationName.showConvertTool,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenConvertTool),
            name: NotificationName.openConvertTool,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowAbout),
            name: NotificationName.showAbout,
            object: nil
        )
    }
    
    @objc private func handleInputMethodChanged(_ notification: Notification) {
        guard let inputMethod = notification.object as? Int else { return }
        // Update existing vInputType variable
        // This will be implemented to call existing methods
        print("Input method changed to: \(inputMethod)")
    }
    
    @objc private func handleCodeTableChanged(_ notification: Notification) {
        guard let codeTable = notification.object as? Int else { return }
        // Update existing vCodeTable variable
        print("Code table changed to: \(codeTable)")
    }
    
    @objc private func handleToggleEnabled(_ notification: Notification) {
        guard let enabled = notification.object as? Bool else { return }
        // Toggle PHTV on/off
        print("PHTV enabled: \(enabled)")
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
            if let openWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "settings" }) {
                // Set window level based on user preference
                let alwaysOnTop = UserDefaults.standard.bool(forKey: UserDefaultsKey.settingsWindowAlwaysOnTop)
                openWindow.level = alwaysOnTop ? .floating : .normal
                
                // FIX: Ensure robust window behavior
                openWindow.hidesOnDeactivate = false
                openWindow.isMovableByWindowBackground = true
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
