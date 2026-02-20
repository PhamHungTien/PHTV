//
//  PHTVCliProfileService.swift
//  PHTV
//
//  Maps bundle identifiers to CLI typing profile codes.
//

import Foundation

@objcMembers
final class PHTVCliTimingProfileBox: NSObject {
    let backspaceDelayUs: UInt32
    let waitAfterBackspaceUs: UInt32
    let textDelayUs: UInt32
    let textChunkSize: Int32
    let postSendBlockUs: UInt32

    fileprivate init(profile: PHTVCliProfileService.TimingProfile, minPostSendBlockUs: UInt32) {
        backspaceDelayUs = profile.backspaceDelayUs
        waitAfterBackspaceUs = profile.waitAfterBackspaceUs
        textDelayUs = profile.textDelayUs
        textChunkSize = profile.textChunkSize
        postSendBlockUs = max(minPostSendBlockUs, profile.textDelayUs &* 3)
    }
}

@objcMembers
final class PHTVCliProfileService: NSObject {
    fileprivate struct TimingProfile {
        let backspaceDelayUs: UInt32
        let waitAfterBackspaceUs: UInt32
        let textDelayUs: UInt32
        let textChunkSize: Int32
    }

    private static let profileByCode: [Int32: TimingProfile] = [
        1: TimingProfile(backspaceDelayUs: 8_000, waitAfterBackspaceUs: 25_000, textDelayUs: 8_000, textChunkSize: 1),  // IDE
        2: TimingProfile(backspaceDelayUs: 6_000, waitAfterBackspaceUs: 18_000, textDelayUs: 5_000, textChunkSize: 1),  // Fast terminal
        3: TimingProfile(backspaceDelayUs: 9_000, waitAfterBackspaceUs: 27_000, textDelayUs: 7_000, textChunkSize: 1),  // Medium terminal
        4: TimingProfile(backspaceDelayUs: 12_000, waitAfterBackspaceUs: 36_000, textDelayUs: 9_000, textChunkSize: 1), // Slow terminal
    ]

    private static let defaultProfile = TimingProfile(
        backspaceDelayUs: 8_000,
        waitAfterBackspaceUs: 24_000,
        textDelayUs: 6_000,
        textChunkSize: 1
    )
    private static let minimumPostSendBlockUs: UInt32 = 20_000
    private static let nonCliTextChunkSizeValue: Int32 = 20

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

    @objc(profileForCode:)
    class func profile(forCode profileCode: Int32) -> PHTVCliTimingProfileBox {
        let profile = profileByCode[profileCode] ?? defaultProfile
        return PHTVCliTimingProfileBox(
            profile: profile,
            minPostSendBlockUs: minimumPostSendBlockUs
        )
    }

    @objc class func nonCliTextChunkSize() -> Int32 {
        nonCliTextChunkSizeValue
    }
}
