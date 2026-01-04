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

    private var titlebarEffectView: NSVisualEffectView?
    private var opacityObserver: Any?

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

        // Setup titlebar background if unified titlebar is enabled
        if unifiedTitlebar {
            setupTitlebarBackground()
        }
    }
    
    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // Setup titlebar background with visual effect view
    private func setupTitlebarBackground() {
        guard let window = window,
              let titlebarContainer = window.standardWindowButton(.closeButton)?.superview?.superview else {
            return
        }

        // Create visual effect view for titlebar
        let effectView = NSVisualEffectView(frame: titlebarContainer.bounds)
        effectView.material = .titlebar
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.autoresizingMask = [.width, .height]

        // Insert at the back so traffic lights remain visible
        titlebarContainer.addSubview(effectView, positioned: .below, relativeTo: nil)
        titlebarEffectView = effectView

        // Apply initial opacity from settings
        updateTitlebarOpacity()

        // Observe opacity changes using block-based observer (safer memory management)
        opacityObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PHTVSettingsChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateTitlebarOpacity()
        }
    }

    private func updateTitlebarOpacity() {
        let enabled = UserDefaults.standard.object(forKey: "vEnableLiquidGlassBackground") as? Bool ?? true
        let opacity = UserDefaults.standard.object(forKey: "vSettingsBackgroundOpacity") as? Double ?? 1.0

        if enabled {
            titlebarEffectView?.alphaValue = CGFloat(opacity)
        } else {
            titlebarEffectView?.alphaValue = 1.0
        }
    }

    // Handle window close to release reference
    func windowWillClose(_ notification: Notification) {
        // Remove block-based observer properly
        if let observer = opacityObserver {
            NotificationCenter.default.removeObserver(observer)
            opacityObserver = nil
        }

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
                .frame(minWidth: 720, minHeight: 500),
            title: "Cài đặt PHTV",
            size: NSSize(width: 820, height: 600),
            unifiedTitlebar: true
        )
        // Set minimum window size to prevent sidebar from being too narrow
        controller.window?.minSize = NSSize(width: 720, height: 500)
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
