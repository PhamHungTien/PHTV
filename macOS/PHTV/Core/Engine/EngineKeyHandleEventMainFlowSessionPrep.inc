        if (_willTempOffEngine) {
            hCode = vDoNothing;
            hExt = 3;
            return;
        }
        if (_spaceCount > 0) {
            hBPC = 0;
            hNCC = 0;
            hExt = 0;
            // FIX: Save space count BEFORE startNewSession() resets it
            int savedSpaceCount = _spaceCount;
            Byte savedUpperCaseStatus = _upperCaseStatus;
            bool savedNeedsSpaceConfirm = _upperCaseNeedsSpaceConfirm;
            startNewSession();
            _upperCaseStatus = savedUpperCaseStatus;
            _upperCaseNeedsSpaceConfirm = savedNeedsSpaceConfirm;
            //continue save space
            saveWord(KEY_SPACE, savedSpaceCount);
            // _spaceCount is already 0 from startNewSession()
        } else if (_specialChar.size() > 0) {
            saveSpecialChar();
        }

        insertState(data, _isCaps); //save state
