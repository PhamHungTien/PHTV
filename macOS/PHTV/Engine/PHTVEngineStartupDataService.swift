//
//  PHTVEngineStartupDataService.swift
//  PHTV
//
//  Loads engine bootstrap data blobs from UserDefaults.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

@objcMembers
final class PHTVEngineStartupDataService: NSObject {
    private static let legacyMacroDataKey = "macroData"

    @objc class func loadFromUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: legacyMacroDataKey)

        let userMacros = MacroStorage.load(defaults: defaults)
        let macroSnapshot = PHTVSystemTextReplacementService.runtimeMacroSnapshot(
            userMacros: userMacros,
            defaults: defaults
        )
        let macroData = MacroStorage.engineBinaryData(from: macroSnapshot.macros)
        PHTVEngineDataBridge.initializeMacroMap(with: macroData)

        PHTVSmartSwitchRuntimeService.loadFromPersistedData()
    }
}
