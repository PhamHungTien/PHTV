void vKeyHandleEvent(const vKeyEvent& event,
                     const vKeyEventState& state,
                     const Uint16& data,
                     const Uint8& capsStatus,
                     const bool& otherControlKey) {
    refreshRuntimeLayoutSnapshot();

    // PERFORMANCE: Debug logging only in debug builds (hot path - called on every keystroke)
    #ifdef DEBUG
    static int lastInputType = -1;
    if (runtimeInputTypeSnapshot != lastInputType) {
        printf("[Engine] vInputType CHANGED TO %d (was %d)\n", runtimeInputTypeSnapshot, lastInputType);
        fflush(stdout);
        lastInputType = runtimeInputTypeSnapshot;
    }
    #endif

    // NEW FEATURE: Restore key - ESC only
    // Note: Modifier keys (Option, Control) are handled in PHTV.mm via kCGEventFlagsChanged
    // We ONLY handle ESC key here to avoid conflicts with typing (e.g. VNI number keys)
    if (phtvRuntimeRestoreOnEscapeEnabled() && _index > 0 && data == KEY_ESC) {
        if (restoreToRawKeys()) {
            // Successfully restored - let the engine handle vRestore code
            // Don't call startNewSession() here as it will clear hCode
            // The vRestore code will be processed and session will be cleared later
            return;
        }
    }

    _isCaps = (capsStatus == 1 || //shift
               capsStatus == 2); //caps lock
    const bool isAutoRestoreBreakKey = isAutoRestoreWordBreak(event, state, data, capsStatus);
    if ((IS_NUMBER_KEY(data) && capsStatus == 1)
#include "EngineKeyHandleEventWordBreak.inc"
    } else if (data == KEY_SPACE) {
        #ifdef DEBUG
        fprintf(stderr, "[AutoEnglish] SPACE pressed: _stateIndex=%d, _index=%d, tempDisableKey=%d\n",
               _stateIndex, _index, tempDisableKey);
        fflush(stderr);
        #endif
        // CRITICAL FIX: Always run checkSpelling() for Auto English
        // Even when tempDisableKey=true, we need accurate _index for Auto English check
        // This ensures _index is up-to-date before checking English words
        if (isSpellCheckingEnabled()) {
            checkSpelling(true); //force check spelling (ignore tempDisableKey for Auto English)
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

        if (phtvRuntimeAutoRestoreEnglishWordEnabled() && _index > 0 && englishStateIndex > 1 && canAutoRestoreToken) {
            shouldRestoreEnglish = detectorShouldRestoreEnglishWord(KeyStates, englishStateIndex);
            if (!shouldRestoreEnglish) {
                if (detectorIsEnglishWordFromKeyStates(KeyStates, englishStateIndex) &&
                    !detectorIsVietnameseWordFromKeyStates(KeyStates, englishStateIndex) &&
                    !isVietnameseWordFromTypingWord(_index)) {
                    shouldRestoreEnglish = true;
                }
            }
            
            // PROTECTION: Single-character Vietnamese words should never be restored
            // When _index==1 and TypingWord has Vietnamese marks, it's a processed Vietnamese character
            // that has no equivalent English word. Standalone W patterns (e.g., "wf" for "ừ")
            // are not in any dictionary, so they could slip through both primary and fallback checks.
            // Examples: ừ (wf), ớ (o[s), ứ (uws), ờ (owf), etc.
            if (shouldRestoreEnglish && _index == 1) {
                if (TypingWord[0] & (MARK_MASK | TONE_MASK | TONEW_MASK | STANDALONE_MASK)) {
                    shouldRestoreEnglish = false;
                    #ifdef DEBUG
                    fprintf(stderr, "[AutoEnglish] SKIP RESTORE SPACE: Single Vietnamese char (has marks)\n");
                    fflush(stderr);
                    #endif
                }
            }

            // CANONICAL TELEX CHECK: Convert TypingWord to canonical Telex and verify against
            // Vietnamese dictionary. This catches ALL alternative Telex typing orders:
            //   "dods" → canonical "ddos" (đó) → Vietnamese → block restore
            //   "thoongr" → canonical "thoongr" (thỏng) → Vietnamese → block restore
            // The check only runs when TypingWord has Vietnamese marks (to avoid overhead
            // for pure English words like "search" where TypingWord base "seach" ≠ Vietnamese)
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
                    fprintf(stderr, "[AutoEnglish] SKIP RESTORE SPACE: Canonical Telex is Vietnamese\n");
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
                    fprintf(stderr, "[AutoEnglish] SKIP RESTORE SPACE: TypingWord is already clean English\n");
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
                fprintf(stderr, "[AutoEnglish] SKIP RESTORE SPACE: no Vietnamese transform in mixed token\n");
                fflush(stderr);
                #endif
            }
        }

        if (phtvRuntimeUseMacroEnabled() && !_hasHandledMacro && findMacro(hMacroKey, hMacroData)) { //macro
            hCode = vReplaceMaro;
            hBPC = (Byte)hMacroKey.size();
            _spaceCount++;
            #ifdef DEBUG
            fprintf(stderr, "[AutoEnglish] Macro matched, Auto English skipped\n");
            fflush(stderr);
            #endif
        } else if (phtvRuntimeAutoRestoreEnglishWordEnabled() && _index > 0 && restoreStateIndex > 1 && canAutoRestoreToken && shouldRestoreEnglish) {
            // PRIORITY FIX: Check Auto English BEFORE Quick Consonant
            // Auto English should have higher priority to prevent conflicts
            // (e.g., "search" ending in "ch" shouldn't trigger Quick Consonant)
            // Auto restore English word on SPACE
            // checkIfEnglishWord returns true only if word is English AND NOT Vietnamese
            // SAFETY: _index > 0 ensures we have characters to delete (prevents deleting nothing)
            #ifdef DEBUG
            fprintf(stderr, "[AutoEnglish] ✓ SPACE RESTORE: _stateIndex=%d, _index=%d\n", _stateIndex, _index);
            fflush(stderr);
            #endif
            hCode = vRestore;
            // SPACE FIX: Use _index for backspace (delete only what's on screen)
            // When Vietnamese processing combines chars (e.g., "search" → "sẻach"),
            // _stateIndex=6 but _index=5, so we must delete based on display count
            // to avoid deleting the space before the word
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
            _spaceCount++;
            // Reset session after restore to prevent re-triggering on next key (e.g., arrow keys)
            // This is different from vRestoreAndStartNewSession which also sends the break key
            _index = 0;
            _stateIndex = 0;
        } else if ((phtvRuntimeQuickStartConsonantEnabled() || phtvRuntimeQuickEndConsonantEnabled()) && !tempDisableKey && checkQuickConsonant()) {
            // Quick Consonant for Vietnamese typing shortcuts
            // Now checked AFTER Auto English to avoid conflicts
            _spaceCount++;
        } else if (tempDisableKey && !_hasHandledMacro) { //restore raw keys if word is invalid Vietnamese
            if (!checkRestoreIfWrongSpelling(vRestore)) {
                hCode = vDoNothing;
            }
            _spaceCount++;
        } else { //do nothing with SPACE KEY
            #ifdef DEBUG
            // Log why Auto English didn't trigger (for debugging random failures)
            if (phtvRuntimeAutoRestoreEnglishWordEnabled() && _stateIndex > 0) {
                std::string word = detectorKeyStatesToString(KeyStates, englishStateIndex);
                fprintf(stderr, "[AutoEnglish] ✗ SPACE NO RESTORE: word='%s', _stateIndex=%d, _index=%d, blocked by: ",
                       word.c_str(), _stateIndex, _index);
                if (_index <= 0) fprintf(stderr, "_index<=0 ");
                if (englishStateIndex <= 1) fprintf(stderr, "englishStateIndex<=1 ");
                if (!canAutoRestoreToken) fprintf(stderr, "invalidTokenShape ");
                if (!detectorShouldRestoreEnglishWord(KeyStates, englishStateIndex)) fprintf(stderr, "notEnglishWord ");
                fprintf(stderr, "\n");
                fflush(stderr);
            }
            #endif
            hCode = vDoNothing;
            _spaceCount++;
        }
        if (phtvRuntimeUseMacroEnabled()) {
            hMacroKey.clear();
            _hasHandledMacro = false;  // Reset when starting new word
        }
        if (_snapshotUpperCaseFirstChar && !phtvRuntimeUpperCaseExcludedForCurrentApp() && _upperCaseNeedsSpaceConfirm) {
            _upperCaseNeedsSpaceConfirm = false; // Space confirms: allow capitalize on next character
        }
        //save word
        if (_spaceCount == 1) {
            if (_specialChar.size() > 0) {
                saveSpecialChar();
            } else {
                saveWord();
            }
        }
        setSpellCheckingEnabled(_useSpellCheckingBefore);
        _willTempOffEngine = false;
    } else if (data == KEY_DELETE) {
        hCode = vDoNothing;
        hExt = 2; //delete
        tempDisableKey = false; // Reset temp disable on backspace
        if (_specialChar.size() > 0) {
            _specialChar.pop_back();
            if (_specialChar.size() == 0) {
                restoreLastTypingState();
            }
        } else if (_spaceCount > 0) { //previous char is space
            _spaceCount--;
            if (_spaceCount == 0) { //restore word
                restoreLastTypingState();
            }
        } else {
            if (_stateIndex > 0) {
                _stateIndex--;
            }
            if (_index > 0){
                _index--;
                if (_longWordHelper.size() > 0) {
                    //right shift
                    for (i = MAX_BUFF - 1; i > 0; i--) {
                        TypingWord[i] = TypingWord[i-1];
                    }
                    TypingWord[0] = _longWordHelper.back();
                    _longWordHelper.pop_back();
                    _index++;
                }
                if (isSpellCheckingEnabled())
                    checkSpelling();
            }
            if (phtvRuntimeUseMacroEnabled() && hMacroKey.size() > 0) {
                hMacroKey.pop_back();
            }
            
            hBPC = 0;
            hNCC = 0;
            hExt = 2; //delete key
            if (_index == 0) {
                // PERFORMANCE FIX: Removed file I/O from keystroke handler
                // Debug logging moved to stderr (use PHTV_DEBUG=1 environment variable)
                Byte savedUpperCaseStatus = _upperCaseStatus;
                bool savedNeedsSpaceConfirm = _upperCaseNeedsSpaceConfirm;
                startNewSession();
                _upperCaseStatus = savedUpperCaseStatus;
                _upperCaseNeedsSpaceConfirm = savedNeedsSpaceConfirm;
                _specialChar.clear();
                restoreLastTypingState();
            } else { //August 23rd continue check grammar
                checkGrammar(1);
            }
        }
    } else { //START AND CHECK KEY
        if (_willTempOffEngine) {
            hCode = vDoNothing;
            hExt = 3;
            return;
        }
        if (_spaceCount > 0) {
            hBPC = 0;
            hNCC = 0;
            hExt = 0;
            // FIX: Save space count BEFORE startNewSession() resets it
            int savedSpaceCount = _spaceCount;
            Byte savedUpperCaseStatus = _upperCaseStatus;
            bool savedNeedsSpaceConfirm = _upperCaseNeedsSpaceConfirm;
            startNewSession();
            _upperCaseStatus = savedUpperCaseStatus;
            _upperCaseNeedsSpaceConfirm = savedNeedsSpaceConfirm;
            //continue save space
            saveWord(KEY_SPACE, savedSpaceCount);
            // _spaceCount is already 0 from startNewSession()
        } else if (_specialChar.size() > 0) {
            saveSpecialChar();
        }

        insertState(data, _isCaps); //save state

        // If a tone mark is pressed while tempDisableKey is true, re-evaluate spelling.
        // This allows adding tone after finishing a word like "hưu" -> "hữu".
        bool allowMarkDespiteTempDisable = IS_MARK_KEY(data);

        // Also allow vowel modifiers to be applied even if tempDisableKey is true,
        // when the current word already has a tone/diacritic. This fixes cases like
        // "viejet" -> "việt" where the tone is typed before the vowel modifier.
        bool allowVowelChangeDespiteTempDisable = false;
        if (tempDisableKey && IS_SPECIALKEY(data) && !allowMarkDespiteTempDisable) {
            if (IS_KEY_DOUBLE(data) || IS_KEY_W(data) || IS_BRACKET_KEY(data)) {
                bool hasToneOrDiacritic = false;
                for (int scan = 0; scan < _index; scan++) {
                    if (TypingWord[scan] & (MARK_MASK | TONE_MASK | TONEW_MASK)) {
                        hasToneOrDiacritic = true;
                        break;
                    }
                }
                allowVowelChangeDespiteTempDisable = hasToneOrDiacritic;
            }
        }

        bool allowSpecialDespiteTempDisable = allowMarkDespiteTempDisable || allowVowelChangeDespiteTempDisable;
        if (isSpellCheckingEnabled() && allowSpecialDespiteTempDisable) {
            checkSpelling(true);
            
            // Fix for Issue #123: If word is invalid Vietnamese (tempDisableKey=true),
            // do not allow tone marks (s,f,r,x,j) to force themselves in.
            // This prevents "year" -> "yẻa", "string" -> "stríng", "global" -> "globá".
            // We only block MARK keys, allowing vowel corrections (aa, ee, dd) if they were allowed.
            if (tempDisableKey && allowMarkDespiteTempDisable) {
                // Allow tone marks when the word is Vietnamese-valid except for missing vowel modifiers
                // (e.g., "vie" + "j" then "e" -> "việc").
                bool allowToneOnInvalid = (_spellingOK && !_spellingVowelOK && canFixVowelWithDiacriticsForMark());
                if (!allowToneOnInvalid) {
                    allowSpecialDespiteTempDisable = false;
                }
            }
        }

        const bool quickTelexEnabled = phtvRuntimeQuickTelexEnabled() != 0;
        const bool freeMarkEnabled = phtvRuntimeFreeMarkEnabled() != 0;

        if (!IS_SPECIALKEY(data) || (tempDisableKey && !allowSpecialDespiteTempDisable)) { //do nothing
            if (quickTelexEnabled && IS_QUICK_TELEX_KEY(data)) {
                handleQuickTelex(data, _isCaps);
                return;
            } else {
                hCode = vDoNothing;
                hBPC = 0;
                hNCC = 0;
                hExt = 3; //normal key
                insertKey(data, _isCaps);
            }
        } else { //check and update key
            //restore state
            hCode = vDoNothing;
            hExt = 3; //normal key
            handleMainKey(data, _isCaps);
        }

        if (!freeMarkEnabled && !IS_KEY_D(data)) {
            if (hCode == vDoNothing) {
                checkGrammar(-1);
            } else {
                checkGrammar(0);
            }
        }
        
        if (hCode == vRestore) {
            insertKey(data, _isCaps);
            // FIX: Do NOT decrement _stateIndex here!
            // When a Telex mark is restored/removed (e.g., pressing 's' twice to toggle sắc),
            // the key was already added to KeyStates via insertState() at line 1712.
            // Decrementing _stateIndex causes English word detection to fail because
            // detectorShouldRestoreEnglishWord() would see "addres" (6 chars) instead of "address" (7 chars).
            // The key IS being inserted into TypingWord via insertKey() above, so _stateIndex
            // should remain in sync with the actual number of keys pressed.
        }
        
        //insert or replace key for macro feature
        if (phtvRuntimeUseMacroEnabled()) {
            if (hCode == vDoNothing) {
                hMacroKey.push_back(data | (_isCaps ? CAPS_MASK : 0));
            } else if (hCode == vWillProcess || hCode == vRestore) {
                for (i = 0; i < hBPC; i++) {
                    if (hMacroKey.size() > 0) {
                        hMacroKey.pop_back();
                    }
                }
                for (i = _index - hBPC; i < hNCC + (_index - hBPC); i++) {
                    hMacroKey.push_back(TypingWord[i]);
                }
            }
        }
        
        if (_snapshotUpperCaseFirstChar && !phtvRuntimeUpperCaseExcludedForCurrentApp()) {
            if (_index == 1 && _upperCaseStatus == 2 && !_upperCaseNeedsSpaceConfirm) {
                upperCaseFirstCharacter();
                // Track for English restore - in case Vietnamese transform didn't happen
                _shouldUpperCaseEnglishRestore = true;
            }
            _upperCaseStatus = 0;
            _upperCaseNeedsSpaceConfirm = false;
        }
        
        //case [ ]
        if (IS_BRACKET_KEY(data) && (( IS_BRACKET_KEY((Uint16)hData[0])) || runtimeInputTypeSnapshot == vSimpleTelex1 || runtimeInputTypeSnapshot == vSimpleTelex2)) {
            if (_index - (hCode == vWillProcess ? hBPC : 0) > 0) {
                _index--;
                saveWord();
            }
            _index = 0;
            tempDisableKey = false;
            _stateIndex = 0;
            hExt = 3;
            _specialChar.push_back(data | (_isCaps ? CAPS_MASK : 0));
        }
    }
    
    //Debug
    //cout<<"index "<<(int)_index<< ", stateIndex "<<(int)_stateIndex<<", word "<<_typingStates.size()<<", long word "<<_longWordHelper.size()<< endl;
    //cout<<"backspace "<<(int)hBPC<<endl;
    //cout<<"new char "<<(int)hNCC<<endl<<endl;
}
