//
//  PHTVAccessibilityCoreBridge.swift
//  PHTV
//
//  C bridge helper for accessibility startup checks.
//

import ApplicationServices
import Foundation

enum PHTVAccessibilityCoreBridge {
    static func runAccessibilitySmokeTest() -> Bool {
        _ = AXUIElementCreateSystemWide()
        return true
    }
}
