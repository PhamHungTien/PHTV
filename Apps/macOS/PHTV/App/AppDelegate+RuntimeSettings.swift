//
//  AppDelegate+RuntimeSettings.swift
//  PHTV
//
//  Runtime settings loading helpers.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

struct PHTVRuntimeSettingsReloadResult {
    let oldSnapshot: [String: NSNumber]
    let newSnapshot: [String: NSNumber]
    let token: UInt
}

@MainActor @objc extension AppDelegate {
    @nonobjc func reloadRuntimeSettingsFromUserDefaults() -> PHTVRuntimeSettingsReloadResult {
        let oldSnapshot = PHTVManager.runtimeSettingsSnapshot()
        let token = PHTVManager.loadRuntimeSettingsFromUserDefaults()
        let newSnapshot = PHTVManager.runtimeSettingsSnapshot()
        return PHTVRuntimeSettingsReloadResult(oldSnapshot: oldSnapshot, newSnapshot: newSnapshot, token: token)
    }

    func loadRuntimeSettingsFromUserDefaults() {
        lastSettingsChangeToken = reloadRuntimeSettingsFromUserDefaults().token
    }
}
