static bool canFixVowelWithDiacriticsForMark() {
    // Preserve current vowel scan state (this is a hot path).
    Byte savedVowelCount = vowelCount;
    Byte savedVSI = VSI;
    Byte savedVEI = VEI;

    findAndCalculateVowel();
    if (vowelCount == 0) {
        vowelCount = savedVowelCount;
        VSI = savedVSI;
        VEI = savedVEI;
        return false;
    }

    auto it = _vowelCombine.find(CHR(VSI));
    if (it == _vowelCombine.end()) {
        vowelCount = savedVowelCount;
        VSI = savedVSI;
        VEI = savedVEI;
        return false;
    }

    const vector<vector<Uint32>>& vo = it->second;
    bool canFix = false;
    for (const auto& pattern : vo) {
        int patternLen = (int)pattern.size() - 1; // exclude flag
        if (patternLen < vowelCount) {
            continue;
        }

        bool match = true;
        for (int idx = 0; idx < vowelCount; idx++) {
            Uint32 expected = pattern[idx + 1];
            Uint16 expectedBase = expected & CHAR_MASK;
            Uint16 currentBase = CHR(VSI + idx);

            if (currentBase != expectedBase) {
                match = false;
                break;
            }

            Uint32 expectedTone = expected & (TONE_MASK | TONEW_MASK);
            Uint32 currentTone = TypingWord[VSI + idx] & (TONE_MASK | TONEW_MASK);

            if (expectedTone == 0) {
                if (currentTone != 0) {
                    match = false;
                    break;
                }
            } else {
                if (currentTone != 0 && currentTone != expectedTone) {
                    match = false;
                    break;
                }
            }
        }

        if (match) {
            canFix = true;
            break;
        }
    }

    vowelCount = savedVowelCount;
    VSI = savedVSI;
    VEI = savedVEI;
    return canFix;
}

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

