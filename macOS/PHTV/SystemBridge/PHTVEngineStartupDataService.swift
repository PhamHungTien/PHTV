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
        let defaults = UserDefaults.standard

        let macroData = defaults.data(forKey: "macroData") ?? Data()
        PHTVEngineDataBridge.initializeMacroMap(with: macroData)

        let smartSwitchData = defaults.data(forKey: "smartSwitchKey") ?? Data()
        PHTVEngineDataBridge.initializeSmartSwitchKey(with: smartSwitchData)
    }
}
