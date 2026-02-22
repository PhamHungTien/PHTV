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
        // Menu bar extra - native SwiftUI menu bar presentation.
        MenuBarExtra {
            StatusBarMenuView()
                .environmentObject(appState)
        } label: {
            let iconName = menuBarIconAssetName(
                isEnabled: appState.isEnabled,
                useVietnameseIcon: appState.useVietnameseMenubarIcon
            )
            let iconSize = manualMenuBarIconSize(appState.menuBarIconSize)
            let iconRenderToken = "\(iconName)-\(Int((iconSize * 10).rounded()))"

            if let renderedIcon = makeMenuBarIconImage(named: iconName, size: iconSize) {
                Image(nsImage: renderedIcon)
                    .renderingMode(.template)
                    .id(iconRenderToken)
            } else {
                Image(iconName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .id("\(iconRenderToken)-fallback")
            }
        }
        .menuBarExtraStyle(.menu)

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

private func menuBarIconAssetName(isEnabled: Bool, useVietnameseIcon: Bool) -> String {
    if !isEnabled {
        return "menubar_english"
    }
    if useVietnameseIcon {
        return "menubar_vietnamese"
    }
    return "menubar_icon"
}

private func manualMenuBarIconSize(_ requestedSize: Double) -> CGFloat {
    let bounds = menuBarIconSizeBounds()
    guard requestedSize.isFinite else {
        return min(max(CGFloat(Defaults.menuBarIconSize), bounds.lowerBound), bounds.upperBound)
    }
    return min(max(CGFloat(requestedSize), bounds.lowerBound), bounds.upperBound)
}

private func menuBarIconSizeBounds() -> ClosedRange<CGFloat> {
    let minSize: CGFloat = 12.0
    let nativeCap = NSStatusBar.system.thickness - 4.0
    let maxSize = max(minSize, nativeCap)
    return minSize...maxSize
}

@MainActor
private var menuBarIconImageCache: [String: NSImage] = [:]

@MainActor
private func makeMenuBarIconImage(named iconName: String, size: CGFloat) -> NSImage? {
    let bounds = menuBarIconSizeBounds()
    let quantizedSize = min(max((size * 10).rounded() / 10, bounds.lowerBound), bounds.upperBound)
    let cacheKey = "\(iconName)-\(quantizedSize)"

    if let cachedImage = menuBarIconImageCache[cacheKey] {
        return cachedImage
    }

    guard let baseIcon = NSImage(named: NSImage.Name(iconName))?.copy() as? NSImage else {
        return nil
    }
    baseIcon.isTemplate = true

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
    renderedImage.isTemplate = true
    renderedImage.size = targetSize

    if menuBarIconImageCache.count > 256 {
        menuBarIconImageCache.removeAll(keepingCapacity: true)
    }
    menuBarIconImageCache[cacheKey] = renderedImage
    return renderedImage
}
