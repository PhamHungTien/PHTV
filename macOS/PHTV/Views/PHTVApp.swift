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

        // Configure memory-only URL cache before any service can create URL sessions.
        // This avoids fallback disk cache paths that may fail in sandboxed contexts.
        URLCache.shared = URLCache(
            memoryCapacity: 8 * 1024 * 1024,
            diskCapacity: 0,
            diskPath: nil
        )

        // CRITICAL: Initialize AppState first so all shared state is ready
        // before any notification-driven services start.
        _ = AppState.shared
        MemoryPressureMonitor.shared.start()

        // Initialize SettingsNotificationObserver to listen for notifications
        _ = SettingsNotificationObserver.shared
        NSLog("PHTV-APP-INIT-END")
    }

    var body: some Scene {
        // Menu bar extra - using native menu style
        MenuBarExtra {
            StatusBarMenuView()
                .environmentObject(appState)
        } label: {
            let size = nativeMenuBarIconSize(CGFloat(appState.menuBarIconSize))
            let iconName = menuBarIconAssetName(
                isEnabled: appState.isEnabled,
                useVietnameseIcon: appState.useVietnameseMenubarIcon
            )

            if let nsImage = makeMenuBarIconImage(named: iconName, size: size) {
                Image(nsImage: nsImage)
                    .renderingMode(.original)
                    .id("\(iconName)-\(Int(size * 100))")
            } else {
                Text(appState.isEnabled ? "Vi" : "En")
                    .font(.system(size: max(11, size * 0.72), weight: .semibold, design: .rounded))
            }
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

private func menuBarIconAssetName(isEnabled: Bool, useVietnameseIcon: Bool) -> String {
    if !isEnabled {
        return "menubar_english"
    }
    if useVietnameseIcon {
        return "menubar_vietnamese"
    }
    return "menubar_icon"
}

@MainActor
private func makeMenuBarIconImage(named iconName: String, size: CGFloat) -> NSImage? {
    let quantizedSize = (size * 100).rounded() / 100
    let cacheKey = "\(iconName)-\(quantizedSize)"
    if let cached = menuBarIconCache[cacheKey] {
        return cached
    }

    guard let baseIcon = NSImage(named: NSImage.Name(iconName)) else {
        return nil
    }

    let targetSize = NSSize(width: quantizedSize, height: quantizedSize)
    let renderedImage = NSImage(size: targetSize)
    renderedImage.lockFocus()
    baseIcon.draw(
        in: NSRect(origin: .zero, size: targetSize),
        from: .zero,
        operation: .sourceOver,
        fraction: 1.0,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    renderedImage.unlockFocus()
    renderedImage.size = targetSize
    menuBarIconCache[cacheKey] = renderedImage
    return renderedImage
}

private func nativeMenuBarIconSize(_ requestedSize: CGFloat) -> CGFloat {
    let minSize: CGFloat = 12.0
    let maxNativeSize = max(minSize, min(18.0, NSStatusBar.system.thickness - 6.0))
    return min(max(requestedSize, minSize), maxNativeSize)
}
