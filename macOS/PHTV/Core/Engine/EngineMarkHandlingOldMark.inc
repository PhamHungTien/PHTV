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

