//
//  PHTVStatusItemRecoveryPolicy.swift
//  PHTV
//

import Foundation

enum PHTVStatusItemRecoveryPolicy {
    static func delay(
        operatingSystemVersion: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
    ) -> Duration {
        operatingSystemVersion.majorVersion == 27
            ? .milliseconds(1_250)
            : .milliseconds(750)
    }
}
