//
//  PHTVApp.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import SwiftUI

@main
struct PHTVApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    @StateObject private var windowOpener = SettingsWindowOpener.shared

    init() {
        NSLog("PHTV-APP-INIT-START")

        // CRITICAL: Initialize AppState FIRST to avoid recursive dispatch_once lock
        // EmojiHotkeyManager.handleSettingsChanged() calls AppState.shared
        // If AppState is initializing when the notification fires, we get recursive lock
        _ = AppState.shared

        // Initialize SettingsNotificationObserver to listen for notifications
        _ = SettingsNotificationObserver.shared

        // Initialize EmojiHotkeyManager directly in SwiftUI init
        NSLog("PHTV-APP-INIT-EMOJI")
        _ = EmojiHotkeyManager.shared
        NSLog("PHTV-APP-INIT-END")
    }

    var body: some Scene {
        // Menu bar extra - using native menu style
        MenuBarExtra {
            StatusBarMenuView()
                .environmentObject(appState)
        } label: {
            // Use app icon (template); add slash when in English mode
            let size = CGFloat(appState.menuBarIconSize)
            Image(nsImage: makeMenuBarIconImage(size: size, slashed: !appState.isEnabled, useVietnameseIcon: appState.useVietnameseMenubarIcon))
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.menu)
        // Note: MenuBarExtra automatically updates when appState.isEnabled changes
        // No need for empty onChange handler that triggers unnecessary redraws

        // Settings window - managed by SwiftUI to avoid crashes
        Window("", id: "settings") {
            SettingsWindowContent()
                .environmentObject(appState)
                .frame(minWidth: 800, maxWidth: 1000, minHeight: 600, maxHeight: 900)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 950, height: 680)
        .windowResizability(.contentSize)
    }
}

// MARK: - Menu Bar Icon Helpers

@MainActor
private var menuBarIconCache: [String: NSImage] = [:]

@MainActor
private func makeMenuBarIconImage(size: CGFloat, slashed: Bool, useVietnameseIcon: Bool) -> NSImage {
    let cacheKey = "\(size)-\(slashed)-\(useVietnameseIcon)"
    if let cached = menuBarIconCache[cacheKey] {
        return cached
    }

    let targetSize = NSSize(width: size, height: size)
    let img = NSImage(size: targetSize)
    img.lockFocus()
    defer { img.unlockFocus() }

    let rect = NSRect(origin: .zero, size: targetSize)

    let baseIcon: NSImage? = {
        if slashed {
            if let englishIcon = NSImage(named: "menubar_english") {
                return englishIcon
            }
        }
        if useVietnameseIcon, let vietnameseIcon = NSImage(named: "menubar_vietnamese") {
            return vietnameseIcon
        }
        if let img = NSImage(named: "menubar_icon") {
            return img
        }
        return NSApplication.shared.applicationIconImage
    }()

    if let baseIcon {
        baseIcon.draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    img.isTemplate = true
    img.size = targetSize
    menuBarIconCache[cacheKey] = img
    return img
}
