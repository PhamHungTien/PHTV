//
//  PHTVRuntimeUIBridgeService.swift
//  PHTV
//
//  Bridges runtime callbacks from the core event pipeline to AppDelegate/UI updates.
//

import AppKit
import Foundation

@MainActor
@objcMembers
final class PHTVRuntimeUIBridgeService: NSObject {
    private class var appDelegate: AppDelegate? {
        NSApp.delegate as? AppDelegate
    }

    @objc class func handleInputMethodChangeFromHotkey() {
        appDelegate?.onImputMethodChanged(true)
    }

    @objc class func refreshAfterSmartSwitchLanguageChange(_ language: Int32) {
        appDelegate?.fillData()
        NotificationCenter.default.post(
            name: NSNotification.Name("LanguageChangedFromSmartSwitch"),
            object: NSNumber(value: language)
        )
    }

    @objc class func refreshAfterSmartSwitchCodeTableChange() {
        appDelegate?.fillData()
    }

    @objc class func triggerQuickConvert() {
        appDelegate?.onQuickConvert()
    }

    @objc class func triggerEmojiHotkey() {
        appDelegate?.onEmojiHotkeyTriggered()
    }
}
