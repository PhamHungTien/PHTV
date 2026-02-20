//
//  PHTVConvertToolSettingsService.swift
//  PHTV
//
//  Loads Convert Tool options from UserDefaults and applies them to C++ runtime.
//

import Foundation

@objcMembers
final class PHTVConvertToolSettingsService: NSObject {
    private static let keyDontAlertWhenCompleted = "convertToolDontAlertWhenCompleted"
    private static let keyToAllCaps = "convertToolToAllCaps"
    private static let keyToAllNonCaps = "convertToolToAllNonCaps"
    private static let keyToCapsFirstLetter = "convertToolToCapsFirstLetter"
    private static let keyToCapsEachWord = "convertToolToCapsEachWord"
    private static let keyRemoveMark = "convertToolRemoveMark"
    private static let keyFromCode = "convertToolFromCode"
    private static let keyToCode = "convertToolToCode"
    private static let keyHotKey = "convertToolHotKey"

    @objc class func loadFromUserDefaults() {
        let defaults = UserDefaults.standard

        PHTVResetConvertToolOptions()

        let hotKey = Int32(defaults.integer(forKey: keyHotKey))
        let resolvedHotKey: Int32 = hotKey == 0 ? Int32(PHTVDefaultConvertToolHotKey()) : hotKey

        PHTVSetConvertToolOptions(
            !defaults.bool(forKey: keyDontAlertWhenCompleted),
            defaults.bool(forKey: keyToAllCaps),
            defaults.bool(forKey: keyToAllNonCaps),
            defaults.bool(forKey: keyToCapsFirstLetter),
            defaults.bool(forKey: keyToCapsEachWord),
            defaults.bool(forKey: keyRemoveMark),
            Int32(defaults.integer(forKey: keyFromCode)),
            Int32(defaults.integer(forKey: keyToCode)),
            resolvedHotKey
        )

        PHTVNormalizeConvertToolOptions()
    }
}
