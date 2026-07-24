//
//  AppDelegate+Defaults.swift
//  PHTV
//
//  Default configuration helpers.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

@MainActor @objc extension AppDelegate {
    func loadDefaultConfig() {
        PHTVManager.loadDefaultConfig()
        fillData()
    }

    func setGrayIcon(_ val: Bool) {
        _ = val
        fillData()
    }
}
