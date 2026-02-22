void checkGrammar(const int& deltaBackSpace) {
    if (_index <= 1 || _index >= MAX_BUFF)
        return;

    findAndCalculateVowel(true);
    if (vowelCount == 0)
        return;

    isCheckedGrammar = false;

    l = VSI;

    //if N key for case: "thuơn", "ưoi", "ưom", "ưoc"
    if (_index >= 3) {
        for (i = _index-1; i >= 0; i--) {
            if (CHR(i) == KEY_N || CHR(i) == KEY_C || CHR(i) == KEY_I ||
                CHR(i) == KEY_M || CHR(i) == KEY_P || CHR(i) == KEY_T) {
                if (i - 2 >= 0 && CHR(i - 1) == KEY_O && CHR(i - 2) == KEY_U) {
                    if ((TypingWord[i-1] & TONEW_MASK) ^ (TypingWord[i-2] & TONEW_MASK)) {
                        TypingWord[i - 2] |= TONEW_MASK;
                        TypingWord[i - 1] |= TONEW_MASK;
                        isCheckedGrammar = true;
                        break;
                    }
                }
            }
        }
    }

    //check mark
    if (_index >= 2) {
        for (i = l; i <= VEI; i++) {
            if (TypingWord[i] & MARK_MASK) {
                // If word ends with a repeated vowel run (e.g., "iuu", "aa"),
                // keep the mark at its current position (base vowel cluster).
                int tailStart = VEI;
                int tailLen = 1;
                if (VEI > VSI) {
                    Uint16 tailVowel = CHR(VEI);
                    while (tailStart > VSI && CHR(tailStart - 1) == tailVowel) {
                        tailStart--;
                    }
                    tailLen = VEI - tailStart + 1;
                }
                if (tailLen >= 2 && i <= tailStart) {
                    isCheckedGrammar = false;
                    break;
                }

                // Check for extended vowels (consecutive same vowels like "ee", "aa")
                // If the marked vowel is followed by the same vowel(s), keep mark at first position
                // Example: "nhé" + "e" => "nhée" (not "nheé"), "á" + "aa" => "áaa" (not "aáa")
                bool isExtendedVowel = false;
                if (i < VEI && CHR(i) == CHR(i + 1)) {
                    // Check if all following vowels are the same
                    isExtendedVowel = true;
                    for (int checkIdx = i + 1; checkIdx <= VEI; checkIdx++) {
                        if (CHR(checkIdx) != CHR(i)) {
                            isExtendedVowel = false;
                            break;
                        }
                    }
                }

                // If extended vowel, keep mark at current position (first of the sequence)
                if (isExtendedVowel) {
                    // Don't move the mark, just update display
                    isCheckedGrammar = false;
                    break;
                }

                Uint32 mark = TypingWord[i] & MARK_MASK;
                TypingWord[i] &= ~MARK_MASK;
                insertMark(mark, false);
                if (i != vowelWillSetMark)
                    isCheckedGrammar = true;
                break;
            }
        }
    }
    
    //re-arrange data to sendback
    if (isCheckedGrammar) {
        if (hCode ==vDoNothing)
            hCode = vWillProcess;
        hBPC = 0;
        
        for (i = _index - 1; i >= l; i--) {
            hBPC++;
            hData[_index - 1 - i] = GET(TypingWord[i]);
        }
        hNCC = hBPC;
        hBPC += deltaBackSpace;
        hExt = 4;
    }
}

