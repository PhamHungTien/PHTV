//
//  PHTVSmartSwitchRuntimeService.swift
//  PHTV
//
//  Runtime helpers for Smart Switch state transitions and persistence.
//

import Foundation

@objcMembers
final class PHTVSmartSwitchRuntimeService: NSObject {
    @objc class func appState(
        forBundleId bundleId: String,
        defaultLanguage: Int32,
        defaultCodeTable: Int32
    ) -> Int32 {
        let defaultState = PHTVSmartSwitchEncodeState(defaultLanguage, defaultCodeTable)
        return PHTVSmartSwitchGetAppState(bundleId, defaultState)
    }

    @objc class func isNotFoundState(_ state: Int32) -> Bool {
        state == PHTVSmartSwitchNotFound()
    }

    @objc class func decodedLanguage(fromState state: Int32) -> Int32 {
        PHTVSmartSwitchDecodeInputMethod(state)
    }

    @objc class func decodedCodeTable(fromState state: Int32) -> Int32 {
        PHTVSmartSwitchDecodeCodeTable(state)
    }

    @objc class func updateAppState(
        forBundleId bundleId: String,
        language: Int32,
        codeTable: Int32
    ) {
        let encodedState = PHTVSmartSwitchEncodeState(language, codeTable)
        PHTVSmartSwitchSetAppState(bundleId, encodedState)
    }

    @objc class func persistSnapshot() {
        let data = PHTVSmartSwitchSerializedData()
        PHTVSmartSwitchPersistenceService.saveSmartSwitchData(data as NSData)
    }
}
