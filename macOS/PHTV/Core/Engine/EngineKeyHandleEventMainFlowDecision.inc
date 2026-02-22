        const bool quickTelexEnabled = phtvRuntimeQuickTelexEnabled() != 0;
        const bool freeMarkEnabled = phtvRuntimeFreeMarkEnabled() != 0;

        if (!IS_SPECIALKEY(data) || (tempDisableKey && !allowSpecialDespiteTempDisable)) { //do nothing
            if (quickTelexEnabled && IS_QUICK_TELEX_KEY(data)) {
                handleQuickTelex(data, _isCaps);
                return;
            } else {
                hCode = vDoNothing;
                hBPC = 0;
                hNCC = 0;
                hExt = 3; //normal key
                insertKey(data, _isCaps);
            }
        } else { //check and update key
            //restore state
            hCode = vDoNothing;
            hExt = 3; //normal key
            handleMainKey(data, _isCaps);
        }
