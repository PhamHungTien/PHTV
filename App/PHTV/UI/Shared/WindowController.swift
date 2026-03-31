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

    convenience init<Content: View>(
        rootView: Content,
        title: String,
        size: NSSize = NSSize(width: 800, height: 600),
        unifiedTitlebar: Bool = false,
        frameAutosaveName: String? = nil
    ) {
        var styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        
        window.title = title
        window.contentViewController = NSHostingController(rootView: rootView)

        let resolvedAutosaveName = frameAutosaveName ?? (!title.isEmpty ? title : nil)
        if let resolvedAutosaveName {
            if !window.setFrameUsingName(resolvedAutosaveName) {
                window.center()
            }
            window.setFrameAutosaveName(resolvedAutosaveName)
        } else {
            window.center()
        }
        
        if unifiedTitlebar {
            // Full-size content view so NavigationSplitView extends under the
            // toolbar/titlebar — required for backgroundExtensionEffect() on macOS 26
            // and for the modern System-Settings-style look on earlier versions.
            window.styleMask.insert(.fullSizeContentView)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = false
            if #available(macOS 11.0, *) {
                // .unified aligns toolbar items with the titlebar traffic-light area,
                // matching the compact look used by System Settings.
                window.toolbarStyle = .unified
            }
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
        if window?.identifier?.rawValue.hasPrefix("settings") == true {
            Task { @MainActor in
                AppState.shared.flushPendingSettingsForWindowClose()
            }
            SettingsWindowHelper.releaseSettingsWindow()
            let appDelegate = AppDelegate.current()
            let showDock = UserDefaults.standard.bool(forKey: UserDefaultsKey.showIconOnDock)
            appDelegate?.showIcon(showDock)
        }
    }

}

    // MARK: - Convenience Factory Methods
extension SwiftUIWindowController {
    
    static func settingsWindow() -> SwiftUIWindowController {
        let controller = SwiftUIWindowController(
            rootView: SettingsWindowContent()
                .environmentObject(AppState.shared)
                .frame(minWidth: 800, minHeight: 600),
            title: "Cài đặt PHTV",
            size: NSSize(width: 950, height: 680),
            unifiedTitlebar: true,
            frameAutosaveName: "PHSettingsWindow"
        )
        // Set minimum window size to prevent sidebar from being too narrow
        controller.window?.identifier = NSUserInterfaceItemIdentifier("settings-window-controller")
        controller.window?.minSize = NSSize(width: 800, height: 600)
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
