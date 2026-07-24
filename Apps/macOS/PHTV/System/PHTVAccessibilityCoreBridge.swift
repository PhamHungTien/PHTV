//
//  PHTVAccessibilityCoreBridge.swift
//  PHTV
//
//  C bridge helper for accessibility startup checks.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import ApplicationServices
import Foundation

enum PHTVAccessibilityCoreBridge {
    static func runAccessibilitySmokeTest() -> Bool {
        _ = AXUIElementCreateSystemWide()
        return true
    }
}
