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
    fileprivate static let minimumPostSendBlockUsValue: UInt32 = 20_000
    private static let nonCliTextChunkSizeValue: Int32 = 20
    private static let cliSpeedFastThresholdUs: UInt64 = 20_000
    private static let cliSpeedMediumThresholdUs: UInt64 = 32_000
    private static let cliSpeedSlowThresholdUs: UInt64 = 48_000
    private static let cliSpeedFactorFast = 2.1
    private static let cliSpeedFactorMedium = 1.6
    private static let cliSpeedFactorSlow = 1.3

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
            minPostSendBlockUs: minimumPostSendBlockUsValue
        )
    }

    @objc class func nonCliTextChunkSize() -> Int32 {
        nonCliTextChunkSizeValue
    }

    @objc(nextCliSpeedFactorForDeltaUs:currentFactor:)
    class func nextCliSpeedFactor(forDeltaUs deltaUs: UInt64, currentFactor: Double) -> Double {
        let targetFactor = cliSpeedTargetFactor(forDeltaUs: deltaUs)
        if targetFactor >= currentFactor {
            return targetFactor
        }

        let smoothed = (currentFactor * 0.7) + (targetFactor * 0.3)
        return max(1.0, smoothed)
    }

    private class func cliSpeedTargetFactor(forDeltaUs deltaUs: UInt64) -> Double {
        if deltaUs == 0 {
            return 1.0
        }
        if deltaUs <= cliSpeedFastThresholdUs {
            return cliSpeedFactorFast
        }
        if deltaUs <= cliSpeedMediumThresholdUs {
            return cliSpeedFactorMedium
        }
        if deltaUs <= cliSpeedSlowThresholdUs {
            return cliSpeedFactorSlow
        }
        return 1.0
    }
}

@objcMembers
final class PHTVCliRuntimeStateService: NSObject {
    nonisolated(unsafe) private static var runtimeCliSpeedFactor = 1.0
    nonisolated(unsafe) private static var runtimeCliBackspaceDelayUs: UInt64 = 0
    nonisolated(unsafe) private static var runtimeCliWaitAfterBackspaceUs: UInt64 = 0
    nonisolated(unsafe) private static var runtimeCliTextDelayUs: UInt64 = 0
    nonisolated(unsafe) private static var runtimeCliTextChunkSize: Int32 = PHTVCliProfileService.nonCliTextChunkSize()
    nonisolated(unsafe) private static var runtimeCliPostSendBlockUs: UInt64 = UInt64(PHTVCliProfileService.minimumPostSendBlockUsValue)
    nonisolated(unsafe) private static var runtimeCliLastKeyDownMachTime: UInt64 = 0
    nonisolated(unsafe) private static var runtimeCliBlockUntilMachTime: UInt64 = 0

    @objc(applyProfile:)
    class func applyProfile(_ profile: PHTVCliTimingProfileBox?) {
        if let profile {
            runtimeCliBackspaceDelayUs = UInt64(profile.backspaceDelayUs)
            runtimeCliWaitAfterBackspaceUs = UInt64(profile.waitAfterBackspaceUs)
            runtimeCliTextDelayUs = UInt64(profile.textDelayUs)
            runtimeCliTextChunkSize = profile.textChunkSize
            runtimeCliPostSendBlockUs = max(UInt64(PHTVCliProfileService.minimumPostSendBlockUsValue), UInt64(profile.postSendBlockUs))
            return
        }

        runtimeCliBackspaceDelayUs = 0
        runtimeCliWaitAfterBackspaceUs = 0
        runtimeCliTextDelayUs = 0
        runtimeCliTextChunkSize = PHTVCliProfileService.nonCliTextChunkSize()
        runtimeCliPostSendBlockUs = UInt64(PHTVCliProfileService.minimumPostSendBlockUsValue)
    }

    @objc(updateSpeedFactorForNowMachTime:)
    class func updateSpeedFactor(forNowMachTime now: UInt64) {
        if runtimeCliLastKeyDownMachTime == 0 {
            runtimeCliLastKeyDownMachTime = now
            runtimeCliSpeedFactor = 1.0
            return
        }

        let deltaUs = PHTVTimingService.machTimeToUs(now - runtimeCliLastKeyDownMachTime)
        runtimeCliLastKeyDownMachTime = now
        runtimeCliSpeedFactor = PHTVCliProfileService.nextCliSpeedFactor(
            forDeltaUs: deltaUs,
            currentFactor: runtimeCliSpeedFactor
        )
    }

    @objc class func resetSpeedState() {
        runtimeCliSpeedFactor = 1.0
        runtimeCliLastKeyDownMachTime = 0
    }

    @objc(scheduleBlockForMicroseconds:nowMachTime:)
    class func scheduleBlock(forMicroseconds microseconds: UInt64, nowMachTime now: UInt64) {
        guard microseconds > 0 else {
            return
        }
        let until = now + PHTVTimingService.microsecondsToMachTime(microseconds)
        if until > runtimeCliBlockUntilMachTime {
            runtimeCliBlockUntilMachTime = until
        }
    }

    @objc(remainingBlockMicrosecondsForNowMachTime:)
    class func remainingBlockMicroseconds(forNowMachTime now: UInt64) -> UInt64 {
        guard runtimeCliBlockUntilMachTime > now else {
            return 0
        }
        return PHTVTimingService.machTimeToUs(runtimeCliBlockUntilMachTime - now)
    }

    @objc class func currentSpeedFactor() -> Double {
        runtimeCliSpeedFactor
    }

    @objc class func cliBackspaceDelayUs() -> UInt64 {
        runtimeCliBackspaceDelayUs
    }

    @objc class func cliWaitAfterBackspaceUs() -> UInt64 {
        runtimeCliWaitAfterBackspaceUs
    }

    @objc class func cliTextDelayUs() -> UInt64 {
        runtimeCliTextDelayUs
    }

    @objc class func cliTextChunkSize() -> Int32 {
        runtimeCliTextChunkSize
    }

    @objc class func cliPostSendBlockUs() -> UInt64 {
        runtimeCliPostSendBlockUs
    }
}
