//
//  PHTVEventContextBridgeService.swift
//  PHTV
//
//  Consolidates Accessibility and Spotlight helper calls for PHTV.mm.
//

import ApplicationServices
import Foundation

@objcMembers
final class PHTVEventContextBridgeService: NSObject {
    @objc(invalidateAccessibilityContextCaches)
    class func invalidateAccessibilityContextCaches() {
        PHTVAccessibilityService.invalidateContextDetectionCaches()
    }

    @objc(replaceFocusedTextViaAXWithBackspaceCount:insertText:verify:safeMode:)
    class func replaceFocusedTextViaAX(backspaceCount: Int32,
                                       insertText: String?,
                                       verify: Bool,
                                       safeMode: Bool) -> Bool {
        guard !safeMode else {
            return false
        }
        return PHTVAccessibilityService.replaceFocusedTextViaAX(Int(backspaceCount),
                                                                insertText: insertText,
                                                                verify: verify)
    }

    @objc(isFocusedElementAddressBarForSafeMode:)
    class func isFocusedElementAddressBar(forSafeMode safeMode: Bool) -> Bool {
        guard !safeMode else {
            return false
        }
        return PHTVAccessibilityService.isFocusedElementAddressBar()
    }

    @objc(isNotionCodeBlockForSafeMode:)
    class func isNotionCodeBlock(forSafeMode safeMode: Bool) -> Bool {
        guard !safeMode else {
            return false
        }
        return PHTVAccessibilityService.isNotionCodeBlock()
    }

    @objc(handleSpotlightCacheInvalidationForType:keycode:flags:)
    class func handleSpotlightCacheInvalidation(forType type: CGEventType,
                                                keycode: UInt16,
                                                flags: CGEventFlags) {
        PHTVSpotlightDetectionService.handleSpotlightCacheInvalidation(type,
                                                                       keycode: CGKeyCode(keycode),
                                                                       flags: flags)
    }

    @objc(trackExternalDelete)
    class func trackExternalDelete() {
        PHTVSpotlightDetectionService.trackExternalDelete()
    }

    @objc(externalDeleteCountValue)
    class func externalDeleteCountValue() -> Int32 {
        Int32(PHTVSpotlightDetectionService.externalDeleteCountValue())
    }

    @objc(elapsedSinceLastExternalDeleteMs)
    class func elapsedSinceLastExternalDeleteMs() -> UInt64 {
        PHTVSpotlightDetectionService.elapsedSinceLastExternalDeleteMs()
    }
}
