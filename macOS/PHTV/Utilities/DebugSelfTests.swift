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
        runConvertToolChecks()

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
        let low = Int(EnginePackedData.lowByte(packedValue))
        let high = Int(EnginePackedData.highByte(packedValue))
        let spaceKey = Int(KeyCode.space)
        let maxBuffer = Int(PHTVEngineRuntimeFacade.engineMaxBuffer())
        let capsMask = EngineBitMask.caps
        let keyA: UInt32 = 0
        let key1: UInt32 = 18
        let lowercaseA = PHTVEngineRuntimeFacade.macroKeyCodeToCharacter(keyA)
        let uppercaseA = PHTVEngineRuntimeFacade.macroKeyCodeToCharacter(keyA | capsMask)
        let digitOne = PHTVEngineRuntimeFacade.macroKeyCodeToCharacter(key1)
        let symbolExclamation = PHTVEngineRuntimeFacade.macroKeyCodeToCharacter(key1 | capsMask)
        let shiftedSpace = PHTVEngineRuntimeFacade.macroKeyCodeToCharacter(UInt32(kVK_Space) | capsMask)
        let unicodeLookup = PHTVEngineRuntimeFacade.findCodeTableSourceKey(codeTable: 0, character: 0x00E2)
        let unicodeVariants = PHTVEngineRuntimeFacade.codeTableVariantCount(codeTable: 0, keyCode: 0)
        let vniCharacter = PHTVEngineRuntimeFacade.codeTableCharacterForKey(
            codeTable: 2,
            keyCode: 0,
            variantIndex: 1
        )
        assertCondition(
            low == 0x34 &&
            high == 0x12 &&
            spaceKey == kVK_Space &&
            maxBuffer > 0 &&
            lowercaseA == 0x0061 &&
            uppercaseA == 0x0041 &&
            digitOne == 0x0031 &&
            symbolExclamation == 0x0021 &&
            shiftedSpace == 0 &&
            unicodeLookup?.keyCode == 0 &&
            unicodeLookup?.variantIndex == 1 &&
            unicodeVariants == 14 &&
            vniCharacter == 0xE261,
            "Swift/C++ interop check should pass"
        )
        PHTVLogger.shared.debug(
            "[CxxInterop] low=\(low), high=\(high), spaceKey=\(spaceKey), maxBuffer=\(maxBuffer), macroMap=true, codeTableMap=true, valid=true"
        )
    }

    private static func runConvertToolChecks() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { clear(defaults: defaults, suiteName: suiteName) }

        let sample = "tiếng việt rất tuyệt vời"

        defaults.set(false, forKey: "convertToolToAllCaps")
        defaults.set(false, forKey: "convertToolToAllNonCaps")
        defaults.set(false, forKey: "convertToolToCapsFirstLetter")
        defaults.set(false, forKey: "convertToolToCapsEachWord")
        defaults.set(false, forKey: "convertToolRemoveMark")
        defaults.set(0, forKey: "convertToolFromCode")
        defaults.set(0, forKey: "convertToolToCode")
        let identity = PHTVConvertToolTextConversionService.convert(sample, defaults: defaults)
        assertCondition(identity == sample, "ConvertTool identity conversion should preserve input")

        defaults.set(true, forKey: "convertToolToAllCaps")
        let upper = PHTVConvertToolTextConversionService.convert(sample, defaults: defaults)
        assertCondition(upper == sample.uppercased(), "ConvertTool all-caps conversion should uppercase input")

        defaults.set(false, forKey: "convertToolToAllCaps")
        defaults.set(true, forKey: "convertToolToAllNonCaps")
        let lower = PHTVConvertToolTextConversionService.convert("ĐẶNG THỊ THẢO", defaults: defaults)
        assertCondition(
            lower == "ĐẶNG THỊ THẢO".lowercased(),
            "ConvertTool all-lower conversion should lowercase input"
        )

        defaults.set(false, forKey: "convertToolToAllNonCaps")
        defaults.set(true, forKey: "convertToolToCapsEachWord")
        let title = PHTVConvertToolTextConversionService.convert("xin chào phtv", defaults: defaults)
        assertCondition(title == "Xin Chào Phtv", "ConvertTool title-case conversion should capitalize each word")

        defaults.set(false, forKey: "convertToolToCapsEachWord")
        defaults.set(true, forKey: "convertToolToCapsFirstLetter")
        let sentence = PHTVConvertToolTextConversionService.convert("xin chào. hôm nay đẹp trời", defaults: defaults)
        assertCondition(
            sentence.hasPrefix("Xin chào."),
            "ConvertTool sentence-case conversion should capitalize first sentence character"
        )
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
