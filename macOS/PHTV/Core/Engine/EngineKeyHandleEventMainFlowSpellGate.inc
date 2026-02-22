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
