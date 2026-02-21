//
//  PHTVManager+SystemUtilities.swift
//  PHTV
//
//  System service wrapper methods for PHTVManager.
//

import AppKit
import Foundation

@objc extension PHTVManager {
    @objc(phtv_isTCCEntryCorrupt)
    class func phtv_isTCCEntryCorrupt() -> Bool {
        if canCreateEventTap() {
            return false
        }

        let isRegistered = PHTVTCCMaintenanceService.isAppRegisteredInTCC()
        if !isRegistered {
            NSLog("[TCC] ⚠️ CORRUPT ENTRY DETECTED - App not found in TCC database!")
            return true
        }

        return false
    }

    @objc(phtv_autoFixTCCEntryWithError:)
    class func phtv_autoFixTCCEntry(withError error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> Bool {
        PHTVTCCMaintenanceService.autoFixTCCEntry(withError: error)
    }

    @objc(phtv_restartTCCDaemon)
    class func phtv_restartTCCDaemon() {
        PHTVTCCMaintenanceService.restartTCCDaemon()
    }

    @objc(phtv_startTCCNotificationListener)
    class func phtv_startTCCNotificationListener() {
        PHTVTCCNotificationService.startListening()
    }

    @objc(phtv_stopTCCNotificationListener)
    class func phtv_stopTCCNotificationListener() {
        PHTVTCCNotificationService.stopListening()
    }

    @objc(phtv_getTableCodes)
    class func phtv_getTableCodes() -> [String] {
        [
            "Unicode",
            "TCVN3 (ABC)",
            "VNI Windows",
            "Unicode tổ hợp",
            "Vietnamese Locale CP 1258"
        ]
    }

    @objc(phtv_getApplicationSupportFolder)
    class func phtv_getApplicationSupportFolder() -> String {
        let applicationSupportDirectory = NSSearchPathForDirectoriesInDomains(
            .applicationSupportDirectory,
            .userDomainMask,
            true
        ).first ?? (NSHomeDirectory() + "/Library/Application Support")
        return applicationSupportDirectory + "/PHTV"
    }

    @objc(phtv_getBinaryArchitectures)
    class func phtv_getBinaryArchitectures() -> String {
        PHTVBinaryIntegrityService.getBinaryArchitectures()
    }

    @objc(phtv_getBinaryHash)
    class func phtv_getBinaryHash() -> String? {
        PHTVBinaryIntegrityService.getBinaryHash()
    }

    @objc(phtv_hasBinaryChangedSinceLastRun)
    class func phtv_hasBinaryChangedSinceLastRun() -> Bool {
        PHTVBinaryIntegrityService.hasBinaryChangedSinceLastRun()
    }

    @objc(phtv_checkBinaryIntegrity)
    class func phtv_checkBinaryIntegrity() -> Bool {
        PHTVBinaryIntegrityService.checkBinaryIntegrity()
    }

    private class func convertTextWithEngine(_ text: String) -> String {
        PHTVConvertToolTextConversionService.convertText(text)
    }

    @objc(phtv_quickConvert)
    class func phtv_quickConvert() -> Bool {
        let pasteboard = NSPasteboard.general
        var htmlString = pasteboard.string(forType: .html)
        var rawString = pasteboard.string(forType: .string)
        var converted = false

        if let html = htmlString {
            htmlString = convertTextWithEngine(html)
            converted = true
        }
        if let raw = rawString {
            rawString = convertTextWithEngine(raw)
            converted = true
        }

        guard converted else {
            return false
        }

        pasteboard.clearContents()
        if let htmlString {
            pasteboard.setString(htmlString, forType: .html)
        }
        if let rawString {
            pasteboard.setString(rawString, forType: .string)
        }
        return true
    }

    @objc(phtv_isSafeModeEnabled)
    class func phtv_isSafeModeEnabled() -> Bool {
        PHTVEngineRuntimeFacade.safeModeEnabled()
    }

    @objc(phtv_setSafeModeEnabled:)
    class func phtv_setSafeModeEnabled(_ enabled: Bool) {
        PHTVEngineRuntimeFacade.setSafeMode(enabled)
        UserDefaults.standard.set(enabled, forKey: "SafeMode")

        if enabled {
            NSLog("[SafeMode] ENABLED - Accessibility API calls will be skipped")
        } else {
            NSLog("[SafeMode] DISABLED - Normal Accessibility API calls")
        }
    }

    @objc(phtv_clearAXTestFlag)
    class func phtv_clearAXTestFlag() {
        UserDefaults.standard.set(false, forKey: "AXTestInProgress")
        NSLog("[SafeMode] Cleared AX test flag on normal termination")
    }
}
