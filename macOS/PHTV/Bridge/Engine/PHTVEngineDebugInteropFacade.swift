//
//  PHTVEngineDebugInteropFacade.swift
//  PHTV
//
//  Debug-only C++ bridge used by parity checks.
//

import Foundation

#if DEBUG
enum PHTVEngineDebugInteropFacade {
    static func convertToolDefaultHotKey() -> Int32 {
        Int32(phtvConvertToolDefaultHotKey())
    }

    static func convertToolResetOptions() {
        phtvConvertToolResetOptions()
    }

    static func convertToolSetOptions(
        _ dontAlertWhenCompleted: Bool,
        _ toAllCaps: Bool,
        _ toAllNonCaps: Bool,
        _ toCapsFirstLetter: Bool,
        _ toCapsEachWord: Bool,
        _ removeMark: Bool,
        _ fromCode: Int32,
        _ toCode: Int32,
        _ hotKey: Int32
    ) {
        phtvConvertToolSetOptions(
            dontAlertWhenCompleted,
            toAllCaps,
            toAllNonCaps,
            toCapsFirstLetter,
            toCapsEachWord,
            removeMark,
            fromCode,
            toCode,
            hotKey
        )
    }

    static func convertToolNormalizeOptions() {
        phtvConvertToolNormalizeOptions()
    }

    static func convertUtf8(_ source: UnsafePointer<CChar>) -> UnsafePointer<CChar>? {
        phtvEngineConvertUtf8(source)
    }
}
#endif
