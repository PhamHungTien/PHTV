void insertKey(const Uint16& keyCode, const bool& isCaps, const bool& isCheckSpelling=true) {
    if (_index >= MAX_BUFF) {
        _longWordHelper.push_back(TypingWord[0]); //save long word
        //left shift - buffer is full, shift all elements left
        for (iii = 0; iii < MAX_BUFF - 1; iii++) {
            TypingWord[iii] = TypingWord[iii + 1];
        }
        // SAFETY FIX: Always write to last position when buffer is full
        // Using _index-1 could cause out-of-bounds if _index > MAX_BUFF
        setKeyData(MAX_BUFF - 1, keyCode, isCaps);
    } else {
        setKeyData(_index++, keyCode, isCaps);
    }
    
    if (isSpellCheckingEnabled() && isCheckSpelling)
        checkSpelling();
    
    //allow d after consonant
    if (keyCode == KEY_D && _index - 2 >= 0 && IS_CONSONANT(CHR(_index - 2)))
        tempDisableKey = false;
}

void insertState(const Uint16& keyCode, const bool& isCaps) {
    if (_stateIndex >= MAX_BUFF) {
        //left shift - buffer is full, shift all elements left
        for (iii = 0; iii < MAX_BUFF - 1; iii++) {
            KeyStates[iii] = KeyStates[iii + 1];
        }
        // SAFETY FIX: Always write to last position when buffer is full
        // Using _stateIndex-1 could cause out-of-bounds if _stateIndex > MAX_BUFF
        KeyStates[MAX_BUFF - 1] = keyCode | (isCaps ? CAPS_MASK : 0);
    } else {
        KeyStates[_stateIndex++] = keyCode | (isCaps ? CAPS_MASK : 0);
    }
}

