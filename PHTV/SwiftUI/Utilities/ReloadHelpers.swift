//
//  ReloadHelpers.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

/// Helper struct for macro reload notifications
struct MacroReloadHelper {
    /// Notify backend about macro reload
    static func notifyMacroUpdate<T>(_ macros: T) {
        NotificationCenter.default.post(
            name: NSNotification.Name("MacrosUpdated"),
            object: macros
        )
    }
}

/// Helper struct for excluded apps reload notifications
struct ExcludedAppReloadHelper {
    /// Notify backend about excluded apps update
    static func notifyExcludedAppsUpdate<T>(_ apps: T) {
        NotificationCenter.default.post(
            name: NSNotification.Name("ExcludedAppsChanged"),
            object: apps
        )
    }
}
