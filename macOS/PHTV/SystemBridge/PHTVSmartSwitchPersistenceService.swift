//
//  PHTVSmartSwitchPersistenceService.swift
//  PHTV
//
//  Persists Smart Switch runtime data to UserDefaults.
//

import Foundation

@objcMembers
final class PHTVSmartSwitchPersistenceService: NSObject {
    private static let keySmartSwitchData = "smartSwitchKey"
    private static let keyInputMethod = "InputMethod"
    private static let keyCodeTable = "CodeTable"

    @objc class func saveSmartSwitchData(_ data: NSData) {
        UserDefaults.standard.set(data as Data, forKey: keySmartSwitchData)
    }

    @objc class func saveInputMethod(_ language: Int32) {
        UserDefaults.standard.set(Int(language), forKey: keyInputMethod)
    }

    @objc class func saveCodeTable(_ codeTable: Int32) {
        UserDefaults.standard.set(Int(codeTable), forKey: keyCodeTable)
    }
}
