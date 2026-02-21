//
//  PHTVEngineRuntimeFacade.swift
//  PHTV
//
//  Swift facade over C++ interop runtime/engine functions.
//

import Foundation

private func phtvCallStartNewSession() {
    startNewSession()
}

private func phtvCallClearCustomDictionary() {
    clearCustomDictionary()
}

@objcMembers
final class PHTVEngineRuntimeFacade: NSObject {
    private static let eventMarker: Int64 = 0x5048_5456 // "PHTV"
    private static let unicodeCompoundMarks: [UInt16] = [0x0301, 0x0300, 0x0309, 0x0303, 0x0323]
    // Mirror constants in Core/Engine/DataType.h.
    private static let engineCapsMask: UInt32 = 0x0001_0000
    private static let engineCharCodeMask: UInt32 = 0x0200_0000
    private static let enginePureCharacterMask: UInt32 = 0x8000_0000
    private static let engineDoNothingCodeValue: Int32 = 0
    private static let engineWillProcessCodeValue: Int32 = 1
    private static let engineRestoreCodeValue: Int32 = 3
    private static let engineReplaceMacroCodeValue: Int32 = 4
    private static let engineRestoreAndStartNewSessionCodeValue: Int32 = 5
    private static let engineMaxBufferValue: Int32 = 32
    private static let navigationKeyCodes: Set<UInt16> = [
        KeyCode.leftArrow,
        KeyCode.rightArrow,
        KeyCode.upArrow,
        KeyCode.downArrow,
        KeyCode.home,
        KeyCode.end,
        KeyCode.pageUp,
        KeyCode.pageDown
    ]
    private static let keyEventKeyboard = vKeyEvent(rawValue: 0)
    private static let keyEventMouse = vKeyEvent(rawValue: 1)
    private static let keyEventStateKeyDown = vKeyEventState(rawValue: 0)
    private static let keyEventStateMouseDown = vKeyEventState(rawValue: 2)
    // Mirror keyCodeToCharacter mapping in Core/Engine/Vietnamese.cpp.
    private static let macroKeyToCharacterUnshifted: [UInt16: UInt16] = [
        0: 0x0061, 11: 0x0062, 8: 0x0063, 2: 0x0064, 14: 0x0065, 3: 0x0066, 5: 0x0067, 4: 0x0068,
        34: 0x0069, 38: 0x006A, 40: 0x006B, 37: 0x006C, 46: 0x006D, 45: 0x006E, 31: 0x006F, 35: 0x0070,
        12: 0x0071, 15: 0x0072, 1: 0x0073, 17: 0x0074, 32: 0x0075, 9: 0x0076, 13: 0x0077, 7: 0x0078,
        16: 0x0079, 6: 0x007A,
        18: 0x0031, 19: 0x0032, 20: 0x0033, 21: 0x0034, 23: 0x0035, 22: 0x0036, 26: 0x0037, 28: 0x0038,
        25: 0x0039, 29: 0x0030,
        50: 0x0060, 27: 0x002D, 24: 0x003D, 33: 0x005B, 30: 0x005D, 42: 0x005C, 41: 0x003B, 39: 0x0027,
        43: 0x002C, 47: 0x002E, 44: 0x002F,
        49: 0x0020
    ]
    private static let macroKeyToCharacterShifted: [UInt16: UInt16] = [
        0: 0x0041, 11: 0x0042, 8: 0x0043, 2: 0x0044, 14: 0x0045, 3: 0x0046, 5: 0x0047, 4: 0x0048,
        34: 0x0049, 38: 0x004A, 40: 0x004B, 37: 0x004C, 46: 0x004D, 45: 0x004E, 31: 0x004F, 35: 0x0050,
        12: 0x0051, 15: 0x0052, 1: 0x0053, 17: 0x0054, 32: 0x0055, 9: 0x0056, 13: 0x0057, 7: 0x0058,
        16: 0x0059, 6: 0x005A,
        18: 0x0021, 19: 0x0040, 20: 0x0023, 21: 0x0024, 23: 0x0025, 22: 0x005E, 26: 0x0026, 28: 0x002A,
        25: 0x0028, 29: 0x0029,
        50: 0x007E, 27: 0x005F, 24: 0x002B, 33: 0x007B, 30: 0x007D, 42: 0x007C, 41: 0x003A, 39: 0x0022,
        43: 0x003C, 47: 0x003E, 44: 0x003F
    ]
    // Mirror _codeTable in Core/Engine/Vietnamese.cpp.
    private static let codeTableLookup: [[UInt32: [UInt16]]] = [
        [
            0x00000: [0x00C2, 0x00E2, 0x0102, 0x0103, 0x00C1, 0x00E1, 0x00C0, 0x00E0, 0x1EA2, 0x1EA3, 0x00C3, 0x00E3, 0x1EA0, 0x1EA1],
            0x0001F: [0x00D4, 0x00F4, 0x01A0, 0x01A1, 0x00D3, 0x00F3, 0x00D2, 0x00F2, 0x1ECE, 0x1ECF, 0x00D5, 0x00F5, 0x1ECC, 0x1ECD],
            0x00020: [0x0000, 0x0000, 0x01AF, 0x01B0, 0x00DA, 0x00FA, 0x00D9, 0x00F9, 0x1EE6, 0x1EE7, 0x0168, 0x0169, 0x1EE4, 0x1EE5],
            0x0000E: [0x00CA, 0x00EA, 0x0000, 0x0000, 0x00C9, 0x00E9, 0x00C8, 0x00E8, 0x1EBA, 0x1EBB, 0x1EBC, 0x1EBD, 0x1EB8, 0x1EB9],
            0x00002: [0x0110, 0x0111],
            0x20000: [0x1EA4, 0x1EA5, 0x1EA6, 0x1EA7, 0x1EA8, 0x1EA9, 0x1EAA, 0x1EAB, 0x1EAC, 0x1EAD],
            0x40000: [0x1EAE, 0x1EAF, 0x1EB0, 0x1EB1, 0x1EB2, 0x1EB3, 0x1EB4, 0x1EB5, 0x1EB6, 0x1EB7],
            0x2001F: [0x1ED0, 0x1ED1, 0x1ED2, 0x1ED3, 0x1ED4, 0x1ED5, 0x1ED6, 0x1ED7, 0x1ED8, 0x1ED9],
            0x4001F: [0x1EDA, 0x1EDB, 0x1EDC, 0x1EDD, 0x1EDE, 0x1EDF, 0x1EE0, 0x1EE1, 0x1EE2, 0x1EE3],
            0x40020: [0x1EE8, 0x1EE9, 0x1EEA, 0x1EEB, 0x1EEC, 0x1EED, 0x1EEE, 0x1EEF, 0x1EF0, 0x1EF1],
            0x2000E: [0x1EBE, 0x1EBF, 0x1EC0, 0x1EC1, 0x1EC2, 0x1EC3, 0x1EC4, 0x1EC5, 0x1EC6, 0x1EC7],
            0x00022: [0x00CD, 0x00ED, 0x00CC, 0x00EC, 0x1EC8, 0x1EC9, 0x0128, 0x0129, 0x1ECA, 0x1ECB],
            0x00010: [0x00DD, 0x00FD, 0x1EF2, 0x1EF3, 0x1EF6, 0x1EF7, 0x1EF8, 0x1EF9, 0x1EF4, 0x1EF5]
        ],
        [
            0x00000: [0x00A2, 0x00A9, 0x00A1, 0x00A8, 0x00B8, 0x00B8, 0x00B5, 0x00B5, 0x00B6, 0x00B6, 0x00B7, 0x00B7, 0x00B9, 0x00B9],
            0x0001F: [0x00A4, 0x00AB, 0x00A5, 0x00AC, 0x00E3, 0x00E3, 0x00DF, 0x00DF, 0x00E1, 0x00E1, 0x00E2, 0x00E2, 0x00E4, 0x00E4],
            0x00020: [0x0000, 0x0000, 0x00A6, 0x00AD, 0x00F3, 0x00F3, 0x00EF, 0x00EF, 0x00F1, 0x00F1, 0x00F2, 0x00F2, 0x00F4, 0x00F4],
            0x0000E: [0x00A3, 0x00AA, 0x0000, 0x0000, 0x00D0, 0x00D0, 0x00CC, 0x00CC, 0x00CE, 0x00CE, 0x00CF, 0x00CF, 0x00D1, 0x00D1],
            0x00002: [0x00A7, 0x00AE],
            0x20000: [0x00CA, 0x00CA, 0x00C7, 0x00C7, 0x00C8, 0x00C8, 0x00C9, 0x00C9, 0x00CB, 0x00CB],
            0x40000: [0x00BE, 0x00BE, 0x00BB, 0x00BB, 0x00BC, 0x00BC, 0x00BD, 0x00BD, 0x00C6, 0x00C6],
            0x2001F: [0x00E8, 0x00E8, 0x00E5, 0x00E5, 0x00E6, 0x00E6, 0x00E7, 0x00E7, 0x00E9, 0x00E9],
            0x4001F: [0x00ED, 0x00ED, 0x00EA, 0x00EA, 0x00EB, 0x00EB, 0x00EC, 0x00EC, 0x00EE, 0x00EE],
            0x40020: [0x00F8, 0x00F8, 0x00F5, 0x00F5, 0x00F6, 0x00F6, 0x00F7, 0x00F7, 0x00F9, 0x00F9],
            0x2000E: [0x00D5, 0x00D5, 0x00D2, 0x00D2, 0x00D3, 0x00D3, 0x00D4, 0x00D4, 0x00D6, 0x00D6],
            0x00022: [0x00DD, 0x00DD, 0x00D7, 0x00D7, 0x00D8, 0x00D8, 0x00DC, 0x00DC, 0x00DE, 0x00DE],
            0x00010: [0x00FD, 0x00FD, 0x00FA, 0x00FA, 0x00FB, 0x00FB, 0x00FC, 0x00FC, 0x00FE, 0x00FE]
        ],
        [
            0x00000: [0xC241, 0xE261, 0xCA41, 0xEA61, 0xD941, 0xF961, 0xD841, 0xF861, 0xDB41, 0xFB61, 0xD541, 0xF561, 0xCF41, 0xEF61],
            0x0001F: [0xC24F, 0xE26F, 0x00D4, 0x00F4, 0xD94F, 0xF96F, 0xD84F, 0xF86F, 0xDB4F, 0xFB6F, 0xD54F, 0xF56F, 0xCF4F, 0xEF6F],
            0x00020: [0x0000, 0x0000, 0x00D6, 0x00F6, 0xD955, 0xF975, 0xD855, 0xF875, 0xDB55, 0xFB75, 0xD555, 0xF575, 0xCF55, 0xEF75],
            0x0000E: [0xC245, 0xE265, 0x0000, 0x0000, 0xD945, 0xF965, 0xD845, 0xF865, 0xDB45, 0xFB65, 0xD545, 0xF565, 0xCF45, 0xEF65],
            0x00002: [0x00D1, 0x00F1],
            0x20000: [0xC141, 0xE161, 0xC041, 0xE061, 0xC541, 0xE561, 0xC341, 0xE361, 0xC441, 0xE461],
            0x40000: [0xC941, 0xE961, 0xC841, 0xE861, 0xDA41, 0xFA61, 0xDC41, 0xFC61, 0xCB41, 0xEB61],
            0x2001F: [0xC14F, 0xE16F, 0xC04F, 0xE06F, 0xC54F, 0xE56F, 0xC34F, 0xE36F, 0xC44F, 0xE46F],
            0x4001F: [0xD9D4, 0xF9F4, 0xD8D4, 0xF8F4, 0xDBD4, 0xFBF4, 0xD5D4, 0xF5F4, 0xCFD4, 0xEFF4],
            0x40020: [0xD9D6, 0xF9F6, 0xD8D6, 0xF8F6, 0xDBD6, 0xFBF6, 0xD5D6, 0xF5F6, 0xCFD6, 0xEFF6],
            0x2000E: [0xC145, 0xE165, 0xC045, 0xE065, 0xC545, 0xE565, 0xC345, 0xE365, 0xC445, 0xE465],
            0x00022: [0x00CD, 0x00ED, 0x00CC, 0x00EC, 0x00C6, 0x00E6, 0x00D3, 0x00F3, 0x00D2, 0x00F2],
            0x00010: [0xD959, 0xF979, 0xD859, 0xF879, 0xDB59, 0xFB79, 0xD559, 0xF579, 0x00CE, 0x00EE]
        ],
        [
            0x00000: [0x00C2, 0x00E2, 0x0102, 0x0103, 0x2041, 0x2061, 0x4041, 0x4061, 0x6041, 0x6061, 0x8041, 0x8061, 0xA041, 0xA061],
            0x0001F: [0x00D4, 0x00F4, 0x01A0, 0x01A1, 0x204F, 0x206F, 0x404F, 0x406F, 0x604F, 0x606F, 0x804F, 0x806F, 0xA04F, 0xA06F],
            0x00020: [0x0000, 0x0000, 0x01AF, 0x01B0, 0x2055, 0x2075, 0x4055, 0x4075, 0x6055, 0x6075, 0x8055, 0x8075, 0xA055, 0xA075],
            0x0000E: [0x00CA, 0x00EA, 0x0000, 0x0000, 0x2045, 0x2065, 0x4045, 0x4065, 0x6045, 0x6065, 0x8045, 0x8065, 0xA045, 0xA065],
            0x00002: [0x0110, 0x0111],
            0x20000: [0x20C2, 0x20E2, 0x40C2, 0x40E2, 0x60C2, 0x60E2, 0x80C2, 0x80E2, 0xA0C2, 0xA0E2],
            0x40000: [0x2102, 0x2103, 0x4102, 0x4103, 0x6102, 0x6103, 0x8102, 0x8103, 0xA102, 0xA103],
            0x2001F: [0x20D4, 0x20F4, 0x40D4, 0x40F4, 0x60D4, 0x60F4, 0x80D4, 0x80F4, 0xA0D4, 0xA0F4],
            0x4001F: [0x21A0, 0x21A1, 0x41A0, 0x41A1, 0x61A0, 0x61A1, 0x81A0, 0x81A1, 0xA1A0, 0xA1A1],
            0x40020: [0x21AF, 0x21B0, 0x41AF, 0x41B0, 0x61AF, 0x61B0, 0x81AF, 0x81B0, 0xA1AF, 0xA1B0],
            0x2000E: [0x20CA, 0x20EA, 0x40CA, 0x40EA, 0x60CA, 0x60EA, 0x80CA, 0x80EA, 0xA0CA, 0xA0EA],
            0x00022: [0x2049, 0x2069, 0x4049, 0x4069, 0x6049, 0x6069, 0x8049, 0x8069, 0xA049, 0xA069],
            0x00010: [0x2059, 0x2079, 0x4059, 0x4079, 0x6059, 0x6079, 0x8059, 0x8079, 0xA059, 0xA079]
        ],
        [
            0x00000: [0x00C2, 0x00E2, 0x00C3, 0x00E3, 0xEC41, 0xEC61, 0xCC41, 0xCC61, 0xD241, 0xD261, 0xDE41, 0xDE61, 0xF241, 0xF261],
            0x0001F: [0x00D4, 0x00F4, 0x00D5, 0x00F5, 0xEC4F, 0xEC6F, 0xCC4F, 0xCC6F, 0xD24F, 0xD26F, 0xDE4F, 0xDE6F, 0xF24F, 0xF26F],
            0x00020: [0x0000, 0x0000, 0x00DD, 0x00FD, 0xEC55, 0xEC75, 0xCC55, 0xCC75, 0xD255, 0xD275, 0xDE55, 0xDE75, 0xF255, 0xF275],
            0x0000E: [0x00CA, 0x00EA, 0x0000, 0x0000, 0xEC45, 0xEC65, 0xCC45, 0xCC65, 0xD245, 0xD265, 0xDE45, 0xDE65, 0xF245, 0xF265],
            0x00002: [0x00D0, 0x00F0],
            0x20000: [0xECC2, 0xECE2, 0xCCC2, 0xCCE2, 0xD2C2, 0xD2E2, 0xDEC2, 0xDEE2, 0xF2C2, 0xF2E2],
            0x40000: [0xECC3, 0xECE3, 0xCCC3, 0xCCE3, 0xD2C3, 0xD2E3, 0xDEC3, 0xDEE3, 0xF2C3, 0xF2E3],
            0x2001F: [0xECD4, 0xECF4, 0xCCD4, 0xCCF4, 0xD2D4, 0xD2F4, 0xDED4, 0xDEF4, 0xF2D4, 0xF2F4],
            0x4001F: [0xECD5, 0xECF5, 0xCCD5, 0xCCF5, 0xD2D5, 0xD2F5, 0xDED5, 0xDEF5, 0xF2D5, 0xF2F5],
            0x40020: [0xECDD, 0xECFD, 0xCCDD, 0xCCFD, 0xD2DD, 0xD2FD, 0xDEDD, 0xDEFD, 0xF2DD, 0xF2FD],
            0x2000E: [0xECCA, 0xECEA, 0xCCCA, 0xCCEA, 0xD2CA, 0xD2EA, 0xDECA, 0xDEEA, 0xF2CA, 0xF2EA],
            0x00022: [0xEC49, 0xEC69, 0xCC49, 0xCC69, 0xD249, 0xD269, 0xDE49, 0xDE69, 0xF249, 0xF269],
            0x00010: [0xEC59, 0xEC79, 0xCC59, 0xCC79, 0xD259, 0xD279, 0xDE59, 0xDE79, 0xF259, 0xF279]
        ]
    ]

