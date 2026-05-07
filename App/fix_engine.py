import sys

def main():
    with open('/Users/phamhungtien/Documents/PHTV/App/PHTV/Engine/PHTVEngineCore.swift', 'r') as f:
        content = f.read()

    # 1. Update evaluateAutoRestoreEnglishDecision signature and logic
    old_eval = """    func evaluateAutoRestoreEnglishDecision() -> (restoreStateIndex: Int, canAutoRestore: Bool, shouldRestore: Bool) {"""
    new_eval = """    func evaluateAutoRestoreEnglishDecision() -> (restoreStateIndex: Int, canAutoRestore: Bool, shouldRestore: Bool, customRestoreSlice: [UInt32]?) {"""
    content = content.replace(old_eval, new_eval)

    # In evaluateAutoRestoreEnglishDecision, right before `return (restoreStateIndex, canAutoRestore, shouldRestoreEnglish)`:
    old_ret_eval = """        return (restoreStateIndex, canAutoRestore, shouldRestoreEnglish)
    }"""
    
    new_ret_eval = """        if shouldRestoreEnglish {
            return (restoreStateIndex, canAutoRestore, true, nil)
        }

        // PR 177: check for custom deduped/english words only if we haven't already decided to restore,
        // and only if the current sequence is NOT a valid Vietnamese word.
        if !hasVietnameseDictionaryMatch && !isVietnameseWordFromTypingWord(idx) {
            if let dedupedSlice = shouldRestoreTelexAdjacentDedupRawKeys() {
                return (dedupedSlice.count, true, true, dedupedSlice)
            }
            if shouldRestoreTelexLeadingDoubleConsonantRawKeys() {
                let leadingCaps = (typingWord[0] & CAPS_MASK) != 0 || (keyStates[0] & CAPS_MASK) != 0
                var deduped = Array(keyStates.dropFirst().prefix(englishStateIndex - 1))
                if leadingCaps && !deduped.isEmpty { deduped[0] |= CAPS_MASK }
                return (deduped.count, true, true, deduped)
            }
            if shouldRestoreSimpleTelexEnglishDoubleVowelRawKeys() {
                return (englishStateIndex, true, true, nil)
            }
        }

        return (restoreStateIndex, canAutoRestore, false, nil)
    }"""
    content = content.replace(old_ret_eval, new_ret_eval)

    # 2. Update handleWordBreak
    old_word_break = """            let decision = evaluateAutoRestoreEnglishDecision()
            if idx > 0 && decision.restoreStateIndex > 1 && decision.canAutoRestore && decision.shouldRestore {
                hCode = HookCodeState.restoreAndStartNewSession.rawValue
                hBPC = idx; hNCC = decision.restoreStateIndex; hExt = 5
                for i in 0..<decision.restoreStateIndex {
                    typingWord[i] = keyStates[i]
                    hData[decision.restoreStateIndex - 1 - i] = keyStates[i]
                }"""
    
    new_word_break = """            let decision = evaluateAutoRestoreEnglishDecision()
            if idx > 0 && decision.restoreStateIndex > 1 && decision.canAutoRestore && decision.shouldRestore {
                hCode = HookCodeState.restoreAndStartNewSession.rawValue
                hBPC = idx; hNCC = decision.restoreStateIndex; hExt = 5
                for i in 0..<decision.restoreStateIndex {
                    let rawKey = decision.customRestoreSlice?[i] ?? keyStates[i]
                    typingWord[i] = rawKey
                    hData[decision.restoreStateIndex - 1 - i] = rawKey
                }"""
    content = content.replace(old_word_break, new_word_break)

    # 3. Update handleSpace
    old_space = """            let decision = evaluateAutoRestoreEnglishDecision()
            if decision.restoreStateIndex > 1 && decision.canAutoRestore && decision.shouldRestore {
                hCode = HookCodeState.restore.rawValue
                hBPC = idx; hNCC = decision.restoreStateIndex; hExt = 5
                for i in 0..<decision.restoreStateIndex {
                    typingWord[i] = keyStates[i]
                    hData[decision.restoreStateIndex - 1 - i] = keyStates[i]
                }"""
    
    new_space = """            let decision = evaluateAutoRestoreEnglishDecision()
            if decision.restoreStateIndex > 1 && decision.canAutoRestore && decision.shouldRestore {
                hCode = HookCodeState.restore.rawValue
                hBPC = idx; hNCC = decision.restoreStateIndex; hExt = 5
                for i in 0..<decision.restoreStateIndex {
                    let rawKey = decision.customRestoreSlice?[i] ?? keyStates[i]
                    typingWord[i] = rawKey
                    hData[decision.restoreStateIndex - 1 - i] = rawKey
                }"""
    content = content.replace(old_space, new_space)

    # 4. Remove PR 177 logic from handleMainFlow
    old_main_flow = """        if shouldRestoreSimpleTelexEnglishDoubleVowelRawKeys(), restoreToRawKeys() {
            hCode = HookCodeState.willProcess.rawValue
            if phtvRuntimeUseMacroEnabled() != 0 {
                hMacroKey = Array(keyStates.prefix(stateIdx))
                hMacroRawKey = hMacroKey
            }
        }

        if shouldRestoreTelexLeadingDoubleConsonantRawKeys(), restoreToRawKeysSkippingFirstDuplicate() {
            hCode = HookCodeState.willProcess.rawValue
            if phtvRuntimeUseMacroEnabled() != 0 {
                let dedup = Array(keyStates.dropFirst().prefix(stateIdx - 1))
                hMacroKey = dedup
                hMacroRawKey = dedup
            }
        }

        if let dedupedSlice = shouldRestoreTelexAdjacentDedupRawKeys(),
           restoreToCustomKeySlice(dedupedSlice) {
            hCode = HookCodeState.willProcess.rawValue
            if phtvRuntimeUseMacroEnabled() != 0 {
                hMacroKey = dedupedSlice
                hMacroRawKey = dedupedSlice
            }
        }"""
    content = content.replace(old_main_flow, "")

    with open('/Users/phamhungtien/Documents/PHTV/App/PHTV/Engine/PHTVEngineCore.swift', 'w') as f:
        f.write(content)

    print("Patched PHTVEngineCore.swift")

if __name__ == "__main__":
    main()
