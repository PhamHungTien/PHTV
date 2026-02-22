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
