        hCode = vDoNothing;
        hExt = 2; //delete
        tempDisableKey = false; // Reset temp disable on backspace
        if (_specialChar.size() > 0) {
            _specialChar.pop_back();
            if (_specialChar.size() == 0) {
                restoreLastTypingState();
            }
        } else if (_spaceCount > 0) { //previous char is space
            _spaceCount--;
            if (_spaceCount == 0) { //restore word
                restoreLastTypingState();
            }
        } else {
            if (_stateIndex > 0) {
                _stateIndex--;
            }
            if (_index > 0){
                _index--;
                if (_longWordHelper.size() > 0) {
                    //right shift
                    for (i = MAX_BUFF - 1; i > 0; i--) {
                        TypingWord[i] = TypingWord[i-1];
                    }
                    TypingWord[0] = _longWordHelper.back();
                    _longWordHelper.pop_back();
                    _index++;
                }
                if (isSpellCheckingEnabled())
                    checkSpelling();
            }
            if (phtvRuntimeUseMacroEnabled() && hMacroKey.size() > 0) {
                hMacroKey.pop_back();
            }
            
            hBPC = 0;
            hNCC = 0;
            hExt = 2; //delete key
            if (_index == 0) {
                // PERFORMANCE FIX: Removed file I/O from keystroke handler
                // Debug logging moved to stderr (use PHTV_DEBUG=1 environment variable)
                Byte savedUpperCaseStatus = _upperCaseStatus;
                bool savedNeedsSpaceConfirm = _upperCaseNeedsSpaceConfirm;
                startNewSession();
                _upperCaseStatus = savedUpperCaseStatus;
                _upperCaseNeedsSpaceConfirm = savedNeedsSpaceConfirm;
                _specialChar.clear();
                restoreLastTypingState();
            } else { //August 23rd continue check grammar
                checkGrammar(1);
            }
        }
