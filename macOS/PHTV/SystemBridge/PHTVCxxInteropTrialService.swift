//
//  PHTVCxxInteropTrialService.swift
//  PHTV
//
//  Debug probe for Swift <-> C++ interop.
//

import Foundation

#if canImport(CxxStdlib)
import CxxStdlib
#endif

enum PHTVCxxInteropTrialService {
    static func verify() -> Bool {
        #if canImport(CxxStdlib)
        let probe = Int(phtvCxxInteropProbeValue())
        let sum = Int(phtvCxxInteropAdd(20, 22))
        let isValid = (probe == 20260221) && (sum == 42)
        PHTVLogger.shared.debug("[CxxInteropTrial] probe=\(probe), sum=\(sum), valid=\(isValid)")
        return isValid
        #else
        PHTVLogger.shared.error("[CxxInteropTrial] CxxStdlib unavailable; C++ interop is not enabled")
        return false
        #endif
    }
}
