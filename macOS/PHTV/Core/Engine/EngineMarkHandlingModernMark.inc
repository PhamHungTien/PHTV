void handleModernMark() {
    // Normalize trailing repeated vowels (e.g., "iuu", "aa") to place tone on the base vowel cluster
    Byte originalVEI = VEI;
    Byte originalVowelCount = vowelCount;
    bool adjustedTrailing = false;
    bool preferLastRepeat = false;
    if (vowelCount >= 2) {
        int tailStart = VEI;
        Uint16 tailVowel = CHR(VEI);
        while (tailStart > VSI && CHR(tailStart - 1) == tailVowel) {
            tailStart--;
        }
        if (VEI - tailStart + 1 >= 2) {
            bool runHasDiacritic = false;
            for (int idx = tailStart; idx <= VEI; idx++) {
                if (TypingWord[idx] & (TONE_MASK | TONEW_MASK)) {
                    runHasDiacritic = true;
                    break;
                }
            }
            // Special-case repeated 'o' in modern orthography (loanwords like "boong"):
            // place the tone on the last 'o' instead of the first.
            if (!runHasDiacritic && tailVowel == KEY_O && tailStart == VSI) {
                preferLastRepeat = true;
            } else {
                VEI = (Byte)tailStart;
                vowelCount = 0;
                for (int idx = VSI; idx <= VEI; idx++) {
                    if (!IS_CONSONANT(CHR(idx))) {
                        vowelCount++;
                    }
                }
                adjustedTrailing = true;
            }
        }
    }

    //default
    VWSM = VEI;
    hBPC = (_index - VEI);
    
    //rule 2
    if (vowelCount == 3 && ((CHR(VSI) == KEY_O && CHR(VSI+1) == KEY_A && CHR(VSI+2) == KEY_I) ||
                            (CHR(VSI) == KEY_U && CHR(VSI+1) == KEY_Y && CHR(VSI+2) == KEY_U) ||
                            (CHR(VSI) == KEY_O && CHR(VSI+1) == KEY_E && CHR(VSI+2) == KEY_O) ||
                            (CHR(VSI) == KEY_U && CHR(VSI+1) == KEY_Y && CHR(VSI+2) == KEY_A))) {
        VWSM = VSI + 1;
        hBPC = _index - VWSM;
    } else if (vowelCount >= 2 && CHR(VEI) == KEY_Y) {
        // Modern orthography: "uy" places tone on 'y' (u+y) instead of 'u'.
        if (vowelCount == 2 && CHR(VSI) == KEY_U && CHR(VSI + 1) == KEY_Y) {
            VWSM = VEI;
            hBPC = _index - VWSM;
        } else {
            // Diphthongs ending with 'y' (ay, oay, ...) place tone on the last non-'y' vowel
            int lastNonY = VEI;
            while (lastNonY >= VSI && CHR(lastNonY) == KEY_Y) {
                lastNonY--;
            }
            if (lastNonY >= VSI) {
                VWSM = lastNonY;
                hBPC = _index - VWSM;
            }
        }
    } else if ((CHR(VSI) == KEY_O && CHR(VSI+1) == KEY_I) ||
               (CHR(VSI) == KEY_A && CHR(VSI+1) == KEY_I) ||
               (CHR(VSI)== KEY_U && CHR(VSI+1) == KEY_I) ) {
        
        VWSM = VSI;
        hBPC = _index - VWSM;
    } else if (CHR(VEI-1) == KEY_A && CHR(VEI) == KEY_Y) {
        VWSM = VEI - 1;
        hBPC = (_index - VEI) + 1;
    } else if (CHR(VSI) == KEY_U && CHR(VSI+1) == KEY_O) {
        VWSM = VSI + 1;
        hBPC = _index - VWSM;
    } else if (CHR(VSI+1) == KEY_O || CHR(VSI+1) == KEY_U) {
        VWSM = VEI - 1;
        hBPC = (_index - VEI) + 1;
    } else if (CHR(VSI) == KEY_O || CHR(VSI) == KEY_U) {
        VWSM = VEI;
        hBPC = (_index - VEI);
    }
    
    //rule 3.1
    if ((CHR(VSI) == KEY_I && (TypingWord[VSI+1] & (KEY_E | TONE_MASK))) ||
        (CHR(VSI) == KEY_Y && (TypingWord[VSI+1] & (KEY_E | TONE_MASK))) ||
        (CHR(VSI) == KEY_U && (TypingWord[VSI+1] == (KEY_O | TONE_MASK))) ||
        ((TypingWord[VSI] == (KEY_U | TONEW_MASK)) && (TypingWord[VSI+1] == (KEY_O | TONEW_MASK)))){

        // If the second vowel already has a diacritic (iê/yê/uô/ươ), keep tone on it.
        bool forceSecondVowel = false;
        if ((CHR(VSI) == KEY_I || CHR(VSI) == KEY_Y) &&
            CHR(VSI + 1) == KEY_E &&
            (TypingWord[VSI + 1] & TONE_MASK)) {
            forceSecondVowel = true;
        } else if (CHR(VSI) == KEY_U &&
                   CHR(VSI + 1) == KEY_O &&
                   (TypingWord[VSI + 1] & TONE_MASK)) {
            forceSecondVowel = true;
        } else if ((TypingWord[VSI] & TONEW_MASK) &&
                   (TypingWord[VSI + 1] & TONEW_MASK) &&
                   CHR(VSI) == KEY_U &&
                   CHR(VSI + 1) == KEY_O) {
            forceSecondVowel = true;
        }

        if (forceSecondVowel) {
            VWSM = VSI + 1;
            hBPC = _index - VWSM;
        } else if (VSI+2 < _index) {
            if (CHR(VSI+2) == KEY_P || CHR(VSI+2) == KEY_T ||
                CHR(VSI+2) == KEY_M || CHR(VSI+2) == KEY_N ||
                CHR(VSI+2) == KEY_O || CHR(VSI+2) == KEY_U ||
                CHR(VSI+2) == KEY_I || CHR(VSI+2) == KEY_C ||
                (VSI+3 < _index && CHR(VSI+2) == KEY_C && CHR(VSI+2) == KEY_H) ||
                (VSI+3 < _index && CHR(VSI+2) == KEY_N && CHR(VSI+2) == KEY_H) ||
                (VSI+3 < _index && CHR(VSI+2) == KEY_N && CHR(VSI+2) == KEY_G)) {
                
                VWSM = VSI + 1;
                hBPC = _index - VWSM;
            } else {
                VWSM = VSI;
                hBPC = _index - VWSM;
            }
        } else {
            VWSM = VSI;
            hBPC = _index - VWSM;
        }
    }
    //rule 3.2
    else if ((CHR(VSI) == KEY_I && (CHR(VSI) == KEY_A)) ||
             (CHR(VSI) == KEY_Y && (CHR(VSI) == KEY_A)) ||
             (CHR(VSI) == KEY_U && (CHR(VSI) == KEY_A)) ||
             (CHR(VSI) == KEY_U && (TypingWord[VSI+1] == (KEY_U | TONEW_MASK)))){
        
        VWSM = VSI;
        hBPC = _index - VWSM;
    }
    
    //rule 4
    if (vowelCount == 2) {
        if (((CHR(VSI) == KEY_I) && (CHR(VSI+1) == KEY_A)) ||
            ((CHR(VSI) == KEY_I) && (CHR(VSI+1) == KEY_U)) ||
            ((CHR(VSI) == KEY_I) && (CHR(VSI+1) == KEY_O))) {
            
            if (VSI == 0 || (CHR(VSI-1) != KEY_G)) { //dont have G
                VWSM = VSI;
                hBPC = _index - VWSM;
            } else {
                VWSM = VSI + 1;
                hBPC = _index - VWSM;
            }
        } else if ((CHR(VSI) == KEY_U) && (CHR(VSI+1) == KEY_A)) {
            if (VSI == 0 || (CHR(VSI-1) != KEY_Q)) { //dont have Q
                if (VEI + 1 >= _index || !canHasEndConsonant()) {
                    VWSM = VSI;
                    hBPC = _index - VWSM;
                }
            } else {
                VWSM = VSI + 1;
                hBPC = _index - VWSM;
            }
        } else if ((CHR(VSI) == KEY_O) && (CHR(VSI+1) == KEY_O)) { //thoong
            VWSM = VEI;
            hBPC = _index - VWSM;
        }
    }

    if (preferLastRepeat) {
        VWSM = originalVEI;
        hBPC = (_index - VWSM);
    }

    if (adjustedTrailing) {
        VEI = originalVEI;
        vowelCount = originalVowelCount;
    }
}