    private class func clampedCodeTableIndex(_ codeTable: Int32) -> Int {
        let rawIndex = Int(codeTable)
        return codeTableLookup.indices.contains(rawIndex) ? rawIndex : 0
    }

    @objc class func initializeAndGetKeyHookState() {
        phtvEngineInitializeAndGetKeyHookState()
    }

    @objc class func notifyTableCodeChanged() {
        let macros = MacroStorage.load(defaults: .standard)
        let macroData = MacroStorage.engineBinaryData(from: macros)
        PHTVEngineDataBridge.initializeMacroMap(with: macroData)
    }

    class func eventMarkerValue() -> Int64 {
        eventMarker
    }

    class func handleMouseDown() {
        vKeyHandleEvent(keyEventMouse, keyEventStateMouseDown, 0, 0, false)
    }

    class func handleKeyboardKeyDown(
        keyCode: UInt16,
        capsStatus: UInt8,
        hasOtherControlKey: Bool
    ) {
        vKeyHandleEvent(
            keyEventKeyboard,
            keyEventStateKeyDown,
            keyCode,
            capsStatus,
            hasOtherControlKey
        )
    }

    class func handleEnglishModeKeyDown(
        keyCode: UInt16,
        isCaps: Bool,
        hasOtherControlKey: Bool
    ) {
        vEnglishMode(keyEventStateKeyDown, keyCode, isCaps, hasOtherControlKey)
    }