void handleOldMark() {
    // Normalize trailing repeated vowels (e.g., "iuu", "aa") to place tone on the base vowel cluster
    Byte originalVEI = VEI;
    Byte originalVowelCount = vowelCount;
    bool adjustedTrailing = false;
    if (vowelCount >= 2) {
        int tailStart = VEI;
        Uint16 tailVowel = CHR(VEI);
        while (tailStart > VSI && CHR(tailStart - 1) == tailVowel) {
            tailStart--;
        }
        if (VEI - tailStart + 1 >= 2) {
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

    //default
    if (vowelCount == 0 && CHR(VEI) == KEY_I)
        VWSM = VEI;
    else
        VWSM = VSI;
    hBPC = (_index - VWSM);
    
    //rule 2
    if (vowelCount == 3 || (VEI + 1 < _index && IS_CONSONANT(CHR(VEI + 1)) && canHasEndConsonant())) {
        VWSM = VSI + 1;
        hBPC = _index - VWSM;
    }
    
    //rule 3
    for (ii = VSI; ii <= VEI; ii++) {
        if ((CHR(ii) == KEY_E && TypingWord[ii] & TONE_MASK) || (CHR(ii) == KEY_O && TypingWord[ii] & TONEW_MASK)) {
            VWSM = ii;
            hBPC = _index - VWSM;
            break;
        }
    }
    
    hNCC = hBPC;

    if (adjustedTrailing) {
        VEI = originalVEI;
        vowelCount = originalVowelCount;
    }
}

void insertMark(const Uint32& markMask, const bool& canModifyFlag) {
    vowelCount = 0;

    if (canModifyFlag)
        hCode = vWillProcess;
    hBPC = hNCC = 0;

    findAndCalculateVowel();
    VWSM = 0;

    //detect mark position
    if (vowelCount == 1) {
        VWSM = VEI;
        hBPC = (_index - VEI);
    } else { //vowel = 2 or 3
        if (phtvRuntimeUseModernOrthographyEnabled() == 0)
            handleOldMark();
        else
            handleModernMark();
        if (TypingWord[VEI] & TONE_MASK || TypingWord[VEI] & TONEW_MASK)
            vowelWillSetMark = VEI;
    }

    //send data
    kk = _index - 1 - VSI;
    //if duplicate same mark -> restore
    if (TypingWord[VWSM] & markMask) {

        TypingWord[VWSM] &= ~MARK_MASK;
        if (canModifyFlag)
            hCode = vRestore;
        for (ii = VSI; ii < _index; ii++) {
            TypingWord[ii] &= ~MARK_MASK;
            hData[kk--] = GET(TypingWord[ii]);
        }
        //_index = 0;
        tempDisableKey = true;
    } else {
        //remove other mark
        TypingWord[VWSM] &= ~MARK_MASK;

        //add mark
        TypingWord[VWSM] |= markMask;
        for (ii = VSI; ii < _index; ii++) {
            if (ii != VWSM) { //remove mark for other vowel
                TypingWord[ii] &= ~MARK_MASK;
            }
            hData[kk--] = GET(TypingWord[ii]);
        }

        hBPC = _index - VSI;
    }
    hNCC = hBPC;
}

void insertD(const Uint16& data, const bool& isCaps) {
    hCode = vWillProcess;
    hBPC = 0;
    for (ii = _index - 1; ii >= 0; ii--) {
        hBPC++;
        if (CHR(ii) == KEY_D) { //reverse unicode char
            if (TypingWord[ii] & TONE_MASK) {
                //restore and disable temporary
                hCode = vRestore;
                TypingWord[ii] &= ~TONE_MASK;
                hData[_index - 1 - ii] = TypingWord[ii];
                tempDisableKey = true;
                break;
            } else {
                TypingWord[ii] |= TONE_MASK;
                hData[_index - 1 - ii] = GET(TypingWord[ii]);
            }
            break;
        } else { //preresent old char
            hData[_index - 1 - ii] = GET(TypingWord[ii]);
        }
    }
    hNCC = hBPC;
}

void insertAOE(const Uint16& data, const bool& isCaps) {
    findAndCalculateVowel();
    
    //remove W tone
    for (ii = VSI; ii <= VEI; ii++) {
        TypingWord[ii] &= ~TONEW_MASK;
    }
    
    hCode = vWillProcess;
    hBPC = 0;
    
    for (ii = _index - 1; ii >= 0; ii--) {
        hBPC++;
        if (CHR(ii) == data) { //reverse unicode char
            if (TypingWord[ii] & TONE_MASK) {
                //restore and disable temporary
                hCode = vRestore;
                TypingWord[ii] &= ~TONE_MASK;
                hData[_index - 1 - ii] = TypingWord[ii];
                //_index = 0;
                if (data != KEY_O) //case thoòng
                    tempDisableKey = true;
                break;
            } else {
                TypingWord[ii] |= TONE_MASK;
                if (!IS_KEY_D(data))
                    TypingWord[ii] &= ~TONEW_MASK;
                hData[_index - 1 - ii] = GET(TypingWord[ii]);
                
            }
            break;
        } else { //preresent old char
            hData[_index - 1 - ii] = GET(TypingWord[ii]);
        }
    }
    hNCC = hBPC;
}

void insertW(const Uint16& data, const bool& isCaps) {
    isRestoredW = false;
    
    findAndCalculateVowel();
    
    //remove ^ tone
    for (ii = VSI; ii <= VEI; ii++) {
        TypingWord[ii] &= ~TONE_MASK;
    }
    
    if (vowelCount > 1) {
        hBPC = _index - VSI;
        hNCC = hBPC;
        
        if (((TypingWord[VSI] & TONEW_MASK) && (TypingWord[VSI+1] & TONEW_MASK)) ||
            ((TypingWord[VSI] & TONEW_MASK) && CHR(VSI+1) == KEY_I) ||
            ((TypingWord[VSI] & TONEW_MASK) && CHR(VSI+1) == KEY_A)){
            //restore and disable temporary
            hCode = vRestore;
            
            for (ii = VSI; ii < _index; ii++) {
                TypingWord[ii] &= ~TONEW_MASK;
                hData[_index - 1 - ii] = GET(TypingWord[ii]) & ~STANDALONE_MASK;
            }
            isRestoredW = true;
            tempDisableKey = true;
        } else {
            hCode = vWillProcess;

            // FIX: Check if vowel already has TONEW_MASK - if so, restore and disable
            // This handles cases like "thuơ" + "w" -> should restore to "thuo" then add "w" -> "thuow"
            bool shouldRestore = false;
            if ((CHR(VSI) == KEY_U && CHR(VSI+1) == KEY_O)) {
                if (VSI - 2 >= 0 && TypingWord[VSI - 2] == KEY_T && TypingWord[VSI - 1] == KEY_H) {
                    // "thuo" case: only VSI+1 (o) gets TONEW_MASK
                    if (TypingWord[VSI+1] & TONEW_MASK) {
                        // Already has TONEW_MASK, restore it
                        shouldRestore = true;
                    } else {
                        TypingWord[VSI+1] |= TONEW_MASK;
                        if (VSI + 2 < _index && CHR(VSI+2) == KEY_N) {
                            TypingWord[VSI] |= TONEW_MASK;
                        }
                    }
                } else if (VSI - 1 >= 0 && TypingWord[VSI - 1] == KEY_Q) {
                    // "quo" case
                    if (TypingWord[VSI+1] & TONEW_MASK) {
                        shouldRestore = true;
                    } else {
                        TypingWord[VSI+1] |= TONEW_MASK;
                    }
                } else {
                    // Other "uo" cases: both vowels get TONEW_MASK
                    if ((TypingWord[VSI] & TONEW_MASK) && !(TypingWord[VSI+1] & TONEW_MASK)) {
                        // Allow "uow" -> "ươ": add TONEW to 'o' without restoring
                        TypingWord[VSI+1] |= TONEW_MASK;
                    } else if ((TypingWord[VSI] & TONEW_MASK) || (TypingWord[VSI+1] & TONEW_MASK)) {
                        shouldRestore = true;
                    } else {
                        TypingWord[VSI] |= TONEW_MASK;
                        TypingWord[VSI+1] |= TONEW_MASK;
                    }
                }
            } else if ((CHR(VSI) == KEY_U && CHR(VSI+1) == KEY_A) ||
                       (CHR(VSI) == KEY_U && CHR(VSI+1) == KEY_I) ||
                       (CHR(VSI) == KEY_U && CHR(VSI+1) == KEY_U) ||
                       (CHR(VSI) == KEY_O && CHR(VSI+1) == KEY_I)) {
                if (TypingWord[VSI] & TONEW_MASK) {
                    shouldRestore = true;
                } else {
                    TypingWord[VSI] |= TONEW_MASK;
                }
            } else if ((CHR(VSI) == KEY_I && CHR(VSI+1) == KEY_O) ||
                       (CHR(VSI) == KEY_O && CHR(VSI+1) == KEY_A)) {
                if (TypingWord[VSI+1] & TONEW_MASK) {
                    shouldRestore = true;
                } else {
                    TypingWord[VSI+1] |= TONEW_MASK;
                }
            } else {
                //don't do anything
                tempDisableKey = true;
                isChanged = false;
                hCode = vDoNothing;
            }

            if (shouldRestore) {
                // Restore: remove TONEW_MASK from all vowels
                hCode = vRestore;
                for (ii = VSI; ii < _index; ii++) {
                    TypingWord[ii] &= ~TONEW_MASK;
                    hData[_index - 1 - ii] = GET(TypingWord[ii]) & ~STANDALONE_MASK;
                }
                isRestoredW = true;
                tempDisableKey = true;
            } else if (hCode == vWillProcess) {
                for (ii = VSI; ii < _index; ii++) {
                    hData[_index - 1 - ii] = GET(TypingWord[ii]);
                }
            }
        }
        
        return;
    }
    
    hCode = vWillProcess;
    hBPC = 0;
    
    for (ii = _index - 1; ii >= 0; ii--) {
        if (ii < VSI)
            break;
        hBPC++;
        switch (CHR(ii)) {
            case KEY_A:
            case KEY_U:
            case KEY_O:
                if (TypingWord[ii] & TONEW_MASK) {
                    //restore and disable temporary
                    if (TypingWord[ii] & STANDALONE_MASK) {
                        hCode = vWillProcess;
                        if (CHR(ii) == KEY_U){
                            TypingWord[ii] = KEY_W | ((TypingWord[ii] & CAPS_MASK) ? CAPS_MASK : 0);
                        } else if (CHR(ii) == KEY_O) {
                            hCode = vRestore;
                            TypingWord[ii] = KEY_O | ((TypingWord[ii] & CAPS_MASK) ? CAPS_MASK : 0);
                            isRestoredW = true;
                        }
                        hData[_index - 1 - ii] = TypingWord[ii];
                    } else {
                        hCode = vRestore;
                        TypingWord[ii] &= ~TONEW_MASK;
                        hData[_index - 1 - ii] = TypingWord[ii];
                        isRestoredW = true;
                        //_index++;
                    }
                    
                    tempDisableKey = true;
                } else {
                    TypingWord[ii] |= TONEW_MASK;
                    TypingWord[ii] &= ~TONE_MASK;
                    hData[_index - 1 - ii] = GET(TypingWord[ii]);
                }
                break;
                
            default:
                hData[_index - 1 - ii] = GET(TypingWord[ii]);
                break;
        }
    }
    hNCC = hBPC;
    
    if (isRestoredW) {
        //_index = 0;
    }
}
