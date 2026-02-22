static bool canFixVowelWithDiacriticsForMark() {
    // Preserve current vowel scan state (this is a hot path).
    Byte savedVowelCount = vowelCount;
    Byte savedVSI = VSI;
    Byte savedVEI = VEI;

    findAndCalculateVowel();
    if (vowelCount == 0) {
        vowelCount = savedVowelCount;
        VSI = savedVSI;
        VEI = savedVEI;
        return false;
    }

    auto it = _vowelCombine.find(CHR(VSI));
    if (it == _vowelCombine.end()) {
        vowelCount = savedVowelCount;
        VSI = savedVSI;
        VEI = savedVEI;
        return false;
    }

    const vector<vector<Uint32>>& vo = it->second;
    bool canFix = false;
    for (const auto& pattern : vo) {
        int patternLen = (int)pattern.size() - 1; // exclude flag
        if (patternLen < vowelCount) {
            continue;
        }

        bool match = true;
        for (int idx = 0; idx < vowelCount; idx++) {
            Uint32 expected = pattern[idx + 1];
            Uint16 expectedBase = expected & CHAR_MASK;
            Uint16 currentBase = CHR(VSI + idx);

            if (currentBase != expectedBase) {
                match = false;
                break;
            }

            Uint32 expectedTone = expected & (TONE_MASK | TONEW_MASK);
            Uint32 currentTone = TypingWord[VSI + idx] & (TONE_MASK | TONEW_MASK);

            if (expectedTone == 0) {
                if (currentTone != 0) {
                    match = false;
                    break;
                }
            } else {
                if (currentTone != 0 && currentTone != expectedTone) {
                    match = false;
                    break;
                }
            }
        }

        if (match) {
            canFix = true;
            break;
        }
    }

    vowelCount = savedVowelCount;
    VSI = savedVSI;
    VEI = savedVEI;
    return canFix;
}

