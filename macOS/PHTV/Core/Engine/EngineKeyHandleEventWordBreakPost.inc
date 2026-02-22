        _isCharKeyCode = state == KeyDown && std::find(_charKeyCode.begin(), _charKeyCode.end(), data) != _charKeyCode.end();
        if (!_isCharKeyCode) { //clear all line cache
            _specialChar.clear();
            _typingStates.clear();
        } else { //check and save current word
            if (_spaceCount > 0) {
                saveWord(KEY_SPACE, _spaceCount);
                _spaceCount = 0;
            } else {
                saveWord();
            }
            _specialChar.push_back(data | (_isCaps ? CAPS_MASK : 0));
            hExt = 3;//normal word
        }
        
        if (hCode == vDoNothing) {
            startNewSession();
            setSpellCheckingEnabled(_useSpellCheckingBefore);
            _willTempOffEngine = false;
        } else if (hCode == vReplaceMaro || _hasHandleQuickConsonant) {
            _index = 0;
            _hasHandledMacro = false;  // Reset for next macro
        }

        //insert key for macro function
        if (phtvRuntimeUseMacroEnabled()) {
            if (_isCharKeyCode) {
                hMacroKey.push_back(data | (_isCaps ? CAPS_MASK : 0));
            } else {
                hMacroKey.clear();
                _hasHandledMacro = false;  // Reset when starting new word
            }
        }

        if (_snapshotUpperCaseFirstChar && !phtvRuntimeUpperCaseExcludedForCurrentApp()) {
            if (isSentenceTerminator(data, capsStatus)) {
                _upperCaseStatus = 2;
                // Period, question mark, exclamation need space before capitalizing (e.g. "iegglobal.vn" should not capitalize "v")
                // Enter/Return capitalize immediately (no space expected after newline)
                _upperCaseNeedsSpaceConfirm = (data != KEY_ENTER && data != KEY_RETURN);
            } else if (_upperCaseStatus > 0 && isUppercaseSkippablePunctuation(data, capsStatus)) {
                // Keep pending uppercase across quotes/brackets/parentheses
            } else {
                _upperCaseStatus = 0;
            }
        }
