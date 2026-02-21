//
//  PHTVSafeModeStartupService.swift
//  PHTV
//
//  Recovers Safe Mode state after AX crashes and validates AX API at startup.
//

import Foundation

@objcMembers
final class PHTVSafeModeStartupService: NSObject {
    private static let keySafeMode = "SafeMode"
    private static let keyAXTestInProgress = "AXTestInProgress"

    @objc class func recoverAndValidateAccessibilityState() {
        let defaults = UserDefaults.standard

        if defaults.bool(forKey: keyAXTestInProgress) {
            phtvRuntimeSetSafeMode(true)
            defaults.set(true, forKey: keySafeMode)
            defaults.set(false, forKey: keyAXTestInProgress)
            NSLog("[PHTV] ⚠️ Auto-enabled Safe Mode due to previous AX crash")
        }

        guard !phtvRuntimeSafeMode() else {
            return
        }

        defaults.set(true, forKey: keyAXTestInProgress)

        if PHTVRunAccessibilitySmokeTest() {
            defaults.set(false, forKey: keyAXTestInProgress)
            NSLog("[PHTV] AX API test passed")
            return
        }

        phtvRuntimeSetSafeMode(true)
        defaults.set(true, forKey: keySafeMode)
        defaults.set(false, forKey: keyAXTestInProgress)
        NSLog("[PHTV] ⚠️ AX API test failed, enabling Safe Mode")
    }
}
