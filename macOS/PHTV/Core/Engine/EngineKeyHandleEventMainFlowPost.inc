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
