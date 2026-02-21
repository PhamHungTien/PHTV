//
//  DebugSelfTests.swift
//  PHTV
//
//  Lightweight regression checks for debug builds.
//

import Carbon
import Foundation

#if DEBUG
@MainActor
enum DebugSelfTests {
    private static var didRun = false

    static func runOnce() {
        guard !didRun else { return }
        didRun = true

        runUserDefaultsHelperChecks()
        runMacroStorageChecks()
        runCxxInteropChecks()
        runConvertToolParityChecks()

        PHTVLogger.shared.debug("[DebugSelfTests] All debug checks passed")
    }

    private static func runUserDefaultsHelperChecks() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { clear(defaults: defaults, suiteName: suiteName) }

        assertCondition(
            defaults.bool(forKey: "missing_bool", default: true) == true,
            "Missing bool key should use fallback"
        )

        defaults.set(NSNumber(value: false), forKey: "numeric_bool")
        assertCondition(
            defaults.bool(forKey: "numeric_bool", default: true) == false,
            "Numeric bool value should be readable"
        )

        defaults.set(NSNumber(value: 42), forKey: "numeric_int")
        assertCondition(
            defaults.integer(forKey: "numeric_int", default: 0) == 42,
            "Numeric int value should be readable"
        )

        defaults.set(NSNumber(value: 1.25), forKey: "numeric_double")
        let value = defaults.double(forKey: "numeric_double", default: 0.0)
        assertCondition(
            Swift.abs(value - 1.25) < 0.000_001,
            "Numeric double value should be readable"
        )

