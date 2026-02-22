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

#include "EngineKeyHandleEventMainFlowPost.inc"