    class func primeUpperCaseFirstChar() {
        vPrimeUpperCaseFirstChar()
    }

    class func restoreToRawKeys() -> Bool {
        vRestoreToRawKeys()
    }

    class func tempOffSpellChecking() {
        vTempOffSpellChecking()
    }

    class func tempOffEngineNow() {
        vTempOffEngine(true)
    }

    class func barrier() {
        phtvRuntimeBarrier()
    }

    class func safeModeEnabled() -> Bool {
        phtvRuntimeSafeMode()
    }

    class func rememberCode() -> Int32 {
        Int32(phtvRuntimeRememberCode())
    }

    class func setRememberCode(_ value: Int32) {
        phtvRuntimeSetRememberCode(value)
    }

    class func currentLanguage() -> Int32 {
        Int32(phtvRuntimeCurrentLanguage())
    }

    class func setCurrentLanguage(_ language: Int32) {
        phtvRuntimeSetCurrentLanguage(language)
    }

    class func otherLanguageMode() -> Int32 {
        Int32(phtvRuntimeOtherLanguage())
    }

    class func setOtherLanguageMode(_ value: Int32) {
        phtvRuntimeSetOtherLanguage(value)
    }

    class func currentInputType() -> Int32 {
        Int32(phtvRuntimeCurrentInputType())
    }

