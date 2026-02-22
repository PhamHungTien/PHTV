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
