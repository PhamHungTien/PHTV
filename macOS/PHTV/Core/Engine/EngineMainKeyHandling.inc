void handleMainKey(const Uint16& data, const bool& isCaps) {
    //if is Z key, remove mark
    if (IS_KEY_Z(data)) {
        removeMark();
        if (!isChanged) {
            // Fallback: allow tone marks on words containing horn vowels (ư/ơ/ă)
            // even if the exact pattern isn't in _vowelForMark (e.g., "huwux" -> "hữu").
            bool hasToneW = false;
            for (ii = 0; ii < _index; ii++) {
                if (TypingWord[ii] & TONEW_MASK) {
                    hasToneW = true;
                    break;
                }
            }
            if (hasToneW) {
                if (isSpellCheckingEnabled()) {
                    checkSpelling(true);
                }
                if (_spellingOK && _spellingVowelOK) {
                    if (IS_KEY_S(data))
                        insertMark(MARK1_MASK);
                    else if (IS_KEY_F(data))
                        insertMark(MARK2_MASK);
                    else if (IS_KEY_R(data))
                        insertMark(MARK3_MASK);
                    else if (IS_KEY_X(data))
                        insertMark(MARK4_MASK);
                    else if (IS_KEY_J(data))
                        insertMark(MARK5_MASK);
                    return;
                }

                // Last resort: try marking the last horn vowel (ư/ơ/ă) even if spelling check fails.
                int markIndex = -1;
                for (ii = _index - 1; ii >= 0; ii--) {
                    if ((TypingWord[ii] & TONEW_MASK) != 0) {
                        markIndex = ii;
                        break;
                    }
                }
                if (markIndex >= 0) {
                    TypingWord[markIndex] &= ~MARK_MASK;
                    if (IS_KEY_S(data))
                        TypingWord[markIndex] |= MARK1_MASK;
                    else if (IS_KEY_F(data))
                        TypingWord[markIndex] |= MARK2_MASK;
                    else if (IS_KEY_R(data))
                        TypingWord[markIndex] |= MARK3_MASK;
                    else if (IS_KEY_X(data))
                        TypingWord[markIndex] |= MARK4_MASK;
                    else if (IS_KEY_J(data))
                        TypingWord[markIndex] |= MARK5_MASK;

                    hCode = vWillProcess;
                    hBPC = 0;
                    for (ii = _index - 1; ii >= 0; ii--) {
                        hBPC++;
                        hData[_index - 1 - ii] = GET(TypingWord[ii]);
                    }
                    hNCC = hBPC;
                    return;
                }
            }

            insertKey(data, isCaps);
        }
        return;
    }

    if (data == KEY_LEFT_BRACKET) { //standalone key [
        checkForStandaloneChar(data, isCaps, KEY_O);
        return;
    }

    if (data == KEY_RIGHT_BRACKET) { //standalone key }
        checkForStandaloneChar(data, isCaps, KEY_U);
        return;
    }

    //if is D key
    if (IS_KEY_D(data)) {
        isCorect = false;
        isChanged = false;
        k = _index;
        for (i = 0; i < _consonantD.size(); i++) {
            if (_index < _consonantD[i].size())
                continue;
            isCorect = true;
            checkCorrectVowel(_consonantD, i, k, data);

            //allow d after consonant
            if (!isCorect && _index - 2 >= 0 && CHR(_index-1) == KEY_D && IS_CONSONANT(CHR(_index-2))) {
                isCorect = true;
            }
            if (isCorect) {
                isChanged = true;
                insertD(data, isCaps);
                break;
            }
        }

        if (!isChanged) {
            insertKey(data, isCaps);
        }
        return;
    }

    //if is mark key
    if (IS_MARK_KEY(data)) {
        // Special-case: allow tone on "ưu" when typed as "huwu" then mark (huwux -> hữu)
        if (_index >= 2 &&
            CHR(_index - 1) == KEY_U &&
            CHR(_index - 2) == KEY_U &&
            (TypingWord[_index - 2] & TONEW_MASK) &&
            !(TypingWord[_index - 1] & TONEW_MASK)) {
            TypingWord[_index - 2] &= ~MARK_MASK;
            if (IS_KEY_S(data))
                TypingWord[_index - 2] |= MARK1_MASK;
            else if (IS_KEY_F(data))
                TypingWord[_index - 2] |= MARK2_MASK;
            else if (IS_KEY_R(data))
                TypingWord[_index - 2] |= MARK3_MASK;
            else if (IS_KEY_X(data))
                TypingWord[_index - 2] |= MARK4_MASK;
            else if (IS_KEY_J(data))
                TypingWord[_index - 2] |= MARK5_MASK;

            hCode = vWillProcess;
            hBPC = 0;
            for (ii = _index - 1; ii >= 0; ii--) {
                hBPC++;
                hData[_index - 1 - ii] = GET(TypingWord[ii]);
            }
            hNCC = hBPC;
            return;
        }

        for (auto it = _vowelForMark.begin(); it != _vowelForMark.end(); ++it) {
            vector<vector<Uint16>>& charset = it->second;
            isCorect = false;
            isChanged = false;
            k = _index;
            for (l = 0; l < charset.size(); l++) {
                if (_index < charset[l].size())
                    continue;
                isCorect = true;
                checkCorrectVowel(charset, l, k, data);

                if (isCorect) {
                    isChanged = true;
                    if (IS_KEY_S(data))
                        insertMark(MARK1_MASK);
                    else if (IS_KEY_F(data))
                        insertMark(MARK2_MASK);
                    else if (IS_KEY_R(data))
                        insertMark(MARK3_MASK);
                    else if (IS_KEY_X(data))
                        insertMark(MARK4_MASK);
                    else if (IS_KEY_J(data))
                        insertMark(MARK5_MASK);
                    break;
                }
            }

            if (isCorect) {
                break;
            }
        }

        if (!isChanged) {
            insertKey(data, isCaps);
        }

        return;
    }

    //check Vowel
    if (runtimeInputTypeSnapshot == vVNI) {
        for (i = _index-1; i >= 0; i--) {
            if (CHR(i) == KEY_O || CHR(i) == KEY_A || CHR(i) == KEY_E) {
                VEI = i;
                break;
            }
        }
    }

    keyForAEO = ((runtimeInputTypeSnapshot != vVNI) ? data : ((data == KEY_7 || data == KEY_8 ? KEY_W : (data == KEY_6 ? TypingWord[VEI] : data))));
    vector<vector<Uint16>>& charset = _vowel[keyForAEO];
    isCorect = false;
    isChanged = false;
    k = _index;
    for (i = 0; i < charset.size(); i++) {
        if (_index < charset[i].size())
            continue;
        isCorect = true;
        checkCorrectVowel(charset, i, k, data);

        if (isCorect) {
            isChanged = true;
            if (IS_KEY_DOUBLE(data)) {
                insertAOE(keyForAEO, isCaps);
            } else if (IS_KEY_W(data)) {
                if (runtimeInputTypeSnapshot == vVNI) {
                    for (j = _index-1; j >= 0; j--) {
                        if (CHR(j) == KEY_O || CHR(j) == KEY_U ||CHR(j) == KEY_A || CHR(j) == KEY_E) {
                            VEI = j;
                            break;
                        }
                    }
                    if ((data == KEY_7 && CHR(VEI) == KEY_A && (VEI-1>=0 ? CHR(VEI-1) != KEY_U : true)) || (data == KEY_8 && (CHR(VEI) == KEY_O || CHR(VEI) == KEY_U)))
                        break;
                }
                insertW(keyForAEO, isCaps);
            }
            break;
        }
    }

    if (!isChanged) {
        if (data == KEY_W && runtimeInputTypeSnapshot != vSimpleTelex1) {
            checkForStandaloneChar(data, isCaps, KEY_U);
        } else {
            insertKey(data, isCaps);
        }
    }
}