    class func setCurrentInputType(_ inputType: Int32) {
        phtvRuntimeSetCurrentInputType(inputType)
    }

    class func currentCodeTable() -> Int32 {
        Int32(phtvRuntimeCurrentCodeTable())
    }

    class func setCurrentCodeTable(_ codeTable: Int32) {
        phtvRuntimeSetCurrentCodeTable(codeTable)
    }

    class func isDoubleCode(_ codeTable: Int32) -> Bool {
        codeTable == 2 || codeTable == 3
    }

    class func isSmartSwitchKeyEnabled() -> Bool {
        phtvRuntimeIsSmartSwitchKeyEnabled()
    }

    class func setSmartSwitchKeyEnabled(_ enabled: Bool) {
        phtvRuntimeSetUseSmartSwitchKey(enabled)
    }

    class func isSendKeyStepByStepEnabled() -> Bool {
        phtvRuntimeIsSendKeyStepByStepEnabled()
    }

    class func setSendKeyStepByStepEnabled(_ enabled: Bool) {
        phtvRuntimeSetSendKeyStepByStepEnabled(enabled)
    }

    class func setUpperCaseExcludedForCurrentApp(_ excluded: Bool) {
        phtvRuntimeSetUpperCaseExcludedForCurrentApp(excluded)
    }

