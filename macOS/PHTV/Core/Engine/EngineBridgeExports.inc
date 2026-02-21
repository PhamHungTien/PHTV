extern "C" void phtvEngineHandleEvent(int event, int state, uint16_t data, uint8_t capsStatus, int otherControlKey) {
    vKeyHandleEvent(
        static_cast<vKeyEvent>(event),
        static_cast<vKeyEventState>(state),
        static_cast<Uint16>(data),
        static_cast<Uint8>(capsStatus),
        otherControlKey != 0
    );
}

extern "C" void phtvEngineHandleEnglishMode(int state, uint16_t data, int isCaps, int otherControlKey) {
    vEnglishMode(
        static_cast<vKeyEventState>(state),
        static_cast<Uint16>(data),
        isCaps != 0,
        otherControlKey != 0
    );
}

extern "C" void phtvEnginePrimeUpperCaseFirstChar(void) {
    vPrimeUpperCaseFirstChar();
}

extern "C" int phtvEngineRestoreToRawKeys(void) {
    return vRestoreToRawKeys() ? 1 : 0;
}

extern "C" void phtvEngineTempOffSpellChecking(void) {
    vTempOffSpellChecking();
}

extern "C" void phtvEngineTempOff(int off) {
    vTempOffEngine(off != 0);
}

extern "C" void phtvEngineSetCheckSpelling(void) {
    vSetCheckSpelling();
}

extern "C" void phtvEngineStartNewSession(void) {
    startNewSession();
}

extern "C" void phtvEngineInitialize(void) {
    (void)vKeyInit();
}

extern "C" int phtvEngineHookCode(void) {
    return static_cast<int>(HookState.code);
}

extern "C" int phtvEngineHookExtCode(void) {
    return static_cast<int>(HookState.extCode);
}

extern "C" int phtvEngineHookBackspaceCount(void) {
    return static_cast<int>(HookState.backspaceCount);
}

extern "C" void phtvEngineHookSetBackspaceCount(uint8_t count) {
    HookState.backspaceCount = static_cast<Byte>(count);
}

extern "C" int phtvEngineHookNewCharCount(void) {
    return static_cast<int>(HookState.newCharCount);
}

extern "C" uint32_t phtvEngineHookCharAt(int index) {
    if (index < 0 || index >= MAX_BUFF) {
        return 0;
    }
    return static_cast<uint32_t>(HookState.charData[index]);
}

extern "C" int phtvEngineHookMacroDataSize(void) {
    return static_cast<int>(HookState.macroData.size());
}

extern "C" uint32_t phtvEngineHookMacroDataAt(int index) {
    if (index < 0 || static_cast<size_t>(index) >= HookState.macroData.size()) {
        return 0;
    }
    return static_cast<uint32_t>(HookState.macroData[static_cast<size_t>(index)]);
}