        defaults.set(true, forKey: UserDefaultsKey.sparkleBetaChannel)
        defaults.set(false, forKey: UserDefaultsKey.autoInstallUpdates)
        defaults.enforceStableUpdateChannel()
        assertCondition(
            defaults.object(forKey: UserDefaultsKey.sparkleBetaChannel) == nil,
            "Stable channel enforcement should clear beta flag"
        )
        assertCondition(
            defaults.bool(forKey: UserDefaultsKey.autoInstallUpdates, default: false),
            "Stable channel enforcement should force auto install"
        )
    }

    private static func runMacroStorageChecks() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { clear(defaults: defaults, suiteName: suiteName) }

        assertCondition(
            MacroStorage.load(defaults: defaults).isEmpty,
            "Loading with missing macro data should return empty list"
        )

        let macroA = MacroItem(shortcut: "gm", expansion: "Good morning")
        let macroB = MacroItem(shortcut: "brb", expansion: "Be right back")
        let savedData = MacroStorage.save([macroA, macroB], defaults: defaults)
        assertCondition(savedData != nil, "Saving macros should return encoded data")

        let macroDate = MacroItem(shortcut: "dt", expansion: "dd/MM/yyyy", snippetType: .date)
        let enginePayload = MacroStorage.engineBinaryData(from: [macroA, macroDate])
        assertCondition(
            enginePayload.count > 2 && enginePayload[0] == 2 && enginePayload[1] == 0,
            "Engine macro payload should begin with little-endian macro count"
        )
        assertCondition(
            enginePayload.last == 1,
            "Engine macro payload should encode snippet type for each macro"
        )

        let loaded = MacroStorage.load(defaults: defaults)
        let shortcuts = loaded.map { $0.shortcut }.sorted()
        assertCondition(
            loaded.count == 2 && shortcuts == ["brb", "gm"],
            "Saved macros should round-trip through storage"
        )

        let invalidData = Data([0x00, 0x01, 0x02])
        assertCondition(
            MacroStorage.decode(invalidData, shouldLogError: false) == nil,
            "Invalid macro payload should fail decoding"
        )

        MacroStorage.postUpdated(macroId: UUID(), action: MacroUpdateAction.added)
    }

    private static func runCxxInteropChecks() {
        let packedValue: UInt32 = 0x1234
        let low = Int(PHTVEngineRuntimeFacade.lowByte(packedValue))
        let high = Int(PHTVEngineRuntimeFacade.hiByte(packedValue))
        let spaceKey = Int(PHTVEngineRuntimeFacade.spaceKeyCode())
        let maxBuffer = Int(PHTVEngineRuntimeFacade.engineMaxBuffer())
        assertCondition(
            low == 0x34 && high == 0x12 && spaceKey == kVK_Space && maxBuffer > 0,
            "Swift/C++ interop check should pass"
        )
        PHTVLogger.shared.debug(
            "[CxxInterop] low=\(low), high=\(high), spaceKey=\(spaceKey), maxBuffer=\(maxBuffer), valid=true"
        )
    }

    private static func runConvertToolParityChecks() {
        let hotKey = PHTVEngineDebugInteropFacade.convertToolDefaultHotKey()
        let options: [(Bool, Bool, Bool, Bool, Bool, Int32, Int32)] = [
            (false, false, false, false, false, 0, 0), // identity
            (true, false, false, false, false, 0, 0),  // all caps
            (false, true, false, false, false, 0, 0),  // all lowercase
            (false, false, true, false, false, 0, 0),  // sentence caps
            (false, false, false, true, false, 0, 0),  // title caps
            (false, false, false, false, true, 0, 0),  // remove mark
            (false, false, false, false, false, 0, 1), // unicode -> tcvn3
            (false, false, false, false, false, 0, 2), // unicode -> vni
            (false, false, false, false, false, 0, 3), // unicode -> unicode composite
            (false, false, false, false, false, 0, 4)  // unicode -> cp1258
        ]
        let samples = [
            "Tiếng Việt rất tuyệt vời!",
            "xin chào. hôm nay trời đẹp?",
            "ĐẶNG thị THẢO"
        ]

        for (toAllCaps,
             toAllNonCaps,
             toCapsFirstLetter,
             toCapsEachWord,
             removeMark,
             fromCode,
             toCode) in options {
            PHTVEngineDebugInteropFacade.convertToolResetOptions()
            PHTVEngineDebugInteropFacade.convertToolSetOptions(
                false,
                toAllCaps,
                toAllNonCaps,
                toCapsFirstLetter,
                toCapsEachWord,
                removeMark,
                fromCode,
                toCode,
                hotKey
            )
            PHTVEngineDebugInteropFacade.convertToolNormalizeOptions()

            let (defaults, suiteName) = makeIsolatedDefaults()
            defaults.set(toAllCaps, forKey: "convertToolToAllCaps")
            defaults.set(toAllNonCaps, forKey: "convertToolToAllNonCaps")
            defaults.set(toCapsFirstLetter, forKey: "convertToolToCapsFirstLetter")
            defaults.set(toCapsEachWord, forKey: "convertToolToCapsEachWord")
            defaults.set(removeMark, forKey: "convertToolRemoveMark")
            defaults.set(Int(fromCode), forKey: "convertToolFromCode")
            defaults.set(Int(toCode), forKey: "convertToolToCode")

            for sample in samples {
                let swiftConverted = PHTVConvertToolTextConversionService.convert(sample, defaults: defaults)
                let cxxConverted = legacyConvertToolConvert(sample)
                assertCondition(
                    swiftConverted == cxxConverted,
                    "ConvertTool parity mismatch for from=\(fromCode), to=\(toCode), input=\(sample)"
                )
            }

            clear(defaults: defaults, suiteName: suiteName)
        }
    }

    private static func legacyConvertToolConvert(_ text: String) -> String {
        text.withCString { source in
            guard let converted = PHTVEngineDebugInteropFacade.convertUtf8(source) else {
                return text
            }
            return String(validatingCString: converted) ?? text
        }
    }

    private static func makeIsolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "com.phamhungtien.phtv.debugtests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create isolated UserDefaults suite for debug checks")
        }
        return (defaults, suiteName)
    }

    private static func clear(defaults: UserDefaults, suiteName: String) {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private static func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            assertionFailure("[DebugSelfTests] \(message)")
            return
        }
    }
}
#endif
