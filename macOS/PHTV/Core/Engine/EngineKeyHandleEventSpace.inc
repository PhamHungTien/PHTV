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

#include "EngineKeyHandleEventSpaceDecision.inc"
#include "EngineKeyHandleEventSpaceFinalize.inc"