    class func switchKeyStatus() -> Int32 {
        Int32(phtvRuntimeSwitchKeyStatus())
    }

    class func setSwitchKeyStatus(_ status: Int32) {
        phtvRuntimeSetSwitchKeyStatus(status)
    }

    class func setShowIconOnDock(_ visible: Bool) {
        phtvRuntimeSetShowIconOnDock(visible)
    }

    class func showIconOnDock() -> Int32 {
        Int32(phtvRuntimeShowIconOnDock())
    }

    class func upperCaseFirstChar() -> Int32 {
        Int32(phtvRuntimeUpperCaseFirstChar())
    }

    class func setUpperCaseFirstChar(_ value: Int32) {
        phtvRuntimeSetUpperCaseFirstChar(value)
    }

    class func upperCaseExcludedForCurrentApp() -> Int32 {
        Int32(phtvRuntimeUpperCaseExcludedForCurrentApp())
    }

    class func checkSpelling() -> Int32 {
        Int32(phtvRuntimeCheckSpelling())
    }

    class func setCheckSpelling(_ value: Int32) {
        phtvRuntimeSetCheckSpelling(value)
    }

    class func applyCheckSpelling() {
        vSetCheckSpelling()
    }

    class func useModernOrthography() -> Int32 {
        Int32(phtvRuntimeUseModernOrthography())
    }

