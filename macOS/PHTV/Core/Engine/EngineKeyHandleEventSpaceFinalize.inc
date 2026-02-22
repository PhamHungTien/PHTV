        if (phtvRuntimeUseMacroEnabled()) {
            hMacroKey.clear();
            _hasHandledMacro = false;  // Reset when starting new word
        }
        if (_snapshotUpperCaseFirstChar && !phtvRuntimeUpperCaseExcludedForCurrentApp() && _upperCaseNeedsSpaceConfirm) {
            _upperCaseNeedsSpaceConfirm = false; // Space confirms: allow capitalize on next character
        }
        //save word
        if (_spaceCount == 1) {
            if (_specialChar.size() > 0) {
                saveSpecialChar();
            } else {
                saveWord();
            }
        }
        setSpellCheckingEnabled(_useSpellCheckingBefore);
        _willTempOffEngine = false;
