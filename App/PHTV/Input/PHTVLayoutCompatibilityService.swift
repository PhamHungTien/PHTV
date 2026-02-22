//
//  PHTVLayoutCompatibilityService.swift
//  PHTV
//
//  Auto-enables layout compatibility for non-US keyboard layouts on first run.
//

import Carbon
import Foundation

@objcMembers
final class PHTVLayoutCompatibilityService: NSObject {
    private static let keyLayoutCompat = "vPerformLayoutCompat"

    @objc class func autoEnableIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: keyLayoutCompat) == nil else {
            return
        }

        guard let currentKeyboard = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return
        }

        guard let sourceID = TISGetInputSourceProperty(currentKeyboard, kTISPropertyInputSourceID) else {
            return
        }
        let keyboardID = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String

        let isUSLayout = keyboardID.contains(".US") ||
            keyboardID.contains(".ABC") ||
            keyboardID == "com.apple.keylayout.US"

        guard !isUSLayout else {
            return
        }

        PHTVEngineRuntimeFacade.setPerformLayoutCompat(1)
        defaults.set(1, forKey: keyLayoutCompat)

        NSLog("[PHTV] Auto-enabled layout compatibility for non-US keyboard: %@", keyboardID)
    }
}
