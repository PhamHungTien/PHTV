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
        UserDefaults.standard.removeObject(forKey: legacyMacroDataKey)

        let macros = MacroStorage.load(defaults: .standard)
        let macroData = MacroStorage.engineBinaryData(from: macros)
        PHTVEngineDataBridge.initializeMacroMap(with: macroData)

        PHTVSmartSwitchRuntimeService.loadFromPersistedData()
    }
}