    class func setUseModernOrthography(_ value: Int32) {
        phtvRuntimeSetUseModernOrthography(value)
    }

    class func quickTelex() -> Int32 {
        Int32(phtvRuntimeQuickTelex())
    }

    class func setQuickTelex(_ value: Int32) {
        phtvRuntimeSetQuickTelex(value)
    }

    class func freeMark() -> Int32 {
        Int32(phtvRuntimeFreeMark())
    }

    class func setFreeMark(_ value: Int32) {
        phtvRuntimeSetFreeMark(value)
    }

    class func useMacro() -> Int32 {
        Int32(phtvRuntimeUseMacro())
    }

    class func setUseMacro(_ value: Int32) {
        phtvRuntimeSetUseMacro(value)
    }

    class func useMacroInEnglishMode() -> Int32 {
        Int32(phtvRuntimeUseMacroInEnglishMode())
    }

    class func setUseMacroInEnglishMode(_ value: Int32) {
        phtvRuntimeSetUseMacroInEnglishMode(value)
    }

    class func autoCapsMacro() -> Int32 {
        Int32(phtvRuntimeAutoCapsMacro())
    }

    class func setAutoCapsMacro(_ value: Int32) {
        phtvRuntimeSetAutoCapsMacro(value)
    }

    class func allowConsonantZFWJ() -> Int32 {
        Int32(phtvRuntimeAllowConsonantZFWJ())
    }

    class func setAllowConsonantZFWJ(_ value: Int32) {
        phtvRuntimeSetAllowConsonantZFWJ(value)
    }

    class func quickStartConsonant() -> Int32 {
        Int32(phtvRuntimeQuickStartConsonant())
    }

    class func setQuickStartConsonant(_ value: Int32) {
        phtvRuntimeSetQuickStartConsonant(value)
    }

    class func quickEndConsonant() -> Int32 {
        Int32(phtvRuntimeQuickEndConsonant())
    }

    class func setQuickEndConsonant(_ value: Int32) {
        phtvRuntimeSetQuickEndConsonant(value)
    }

    class func performLayoutCompat() -> Int32 {
        Int32(phtvRuntimePerformLayoutCompat())
    }

    class func setPerformLayoutCompat(_ value: Int32) {
        phtvRuntimeSetPerformLayoutCompat(value)
    }

    class func restoreOnEscape() -> Int32 {
        Int32(phtvRuntimeRestoreOnEscape())
    }

    class func setRestoreOnEscape(_ value: Int32) {
        phtvRuntimeSetRestoreOnEscape(value)
    }

    class func customEscapeKey() -> Int32 {
        Int32(phtvRuntimeCustomEscapeKey())
    }

    class func setCustomEscapeKey(_ value: Int32) {
        phtvRuntimeSetCustomEscapeKey(value)
    }

    class func pauseKeyEnabled() -> Int32 {
        Int32(phtvRuntimePauseKeyEnabled())
    }

