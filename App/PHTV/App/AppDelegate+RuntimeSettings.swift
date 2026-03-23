//
//  AppDelegate+RuntimeSettings.swift
//  PHTV
//
//  Runtime settings loading helpers.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

@MainActor @objc extension AppDelegate {
    func loadRuntimeSettingsFromUserDefaults() {
        lastSettingsChangeToken = PHTVManager.loadRuntimeSettingsFromUserDefaults()
    }
}
