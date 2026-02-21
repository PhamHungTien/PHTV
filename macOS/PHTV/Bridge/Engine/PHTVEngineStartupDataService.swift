//
//  PHTVEngineStartupDataService.swift
//  PHTV
//
//  Loads engine bootstrap data blobs from UserDefaults.
//

import Foundation

@objcMembers
final class PHTVEngineStartupDataService: NSObject {
    @objc class func loadFromUserDefaults() {
        let macros = MacroStorage.load(defaults: .standard)
        let macroData = MacroStorage.engineBinaryData(from: macros)
        PHTVEngineDataBridge.initializeMacroMap(with: macroData)

        PHTVSmartSwitchRuntimeService.loadFromPersistedData()
    }
}