    class func setPauseKeyEnabled(_ value: Int32) {
        phtvRuntimeSetPauseKeyEnabled(value)
    }

    class func pauseKey() -> Int32 {
        Int32(phtvRuntimePauseKey())
    }

    class func setPauseKey(_ value: Int32) {
        phtvRuntimeSetPauseKey(value)
    }

    class func autoRestoreEnglishWord() -> Int32 {
        Int32(phtvRuntimeAutoRestoreEnglishWord())
    }

    class func setAutoRestoreEnglishWord(_ value: Int32) {
        phtvRuntimeSetAutoRestoreEnglishWord(value)
    }

    class func enableEmojiHotkey() -> Int32 {
        Int32(phtvRuntimeEnableEmojiHotkey())
    }

    class func emojiHotkeyModifiers() -> Int32 {
        Int32(phtvRuntimeEmojiHotkeyModifiers())
    }

    class func emojiHotkeyKeyCode() -> Int32 {
        Int32(phtvRuntimeEmojiHotkeyKeyCode())
    }

    class func setEmojiHotkeySettings(_ enabled: Int32, _ modifiers: Int32, _ keyCode: Int32) {
        phtvRuntimeSetEmojiHotkeySettings(enabled, modifiers, keyCode)
    }

    class func defaultSwitchHotkeyStatus() -> Int32 {
        Int32(Defaults.defaultSwitchKeyStatus)
    }

    class func defaultPauseKey() -> Int32 {
        Int32(KeyCode.leftOption)
    }

    class func setFixRecommendBrowser(_ value: Int32) {
        phtvRuntimeSetFixRecommendBrowser(value)
    }

    class func setTempOffSpelling(_ value: Int32) {
        phtvRuntimeSetTempOffSpelling(value)
    }

    class func setTempOffEngine(_ value: Int32) {
        phtvRuntimeSetTempOffPHTV(value)
    }

    class func setSafeMode(_ enabled: Bool) {
        phtvRuntimeSetSafeMode(enabled)
    }

    class func tempOffSpelling() -> Int32 {
        Int32(phtvRuntimeTempOffSpelling())
    }

    class func tempOffEngine() -> Int32 {
        Int32(phtvRuntimeTempOffPHTV())
    }

    class func fixRecommendBrowser() -> Int32 {
        Int32(phtvRuntimeFixRecommendBrowser())
    }

    class func startNewSession() {
        phtvCallStartNewSession()
    }

    class func initializeMacroMap(_ data: UnsafePointer<UInt8>?, _ count: Int32) {
        initMacroMap(data, count)
    }

    class func initializeEnglishDictionary(_ path: UnsafePointer<CChar>) -> Bool {
        if path[0] == 0 {
            return false
        }
        let cppPath = std.string(path)
        return initEnglishDictionary(cppPath)
    }

    class func englishDictionarySize() -> Int32 {
        Int32(getEnglishDictionarySize())
    }

    class func initializeVietnameseDictionary(_ path: UnsafePointer<CChar>) -> Bool {
        if path[0] == 0 {
            return false
        }
        let cppPath = std.string(path)
        return initVietnameseDictionary(cppPath)
    }

    class func vietnameseDictionarySize() -> Int32 {
        Int32(getVietnameseDictionarySize())
    }

    class func initializeCustomDictionary(_ data: UnsafePointer<CChar>?, _ count: Int32) {
        initCustomDictionary(data, count)
    }

    class func customEnglishWordCount() -> Int32 {
        Int32(getCustomEnglishWordCount())
    }

    class func customVietnameseWordCount() -> Int32 {
        Int32(getCustomVietnameseWordCount())
    }

    class func clearCustomDictionary() {
        phtvCallClearCustomDictionary()
    }

    class func hotkeyDisplayCharacter(_ keyCode: UInt16) -> UInt16 {
        macroKeyCodeToCharacter(UInt32(keyCode) | capsMask())
    }

    class func findCodeTableSourceKey(
        codeTable: Int32,
        character: UInt16
    ) -> (keyCode: UInt32, variantIndex: Int32)? {
        let table = codeTableLookup[clampedCodeTableIndex(codeTable)]
        for keyCode in table.keys.sorted() {
            guard let variants = table[keyCode],
                  let variantIndex = variants.firstIndex(of: character) else {
                continue
            }
            return (keyCode, Int32(variantIndex))
        }
        return nil
    }

