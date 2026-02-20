//
//  PHTVAccessibilityCoreBridge.swift
//  PHTV
//
//  C bridge helper for accessibility startup checks.
//

import ApplicationServices
import Foundation

@_cdecl("PHTVRunAccessibilitySmokeTest")
func phtvRunAccessibilitySmokeTestExport() -> Bool {
    _ = AXUIElementCreateSystemWide()
    return true
}
