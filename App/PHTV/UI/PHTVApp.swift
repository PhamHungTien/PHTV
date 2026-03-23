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
        // Menu bar icon and menu are managed by StatusBarMenuManager (NSStatusItem + NSMenu).
        // This gives native submenu hover behavior that SwiftUI MenuBarExtra lacks.

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

