static inline bool isVietnameseWordFromTypingWord(const int length) {
    if (length <= 0) return false;
    Uint32 buf[32];
    int len = length > 30 ? 30 : length;
    for (int i = 0; i < len; i++) {
        buf[i] = TypingWord[i] & 0x3F;
    }
    return detectorIsVietnameseWordFromKeyStates(buf, len);
}

/**
 * Convert TypingWord back to canonical Telex keycodes and check Vietnamese dictionary.
 * This handles ALL alternative Telex typing orders:
 *   - "dods" (d-o-d-s) → canonical "ddos" (đó) ✓
 *   - "wf" (standalone W+f) → canonical "uwf" (ừ) ✓
 *   - Any reordered Telex pattern that the engine processed correctly
 *
 * Returns true if the canonical Telex form is a Vietnamese word.
 */
static bool isVietnameseFromCanonicalTelex(const int length) {
    if (length <= 0) return false;

    Uint32 buf[64]; // Canonical Telex can be longer than TypingWord
    int len = 0;
    Uint32 toneKey = 0; // Tone mark key to append at end (end-tone variant)

    for (int i = 0; i < length && len < 60; i++) {
        Uint32 tw = TypingWord[i];
        Uint32 baseKey = tw & 0x3F;

        // đ: KEY_D with TONE_MASK → "dd"
        if (baseKey == KEY_D && (tw & TONE_MASK)) {
            buf[len++] = KEY_D;
            buf[len++] = KEY_D;
        }
        // Vowel with TONE_MASK (â, ê, ô) → double the vowel
        else if (!(tw & STANDALONE_MASK) && (tw & TONE_MASK) && !IS_CONSONANT(baseKey)) {
            buf[len++] = baseKey;
            buf[len++] = baseKey;
        }
        // Normal character
        else {
            buf[len++] = baseKey;
        }

        // TONEW_MASK (ă, ơ, ư) → append W
        if (tw & (TONEW_MASK | STANDALONE_MASK)) {
            // For standalone ư (KEY_U with STANDALONE), base is already KEY_U
            // For normal aw/ow/uw, base is the vowel
            if (len < 62) buf[len++] = KEY_W;
        }

        // Collect tone mark (only one per word, applied at end)
        if (tw & MARK1_MASK) toneKey = KEY_S;       // sắc
        else if (tw & MARK2_MASK) toneKey = KEY_F;   // huyền
        else if (tw & MARK3_MASK) toneKey = KEY_R;   // hỏi
        else if (tw & MARK4_MASK) toneKey = KEY_X;   // ngã
        else if (tw & MARK5_MASK) toneKey = KEY_J;   // nặng
    }

    // Append tone mark at end (end-tone variant, always in Vietnamese dictionary)
    if (toneKey && len < 62) {
        buf[len++] = toneKey;
    }

    if (len < 2) return false; // Too short for dictionary lookup
    return detectorIsVietnameseWordFromKeyStates(buf, len);
}