    class func codeTableVariantCount(
        codeTable: Int32,
        keyCode: UInt32
    ) -> Int32 {
        let table = codeTableLookup[clampedCodeTableIndex(codeTable)]
        return Int32(table[keyCode]?.count ?? 0)
    }

    class func codeTableCharacterForKey(
        codeTable: Int32,
        keyCode: UInt32,
        variantIndex: Int32
    ) -> UInt16? {
        guard variantIndex >= 0 else {
            return nil
        }
        let table = codeTableLookup[clampedCodeTableIndex(codeTable)]
        guard let variants = table[keyCode],
              Int(variantIndex) < variants.count else {
            return nil
        }
        return variants[Int(variantIndex)]
    }

    class func capsMask() -> UInt32 {
        engineCapsMask
    }

    class func charCodeMask() -> UInt32 {
        engineCharCodeMask
    }

    class func pureCharacterMask() -> UInt32 {
        enginePureCharacterMask
    }

    class func macroKeyCodeToCharacter(_ keyData: UInt32) -> UInt16 {
        let allowedMask = UInt32(KeyCode.keyMask) | engineCapsMask
        guard (keyData & ~allowedMask) == 0 else {
            return 0
        }

        let keyCode = UInt16(truncatingIfNeeded: keyData & UInt32(KeyCode.keyMask))
        if (keyData & engineCapsMask) != 0 {
            return macroKeyToCharacterShifted[keyCode] ?? 0
        }
        return macroKeyToCharacterUnshifted[keyCode] ?? 0
    }

    class func keyDeleteCode() -> Int32 {
        Int32(KeyCode.delete)
    }

    class func keySlashCode() -> Int32 {
        Int32(KeyCode.slash)
    }

    class func keyEnterCode() -> Int32 {
        Int32(KeyCode.enter)
    }

    class func keyReturnCode() -> Int32 {
        Int32(KeyCode.returnKey)
    }

    class func spaceKeyCode() -> Int32 {
        Int32(KeyCode.space)
    }

    class func engineDoNothingCode() -> Int32 {
        engineDoNothingCodeValue
    }

    class func engineWillProcessCode() -> Int32 {
        engineWillProcessCodeValue
    }

    class func engineReplaceMacroCode() -> Int32 {
        engineReplaceMacroCodeValue
    }

    class func engineRestoreCode() -> Int32 {
        engineRestoreCodeValue
    }

    class func engineRestoreAndStartNewSessionCode() -> Int32 {
        engineRestoreAndStartNewSessionCodeValue
    }

    class func engineMaxBuffer() -> Int32 {
        engineMaxBufferValue
    }

    class func engineDataCode() -> Int32 {
        Int32(phtvEngineDataCode())
    }

    class func engineDataExtCode() -> Int32 {
        Int32(phtvEngineDataExtCode())
    }

    class func engineDataBackspaceCount() -> Int32 {
        Int32(phtvEngineDataBackspaceCount())
    }

    class func setEngineDataBackspaceCount(_ count: UInt8) {
        phtvEngineDataSetBackspaceCount(count)
    }

    class func engineDataNewCharCount() -> Int32 {
        Int32(phtvEngineDataNewCharCount())
    }

    class func engineDataCharAt(_ index: Int32) -> UInt32 {
        UInt32(phtvEngineDataCharAt(index))
    }

    class func engineDataMacroDataSize() -> Int32 {
        Int32(phtvEngineDataMacroDataSize())
    }

    class func engineDataMacroDataAt(_ index: Int32) -> UInt32 {
        UInt32(phtvEngineDataMacroDataAt(index))
    }

    class func lowByte(_ value: UInt32) -> UInt16 {
        UInt16(truncatingIfNeeded: value & 0x00FF)
    }

    class func hiByte(_ value: UInt32) -> UInt16 {
        UInt16(truncatingIfNeeded: (value >> 8) & 0x00FF)
    }

    class func unicodeCompoundMarkAt(_ index: Int32) -> UInt16 {
        let safeIndex = Int(index)
        guard unicodeCompoundMarks.indices.contains(safeIndex) else {
            return 0
        }
        return unicodeCompoundMarks[safeIndex]
    }

    class func isNavigationKey(_ keyCode: UInt16) -> Bool {
        navigationKeyCodes.contains(keyCode)
    }
}
