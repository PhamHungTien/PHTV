//
//  PHTVCoreSettingsBootstrapService.swift
//  PHTV
//
//  Bootstraps runtime settings from UserDefaults.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

@objcMembers
final class PHTVCoreSettingsBootstrapService: NSObject {
    @objc class func loadFromUserDefaults() {
        // Keep bootstrap defaults aligned even when this path is hit outside app launch.
        SettingsBootstrap.registerDefaults()

        _ = PHTVManager.loadRuntimeSettingsFromUserDefaults()
        let defaults = UserDefaults.standard

        // Preserve bootstrap-only runtime fields that are intentionally not in the regular tokenized loader.
        PHTVEngineRuntimeFacade.setFreeMark(0)
        PHTVEngineRuntimeFacade.setFixRecommendBrowser(
            Int32(defaults.integer(forKey: "FixRecommendBrowser"))
        )
        PHTVEngineRuntimeFacade.setTempOffSpelling(Int32(defaults.integer(forKey: "vTempOffSpelling")))

        PHTVEngineRuntimeFacade.setOtherLanguageMode(Int32(defaults.integer(forKey: "vOtherLanguage")))
        PHTVEngineRuntimeFacade.setTempOffEngine(Int32(defaults.integer(forKey: "vTempOffPHTV")))
        PHTVEngineRuntimeFacade.setSafeMode(defaults.bool(forKey: UserDefaultsKey.safeMode))
    }
}
