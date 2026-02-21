//
//  DebugSelfTests.swift
//  PHTV
//
//  Lightweight regression checks for debug builds.
//

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
        let probe = Int(PHTVEngineRuntimeFacade.interopProbeValue())
        let sum = Int(PHTVEngineRuntimeFacade.interopAdd(20, 22))
        assertCondition(
            probe == 20260221 && sum == 42,
            "Swift/C++ interop check should pass"
        )
        PHTVLogger.shared.debug("[CxxInterop] probe=\(probe), sum=\(sum), valid=true")
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
