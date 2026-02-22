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
