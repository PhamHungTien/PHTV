// Helper to reverse mapping from Unicode char to Engine Key + Flags
Uint32 getEngineCharFromUnicode(const Uint16& ch) {
    refreshRuntimeLayoutSnapshot();
    const int codeTable = runtimeCodeTableSnapshot;

    // Iterate code table
    for (auto const& item : _codeTable[codeTable]) {
        Uint32 key = item.first;
        const vector<Uint16>& val = item.second;
        for (int i = 0; i < val.size(); i++) {
            if (val[i] == ch) {
                Uint32 engineChar = key & CHAR_MASK; // Base key
                
                // Add Flags based on index i and key flags
                bool isCaps = (i % 2 == 0);
                if (isCaps) engineChar |= CAPS_MASK;
                
                // If key has TONE_MASK or TONEW_MASK, it's already in key
                if (key & TONE_MASK) engineChar |= TONE_MASK;
                if (key & TONEW_MASK) engineChar |= TONEW_MASK;
                
                // Determine Mark or extra Tone flags based on index
                if ((key & (TONE_MASK|TONEW_MASK)) == 0) {
                    // Clean key (e.g. A, E, O)
                    if (i >= 0 && i <= 1) engineChar |= TONE_MASK;      // Â
                    else if (i >= 2 && i <= 3) engineChar |= TONEW_MASK; // Ă
                    else if (i >= 4 && i <= 5) engineChar |= MARK1_MASK; // Á
                    else if (i >= 6 && i <= 7) engineChar |= MARK2_MASK; // À
                    else if (i >= 8 && i <= 9) engineChar |= MARK3_MASK; // Ả
                    else if (i >= 10 && i <= 11) engineChar |= MARK4_MASK; // Ã
                    else if (i >= 12 && i <= 13) engineChar |= MARK5_MASK; // Ạ
                } else {
                    // Key has TONE (Â) or TONEW (Ă)
                    // 0,1: MARK1 (Sắc)
                    // ...
                    if (i >= 0 && i <= 1) engineChar |= MARK1_MASK;
                    else if (i >= 2 && i <= 3) engineChar |= MARK2_MASK;
                    else if (i >= 4 && i <= 5) engineChar |= MARK3_MASK;
                    else if (i >= 6 && i <= 7) engineChar |= MARK4_MASK;
                    else if (i >= 8 && i <= 9) engineChar |= MARK5_MASK;
                }
                
                engineChar |= CHAR_CODE_MASK;
                return engineChar;
            }
        }
    }
    
    // If not in code table, check character map (simple chars)
    if (ch < 128) {
        if (_characterMap.find(ch) != _characterMap.end()) {
            return _characterMap[ch];
        }
    }
    
    // Fallback: Pure Character
    return ch | PURE_CHARACTER_MASK;
}

void vRestoreSessionWithWord(const wstring& word) {
    // 1. Capture current raw keys if any (user typed while we were detecting)
    vector<Uint32> pendingKeys;
    for (int i = 0; i < _stateIndex; i++) {
        pendingKeys.push_back(KeyStates[i]);
    }

    startNewSession();
    
    for (size_t i = 0; i < word.length() && i < MAX_BUFF; i++) {
        Uint16 ch = (Uint16)word[i];
        Uint32 engineChar = getEngineCharFromUnicode(ch);
        
        TypingWord[_index] = engineChar;
        KeyStates[_stateIndex] = engineChar; // Best effort
        
        _index++;
        _stateIndex++;
    }
    
    saveWord();
    
    // Restore checking state based on validity
    checkSpelling(); 
    
    // 3. Replay pending keys
    if (!pendingKeys.empty()) {
        #ifdef DEBUG
        printf("[PHTV Restore] Replaying %lu pending keys\n", pendingKeys.size());
        #endif
        for (Uint32 keyData : pendingKeys) {
            Uint16 keyCode = keyData & CHAR_MASK;
            bool isCaps = (keyData & CAPS_MASK) != 0;
            // Replay as keyboard event
            vKeyHandleEvent(vKeyEvent::Keyboard, vKeyEventState::KeyDown, keyCode, isCaps ? 1 : 0, false);
        }
    }
}

