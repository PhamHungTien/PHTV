//
//  PHTVEngineStartupDataService.swift
//  PHTV
//
//  Loads engine bootstrap data blobs from UserDefaults.
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
