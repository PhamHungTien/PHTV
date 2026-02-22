        || otherControlKey || isAutoRestoreBreakKey || (_index == 0 && IS_NUMBER_KEY(data))) {
        hCode = vDoNothing;
        hBPC = 0;
        hNCC = 0;
        hExt = 1; //word break
        
        //check macro feature
        if (phtvRuntimeUseMacroEnabled() && isMacroBreakCode(data) && !_hasHandledMacro && findMacro(hMacroKey, hMacroData)) {
            hCode = vReplaceMaro;
            hBPC = (Byte)hMacroKey.size();
            _hasHandledMacro = true;
            #ifdef DEBUG
            fprintf(stderr, "[AutoEnglish] CONFLICT: Macro matched, auto English skipped\n"); fflush(stderr);
            #endif
        } else if (phtvRuntimeAutoRestoreEnglishWordEnabled() && isAutoRestoreBreakKey) {
            // PRIORITY FIX: Check Auto English BEFORE Quick Consonant
            // Auto English should have higher priority to prevent conflicts
            // (e.g., "search." ending in "ch" shouldn't trigger Quick Consonant)
            #ifdef DEBUG
            const char* eventType = (event == vKeyEvent::Mouse) ? "Mouse" : "Keyboard";
            const char* stateType = (state == KeyDown) ? "KeyDown" : (state == KeyUp) ? "KeyUp" : (state == MouseDown) ? "MouseDown" : "MouseUp";
            fprintf(stderr, "[AutoEnglish] WORD BREAK detected: event=%s, state=%s, _stateIndex=%d, _index=%d, data=0x%X\n",
                   eventType, stateType, _stateIndex, _index, data);
            fflush(stderr);
            #endif
            if (isSpellCheckingEnabled()) {
                checkSpelling(true);
            }
            bool shouldRestoreEnglish = false;
            int englishStateIndex = getEnglishLookupStateLength();
            bool isPureLetterToken = (englishStateIndex == _stateIndex) &&
                                     hasOnlyEnglishLetterKeyStates(_stateIndex);
            bool isLetterWithNumericSuffixToken =
                (englishStateIndex > 0 && englishStateIndex < _stateIndex) &&
                hasOnlyEnglishLetterKeyStates(englishStateIndex) &&
                hasOnlyTrailingDigitKeyStates(englishStateIndex);
            bool canAutoRestoreToken = isPureLetterToken || isLetterWithNumericSuffixToken;
            int restoreStateIndex = isLetterWithNumericSuffixToken ? _stateIndex : englishStateIndex;

            if (englishStateIndex > 1 && canAutoRestoreToken) {
                shouldRestoreEnglish = detectorShouldRestoreEnglishWord(KeyStates, englishStateIndex);
                if (!shouldRestoreEnglish) {
                    if (detectorIsEnglishWordFromKeyStates(KeyStates, englishStateIndex) &&
                        !detectorIsVietnameseWordFromKeyStates(KeyStates, englishStateIndex) &&
                        !isVietnameseWordFromTypingWord(_index)) {
                        shouldRestoreEnglish = true;
                    }
                }

                // PROTECTION: Single-character Vietnamese words should never be restored
                // (Same protection as SPACE handler - see detailed comment there)
                if (shouldRestoreEnglish && _index == 1) {
                    if (TypingWord[0] & (MARK_MASK | TONE_MASK | TONEW_MASK | STANDALONE_MASK)) {
                        shouldRestoreEnglish = false;
                        #ifdef DEBUG
                        fprintf(stderr, "[AutoEnglish] SKIP RESTORE WORDBREAK: Single Vietnamese char (has marks)\n");
                        fflush(stderr);
                        #endif
                    }
                }

                // CANONICAL TELEX CHECK (word break path)
                // (Same logic as SPACE handler - see detailed comment there)
                if (shouldRestoreEnglish) {
                    bool hasVietnameseMarks = false;
                    for (int k = 0; k < _index; k++) {
                        if (TypingWord[k] & (MARK_MASK | TONE_MASK | TONEW_MASK | STANDALONE_MASK)) {
                            hasVietnameseMarks = true;
                            break;
                        }
                    }
                    if (hasVietnameseMarks && isVietnameseFromCanonicalTelex(_index)) {
                        shouldRestoreEnglish = false;
                        #ifdef DEBUG
                        fprintf(stderr, "[AutoEnglish] SKIP RESTORE WORDBREAK: Canonical Telex is Vietnamese\n");
                        fflush(stderr);
                        #endif
                    }
                }

                // Fix for "macoss" -> "macos": If user corrected the word manually (e.g. typing 's' to remove tone),
                // producing a clean English word in TypingWord, do not restore the raw keys (which might be "macoss").
                if (shouldRestoreEnglish) {
                    bool isTypingWordPureEnglish = true;
                    for (int k = 0; k < _index; k++) {
                        if (TypingWord[k] & (MARK_MASK | TONE_MASK | TONEW_MASK | STANDALONE_MASK)) {
                            isTypingWordPureEnglish = false;
                            break;
                        }
                    }
                    if (isTypingWordPureEnglish && detectorIsEnglishWordFromKeyStates(TypingWord, _index)) {
                        shouldRestoreEnglish = false;
                        #ifdef DEBUG
                        fprintf(stderr, "[AutoEnglish] SKIP RESTORE: TypingWord is already clean English\n");
                        fflush(stderr);
                        #endif
                    }
                }

                // Mixed tokens like "power1" should restore only when Vietnamese transform happened
                // (e.g. "pơer1" -> "power1"), avoid no-op restore for plain "int1234".
                if (shouldRestoreEnglish && isLetterWithNumericSuffixToken &&
                    !hasVietnameseTransformsInTypingWord(_index)) {
                    shouldRestoreEnglish = false;
                    #ifdef DEBUG
                    fprintf(stderr, "[AutoEnglish] SKIP RESTORE WORDBREAK: no Vietnamese transform in mixed token\n");
                    fflush(stderr);
                    #endif
                }
            }
            // IMPORTANT: Check _index > 0 (must have display chars) and englishStateIndex > 1 (at least 2 keys pressed)
            if (_index > 0 && restoreStateIndex > 1 && canAutoRestoreToken && shouldRestoreEnglish) {
                // Auto restore English word feature
                // checkIfEnglishWord returns true only if:
                // - Word exists in English dictionary AND
                // - Word does NOT exist in Vietnamese dictionary
                hCode = vRestoreAndStartNewSession;
                // SPACE FIX (WORD BREAK path): Use _index for backspace count
                // When Vietnamese processing combines chars (e.g., "search" → "sẻach"),
                // _stateIndex=6 but _index=5, so we must delete based on display count
                // to avoid deleting characters before the word
                hBPC = _index;  // Backspace count = display character count
                hNCC = restoreStateIndex;  // Insert count = original keystroke count (restore full mixed token if needed)
                hExt = 5;  // Signal: This is Auto English restore (not Text Replacement)
                for (i = 0; i < restoreStateIndex; i++) {
                    TypingWord[i] = KeyStates[i];
                    hData[restoreStateIndex - 1 - i] = KeyStates[i];
                }
                // Apply uppercase first character if enabled
                // Use _shouldUpperCaseEnglishRestore which was set when first char was typed
                // Also check if current app is NOT excluded from uppercase feature
                if (_snapshotUpperCaseFirstChar && !phtvRuntimeUpperCaseExcludedForCurrentApp() && _shouldUpperCaseEnglishRestore && restoreStateIndex > 0) {
                    hData[restoreStateIndex - 1] |= CAPS_MASK;
                }
                _shouldUpperCaseEnglishRestore = false;
                _index = restoreStateIndex;
                // CRITICAL FIX: Reset session immediately to prevent state pollution
                // Without this, when typing fast or multiple words, _index/_stateIndex retain old values
                // causing intermittent failures ("sometimes works, sometimes doesn't")
                // This matches SPACE handler behavior (line 1573-1574)
                _index = 0;
                _stateIndex = 0;
                #ifdef DEBUG
                fprintf(stderr, "[AutoEnglish] ✓ WORD BREAK RESTORE: reset to _index=0, _stateIndex=0\n");
                fflush(stderr);
                #endif
            #ifdef DEBUG
            } else if (_stateIndex > 0) {
                std::string word = detectorKeyStatesToString(KeyStates, englishStateIndex);
                fprintf(stderr, "[AutoEnglish] ✗ WORD BREAK NO RESTORE: word='%s', _index=%d, _stateIndex=%d, blocked by: ",
                       word.c_str(), _index, _stateIndex);
                if (_index <= 0) fprintf(stderr, "_index<=0 ");
                if (englishStateIndex <= 1) fprintf(stderr, "englishStateIndex<=1 ");
                if (!canAutoRestoreToken) fprintf(stderr, "invalidTokenShape ");
                if (!detectorShouldRestoreEnglishWord(KeyStates, englishStateIndex)) fprintf(stderr, "notEnglish ");
                fprintf(stderr, "\n");
                fflush(stderr);
            #endif
            }
        } else if ((phtvRuntimeQuickStartConsonantEnabled() || phtvRuntimeQuickEndConsonantEnabled()) && !tempDisableKey && isMacroBreakCode(data)) {
            // Quick Consonant for Vietnamese typing shortcuts
            // Now checked AFTER Auto English to avoid conflicts
            checkQuickConsonant();
        } else if (isAutoRestoreBreakKey) { //restore raw keys if word is invalid Vietnamese
            if (!tempDisableKey && isSpellCheckingEnabled()) {
                checkSpelling(true); //force check spelling before restore decision
            }
            if (tempDisableKey && !checkRestoreIfWrongSpelling(vRestoreAndStartNewSession)) {
                hCode = vDoNothing;
            }
        }
        
#include "EngineKeyHandleEventWordBreakPost.inc"
