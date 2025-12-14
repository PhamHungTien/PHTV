//
//  WindowController.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import AppKit

/// Window controller for hosting SwiftUI views in NSWindow
class SwiftUIWindowController: NSWindowController, NSWindowDelegate {
    
    convenience init<Content: View>(rootView: Content, title: String, size: NSSize = NSSize(width: 800, height: 600), unifiedTitlebar: Bool = false) {
        var styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        
        if unifiedTitlebar {
            styleMask.insert(.fullSizeContentView)
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        
        window.title = title
        window.center()
        window.contentView = NSHostingView(rootView: rootView)
        window.setFrameAutosaveName(title)
        
        if unifiedTitlebar {
            // Completely hide titlebar, content extends to top
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            
            // Remove the toolbar completely
            window.toolbar = nil
            
            // Make window movable by dragging background
            window.isMovableByWindowBackground = true
            
            // Hide title bar but keep traffic lights
            window.standardWindowButton(.closeButton)?.superview?.superview?.isHidden = false
        }
        
        self.init(window: window)
        window.delegate = self
    }
    
    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // Handle window close to release reference
    func windowWillClose(_ notification: Notification) {
        // Restore dock icon state to user preference when closing settings
        if window?.title == "Cài đặt PHTV" || window?.title == "Cài đặt" {
            let appDelegate = NSApplication.shared.delegate as? AppDelegate
            let showDock = UserDefaults.standard.bool(forKey: "vShowIconOnDock")
            appDelegate?.showIcon(showDock)
        }
    }
}

// MARK: - Convenience Factory Methods
extension SwiftUIWindowController {
    
    static func settingsWindow() -> SwiftUIWindowController {
        let controller = SwiftUIWindowController(
            rootView: SettingsView()
                .environmentObject(AppState.shared)
                .frame(minWidth: 700, minHeight: 500),
            title: "Cài đặt PHTV",
            size: NSSize(width: 800, height: 600),
            unifiedTitlebar: true
        )
        return controller
    }
    
    static func aboutWindow() -> SwiftUIWindowController {
        let controller = SwiftUIWindowController(
            rootView: AboutView()
                .environmentObject(AppState.shared),
            title: "Về PHTV",
            size: NSSize(width: 500, height: 600)
        )
        if let mask = controller.window?.styleMask {
            var newMask = mask
            newMask.remove(.resizable)
            controller.window?.styleMask = newMask
        }
        return controller
    }
}
