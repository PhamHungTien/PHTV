// PHTVEngineBridgeExports.swift
// PHTV
//
// @_cdecl exports providing the phtvEngine* C-callable interface.
// Created by Phạm Hùng Tiến on 2026.

// MARK: - Engine event type constants (ported from PHTVEngineCBridge.inc)
let PHTV_ENGINE_EVENT_KEYBOARD: Int32          = 0
let PHTV_ENGINE_EVENT_MOUSE: Int32             = 1
let PHTV_ENGINE_EVENT_STATE_KEY_DOWN: Int32    = 0
let PHTV_ENGINE_EVENT_STATE_KEY_UP: Int32      = 1
let PHTV_ENGINE_EVENT_STATE_MOUSE_DOWN: Int32  = 2
let PHTV_ENGINE_EVENT_STATE_MOUSE_UP: Int32    = 3

@_cdecl("phtvEngineHandleEvent")
func phtvEngineHandleEvent(_ event: Int32, _ state: Int32, _ data: UInt16, _ capsStatus: UInt8, _ otherControlKey: Int32) {
    engineHandleEvent(event, state, data, capsStatus, otherControlKey)
}

@_cdecl("phtvEngineHandleEnglishMode")
func phtvEngineHandleEnglishMode(_ state: Int32, _ data: UInt16, _ isCaps: Int32, _ otherControlKey: Int32) {
    engineHandleEnglishMode(state, data, isCaps, otherControlKey)
}

@_cdecl("phtvEnginePrimeUpperCaseFirstChar")
func phtvEnginePrimeUpperCaseFirstChar() {
    enginePrimeUpperCaseFirstChar()
}

@_cdecl("phtvEngineRestoreToRawKeys")
func phtvEngineRestoreToRawKeys() -> Int32 {
    engineRestoreToRawKeys()
}

@_cdecl("phtvEngineTempOffSpellChecking")
func phtvEngineTempOffSpellChecking() {
    engineTempOffSpellChecking()
}

@_cdecl("phtvEngineTempOff")
func phtvEngineTempOff(_ off: Int32) {
    engineTempOff(off)
}

@_cdecl("phtvEngineSetCheckSpelling")
func phtvEngineSetCheckSpelling() {
    engineSetCheckSpelling()
}

@_cdecl("phtvEngineStartNewSession")
func phtvEngineStartNewSession() {
    engineStartNewSession()
}

@_cdecl("phtvEngineInitialize")
func phtvEngineInitialize() {
    engineInitialize()
}

@_cdecl("phtvEngineHookCode")
func phtvEngineHookCode() -> Int32 {
    engineHookCode()
}

@_cdecl("phtvEngineHookExtCode")
func phtvEngineHookExtCode() -> Int32 {
    engineHookExtCode()
}

@_cdecl("phtvEngineHookBackspaceCount")
func phtvEngineHookBackspaceCount() -> Int32 {
    engineHookBackspaceCount()
}

@_cdecl("phtvEngineHookSetBackspaceCount")
func phtvEngineHookSetBackspaceCount(_ count: UInt8) {
    engineHookSetBackspaceCount(count)
}

@_cdecl("phtvEngineHookNewCharCount")
func phtvEngineHookNewCharCount() -> Int32 {
    engineHookNewCharCount()
}

@_cdecl("phtvEngineHookCharAt")
func phtvEngineHookCharAt(_ index: Int32) -> UInt32 {
    engineHookCharAt(index)
}

@_cdecl("phtvEngineHookMacroDataSize")
func phtvEngineHookMacroDataSize() -> Int32 {
    engineHookMacroDataSize()
}

@_cdecl("phtvEngineHookMacroDataAt")
func phtvEngineHookMacroDataAt(_ index: Int32) -> UInt32 {
    engineHookMacroDataAt(index)
}
