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
            name: NSNotification.Name("InputMethodChanged"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCodeTableChanged(_:)),
            name: NSNotification.Name("CodeTableChanged"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToggleEnabled(_:)),
            name: NSNotification.Name("ToggleEnabled"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowConvertTool),
            name: NSNotification.Name("ShowConvertTool"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowAbout),
            name: NSNotification.Name("ShowAbout"),
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
        // Show convert tool window
        // Call existing method to show convert tool
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
