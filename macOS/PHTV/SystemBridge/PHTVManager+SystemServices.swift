//
//  PHTVManager+SystemServices.swift
//  PHTV
//
//  Swift port of service-wrapper methods from PHTVManager.m.
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
}
