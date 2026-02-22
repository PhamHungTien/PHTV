//
//  SettingsWindowOpener.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import AppKit

@MainActor
final class SettingsWindowOpener: ObservableObject {
    static let shared = SettingsWindowOpener()
    @Published var shouldOpenWindow = false

    func requestOpenWindow() {
        // Set flag that will be observed by SwiftUI
        shouldOpenWindow = true

        // Also try to open window directly using NSApp
        // This works because SwiftUI Window scene registers with NSApp
        DispatchQueue.main.async {
            // Find the window by checking all windows
            for window in NSApp.windows {
                let identifier = window.identifier?.rawValue ?? ""
                if identifier.hasPrefix("settings") {
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                    self.shouldOpenWindow = false
                    return
                }
            }

            // If no window found, the SwiftUI scene might create one
            // We need to activate the app to trigger scene creation
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

