//
//  RuntimePerformanceTests.swift
//  PHTV
//
//  Opt-in microbenchmarks for latency-sensitive runtime lookups.
//

import XCTest
@testable import PHTV

final class RuntimePerformanceTests: XCTestCase {
    private let macroCount = 2_000
    private let lookupsPerMeasurement = 1_000

    override func tearDown() {
        PHTVEngineDataBridge.initializeMacroMap(with: MacroStorage.engineBinaryData(from: []))
        PHTVEngineRuntimeFacade.setCurrentCodeTable(0)
        super.tearDown()
    }

    func testMeasureNativeTextReplacementLegacyScan() throws {
        try requirePerformanceTests()
        let entries = makeMacros().map { nativeKeyCodes(for: $0.shortcut) }
        let candidate = nativeKeyCodes(for: "z")
        var matchCount = 0

        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            var measuredMatches = 0
            for _ in 0..<lookupsPerMeasurement {
                if legacyNativePrefixMatch(candidate, entries: entries) {
                    measuredMatches += 1
                }
            }
            matchCount += measuredMatches
        }

        XCTAssertEqual(matchCount, 0)
    }

    func testMeasureNativeTextReplacementPrefixIndex() throws {
        try requirePerformanceTests()
        PHTVEngineRuntimeFacade.setCurrentCodeTable(0)
        PHTVEngineDataBridge.initializeMacroMap(
            with: MacroStorage.engineBinaryData(from: makeMacros())
        )
        let candidate = nativeKeyCodes(for: "z")
        var matchCount = 0

        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            var measuredMatches = 0
            for _ in 0..<lookupsPerMeasurement {
                let matched = candidate.withUnsafeBufferPointer { buffer in
                    phtvHasNativeTextReplacementPrefix(
                        buffer.baseAddress,
                        Int32(buffer.count)
                    ) != 0
                }
                if matched {
                    measuredMatches += 1
                }
            }
            matchCount += measuredMatches
        }

        XCTAssertEqual(matchCount, 0)
    }

    private func requirePerformanceTests() throws {
        #if !PHTV_PERFORMANCE_TESTS
        throw XCTSkip(
            "Add PHTV_PERFORMANCE_TESTS to SWIFT_ACTIVE_COMPILATION_CONDITIONS to run runtime microbenchmarks"
        )
        #endif
    }

    private func makeMacros() -> [MacroItem] {
        (0..<macroCount).map { index in
            MacroItem(
                shortcut: benchmarkShortcut(index),
                expansion: "replacement",
                snippetType: .systemTextReplacement
            )
        }
    }

    private func benchmarkShortcut(_ index: Int) -> String {
        var value = index
        var suffix = [UInt8](repeating: Character("a").asciiValue!, count: 5)
        for position in suffix.indices.reversed() {
            suffix[position] += UInt8(value % 26)
            value /= 26
        }
        return "m" + String(decoding: suffix, as: UTF8.self)
    }

    private func nativeKeyCodes(for token: String) -> [UInt32] {
        token.map { character in
            let keyCode = UInt32(keyCode(for: Character(character.lowercased())))
            return character.isUppercase ? keyCode | EngineBitMask.caps : keyCode
        }
    }

    private func keyCode(for character: Character) -> UInt16 {
        switch character {
        case "a": return KEY_A; case "b": return KEY_B; case "c": return KEY_C
        case "d": return KEY_D; case "e": return KEY_E; case "f": return KEY_F
        case "g": return KEY_G; case "h": return KEY_H; case "i": return KEY_I
        case "j": return KEY_J; case "k": return KEY_K; case "l": return KEY_L
        case "m": return KEY_M; case "n": return KEY_N; case "o": return KEY_O
        case "p": return KEY_P; case "q": return KEY_Q; case "r": return KEY_R
        case "s": return KEY_S; case "t": return KEY_T; case "u": return KEY_U
        case "v": return KEY_V; case "w": return KEY_W; case "x": return KEY_X
        case "y": return KEY_Y; case "z": return KEY_Z
        default: return KEY_SPACE
        }
    }

    private func legacyNativePrefixMatch(
        _ candidate: [UInt32],
        entries: [[UInt32]]
    ) -> Bool {
        for macroKey in entries where macroKey.count >= candidate.count {
            let candidateCopy = Array(candidate[...])
            if zip(macroKey.prefix(candidateCopy.count), candidateCopy).allSatisfy({ $0 == $1 }) {
                return true
            }

            var loweredCandidate = candidateCopy
            var changed = false
            for index in loweredCandidate.indices {
                let lowered = loweredCandidate[index] & ~EngineBitMask.caps
                if lowered != loweredCandidate[index] {
                    changed = true
                    loweredCandidate[index] = lowered
                }
            }
            if changed,
               zip(macroKey.prefix(loweredCandidate.count), loweredCandidate)
               .allSatisfy({ $0 == $1 }) {
                return true
            }
        }
        return false
    }
}
