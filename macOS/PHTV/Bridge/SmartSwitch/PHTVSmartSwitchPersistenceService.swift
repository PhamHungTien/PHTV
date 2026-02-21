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

    private class func persistOnMain(_ action: @escaping @Sendable () -> Void) {
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async(execute: action)
        }
    }

    @objc class func saveSmartSwitchData(_ data: Data) {
        persistOnMain {
            let defaults = UserDefaults.standard
            if defaults.data(forKey: keySmartSwitchData) != data {
                defaults.set(data, forKey: keySmartSwitchData)
            }
        }
    }

    @objc class func saveInputMethod(_ language: Int32) {
        let value = Int(language)
        persistOnMain {
            let defaults = UserDefaults.standard
            if defaults.object(forKey: keyInputMethod) as? Int != value {
                defaults.set(value, forKey: keyInputMethod)
            }
        }
    }

    @objc class func saveCodeTable(_ codeTable: Int32) {
        let value = Int(codeTable)
        persistOnMain {
            let defaults = UserDefaults.standard
            if defaults.object(forKey: keyCodeTable) as? Int != value {
                defaults.set(value, forKey: keyCodeTable)
            }
        }
    }
}
