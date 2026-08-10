//
//  PHTVRemoteViewCrashGuardPolicy.swift
//  PHTV
//

import Foundation

enum PHTVRemoteViewCrashGuardPolicy {
    static func shouldInstall(
        operatingSystemVersion: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
    ) -> Bool {
        operatingSystemVersion.majorVersion == 27
    }
}
