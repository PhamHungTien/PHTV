//
//  PHTVSmartSwitchBridgeService.swift
//  PHTV
//
//  Applies Smart Switch transitions for core runtime callbacks.
//

import Foundation

@objcMembers
final class PHTVSmartSwitchBridgeService: NSObject {
    private static let appBundleIdentifier = "com.phamhungtien.phtv"

    @objc(handleActiveAppChangedForBundleId:useSmartSwitchKey:rememberCode:currentLanguage:currentCodeTable:)
    class func handleActiveAppChanged(
        forBundleId bundleId: String?,
        useSmartSwitchKey: Int32,
        rememberCode: Int32,
        currentLanguage: Int32,
        currentCodeTable: Int32
    ) {
        guard useSmartSwitchKey != 0 || rememberCode != 0 else {
            return
        }

        guard let bundleId, !bundleId.isEmpty, bundleId != appBundleIdentifier else {
            return
        }

        let state = PHTVSmartSwitchRuntimeService.appState(
            forBundleId: bundleId,
            defaultLanguage: currentLanguage,
            defaultCodeTable: currentCodeTable
        )

        if PHTVSmartSwitchRuntimeService.isNotFoundState(state) {
            PHTVSmartSwitchRuntimeService.persistSnapshot()
            return
        }

        let targetLanguage = PHTVSmartSwitchRuntimeService.decodedLanguage(fromState: state)
        if targetLanguage != currentLanguage {
            PHTVEngineRuntimeFacade.setCurrentLanguage(targetLanguage)
            PHTVSmartSwitchPersistenceService.saveInputMethod(targetLanguage)
            PHTVManager.requestNewSession()
            Task { @MainActor in
                PHTVRuntimeUIBridgeService.refreshAfterSmartSwitchLanguageChange(targetLanguage)
            }
        }

        let targetCodeTable = PHTVSmartSwitchRuntimeService.decodedCodeTable(fromState: state)
        if rememberCode != 0, targetCodeTable != currentCodeTable {
            PHTVEngineRuntimeFacade.setCurrentCodeTable(targetCodeTable)
            PHTVSmartSwitchPersistenceService.saveCodeTable(targetCodeTable)
            PHTVManager.requestNewSession()
            Task { @MainActor in
                PHTVRuntimeUIBridgeService.refreshAfterSmartSwitchCodeTableChange()
            }
        }
    }

    @objc(handleTableCodeChangedForBundleId:rememberCode:currentLanguage:currentCodeTable:)
    class func handleTableCodeChanged(
        forBundleId bundleId: String?,
        rememberCode: Int32,
        currentLanguage: Int32,
        currentCodeTable: Int32
    ) {
        guard rememberCode != 0 else {
            return
        }

        guard let bundleId, !bundleId.isEmpty, bundleId != appBundleIdentifier else {
            return
        }

        PHTVSmartSwitchRuntimeService.updateAppState(
            forBundleId: bundleId,
            language: currentLanguage,
            codeTable: currentCodeTable
        )
        PHTVSmartSwitchRuntimeService.persistSnapshot()
    }

    @objc(handleInputMethodChangedForBundleId:useSmartSwitchKey:currentLanguage:currentCodeTable:)
    class func handleInputMethodChanged(
        forBundleId bundleId: String?,
        useSmartSwitchKey: Int32,
        currentLanguage: Int32,
        currentCodeTable: Int32
    ) {
        guard useSmartSwitchKey != 0 else {
            return
        }

        guard let bundleId, !bundleId.isEmpty, bundleId != appBundleIdentifier else {
            return
        }

        PHTVSmartSwitchRuntimeService.updateAppState(
            forBundleId: bundleId,
            language: currentLanguage,
            codeTable: currentCodeTable
        )
        PHTVSmartSwitchRuntimeService.persistSnapshot()
    }
}
