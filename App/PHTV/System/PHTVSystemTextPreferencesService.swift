//
//  PHTVSystemTextPreferencesService.swift
//  PHTV
//
//  Manages the macOS "add period with double-space" text preference.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import CoreFoundation
import Foundation

/// PHTV's toggle mirrors the macOS "double-space inserts a period"
/// substitution (NSAutomaticPeriodSubstitutionEnabled in the global domain)
/// and owns it in both directions: toggle ON writes the system value to
/// enabled, toggle OFF (PHTV's default) writes it to disabled so double
/// spaces stay two plain spaces while typing Vietnamese.
@objcMembers
final class PHTVSystemTextPreferencesService: NSObject {

    private static var periodSubstitutionKey: CFString {
        "NSAutomaticPeriodSubstitutionEnabled" as CFString
    }

    class func applyDoubleSpacePeriodEnabled(_ enabled: Bool) {
        setGlobalPeriodSubstitution(enabled)
        // Mirror into the typing engine so auto-capitalization treats the
        // macOS-inserted period (from two spaces) as a sentence terminator.
        PHTVEngineRuntimeFacade.setDoubleSpacePeriod(enabled ? 1 : 0)
        NSLog("[SystemTextPrefs] Double-space period substitution %@", enabled ? "enabled" : "disabled")
    }

    /// Applies the persisted choice at launch so the system value matches
    /// PHTV's toggle even when another tool changed it while PHTV was off.
    class func applyPersistedDoubleSpacePeriodPreference(in defaults: UserDefaults = .standard) {
        let enabled = defaults.bool(
            forKey: UserDefaultsKey.doubleSpacePeriodEnabled,
            default: Defaults.doubleSpacePeriodEnabled
        )
        setGlobalPeriodSubstitution(enabled)
        PHTVEngineRuntimeFacade.setDoubleSpacePeriod(enabled ? 1 : 0)
    }

    private class func setGlobalPeriodSubstitution(_ enabled: Bool) {
        CFPreferencesSetValue(
            periodSubstitutionKey,
            enabled ? kCFBooleanTrue : kCFBooleanFalse,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        CFPreferencesSynchronize(
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
    }
}
