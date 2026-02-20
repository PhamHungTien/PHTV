//
//  PHTVCliProfileService.swift
//  PHTV
//
//  Maps bundle identifiers to CLI typing profile codes.
//

import Foundation

@objcMembers
final class PHTVCliProfileService: NSObject {
    @objc(profileCodeForBundleId:)
    class func profileCode(forBundleId bundleId: String?) -> Int32 {
        guard let bundleId, !bundleId.isEmpty else {
            return 0
        }

        if PHTVAppDetectionService.isVSCodeFamilyApp(bundleId) ||
            PHTVAppDetectionService.isJetBrainsApp(bundleId) {
            return 1
        }

        if PHTVAppDetectionService.isFastTerminalApp(bundleId) {
            return 2
        }

        if PHTVAppDetectionService.isMediumTerminalApp(bundleId) {
            return 3
        }

        if PHTVAppDetectionService.isSlowTerminalApp(bundleId) {
            return 4
        }

        return 0
    }
}
