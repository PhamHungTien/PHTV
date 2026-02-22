void checkCorrectVowel(vector<vector<Uint16>>& charset, int& i, int& k, const Uint16& markKey) {
    //ignore "qu" case
    if (_index >= 2 && CHR(_index-1) == KEY_U && CHR(_index-2) == KEY_Q) {
        isCorect = false;
        return;
    }
    k = _index - 1;
    const bool quickEndConsonantEnabled = phtvRuntimeQuickEndConsonantEnabled() != 0;
    for (j = (int)charset[i].size() - 1; j >= 0; j--) {
        if ((charset[i][j] & ~(quickEndConsonantEnabled ? END_CONSONANT_MASK : 0)) != CHR(k)) {
            isCorect = false;
            return;
        }
        k--;
        if (k < 0)
            break;
    }
    
    //limit mark for end consonant: "C", "T"
    if (isCorect && charset[i].size() > 1 && (IS_KEY_F(markKey) || IS_KEY_X(markKey) || IS_KEY_R(markKey))) {
        if (charset[i][1] == KEY_C || charset[i][1] == KEY_T) {
            isCorect = false;
        } else if (charset[i].size() > 2 && (charset[i][2] == KEY_T)) {
            isCorect = false;
        }
    }
    
    if (isCorect && k >= 0) {
        // Block duplicate plain vowels, but allow marking when one of them is transformed
        // (e.g., "ưu" where ư has TONEW_MASK should allow tone marks).
        if (CHR(k) == CHR(k+1) &&
            !(TypingWord[k] & (TONE_MASK | TONEW_MASK)) &&
            !(TypingWord[k+1] & (TONE_MASK | TONEW_MASK))) {
            // Allow triple (or more) identical vowels when applying a tone mark
            // so sequences like "ooo" can still receive a tone before end consonants.
            if (IS_MARK_KEY(markKey) && k + 2 < _index && CHR(k) == CHR(k + 2)) {
                // keep isCorect = true
            } else {
                isCorect = false;
            }
        }
    }
}

Uint32 getCharacterCode(const Uint32& data) {
    const int codeTable = runtimeCodeTableSnapshot;

    capsElem = (data & CAPS_MASK) ? 0 : 1;
    key = data & CHAR_MASK;
    if (data & MARK_MASK) { //has mark
        markElem = -2;
        switch (data & MARK_MASK) {
            case MARK1_MASK:
                markElem = 0;
                break;
            case MARK2_MASK:
                markElem = 2;
                break;
            case MARK3_MASK:
                markElem = 4;
                break;
            case MARK4_MASK:
                markElem = 6;
                break;
            case MARK5_MASK:
                markElem = 8;
                break;
        }
        markElem += capsElem;
        
        switch (key) {
            case KEY_A:
            case KEY_O:
            case KEY_U:
            case KEY_E:
                if ((data & TONE_MASK) == 0 && (data & TONEW_MASK) == 0)
                    markElem += 4;
                break;
        }
        
        if (data & TONE_MASK) {
            key |= TONE_MASK;
        } else if (data & TONEW_MASK) {
            key |= TONEW_MASK;
        }
        if (_codeTable[codeTable].find(key) == _codeTable[codeTable].end())
            return data; //not found
        
        return _codeTable[codeTable][key][markElem] | CHAR_CODE_MASK;
    } else { //doesn't has mark
        if (_codeTable[codeTable].find(key) == _codeTable[codeTable].end())
            return data; //not found
        
        if (data & TONE_MASK) {
            return _codeTable[codeTable][key][capsElem] | CHAR_CODE_MASK;
        } else if (data & TONEW_MASK) {
            return _codeTable[codeTable][key][capsElem + 2] | CHAR_CODE_MASK;
        } else {
            return data; //not found
        }
    }
    
    return 0;
}

