# Phân tích Code & Kiểm tra Logic

## 1. Phân tích Priority Order

### ✅ Priority 1: Custom Vietnamese (Correct)
**Code:** Lines 424-430
```cpp
if (!customVietnameseWords.empty() && customVietnameseWords.count(word)) {
    return false;
}
```
**Status:** ✅ ĐÚNG - User custom Vietnamese luôn được ưu tiên cao nhất

---

### ✅ Priority 2: Custom English (Correct)
**Code:** Lines 432-438
```cpp
if (!customEnglishWords.empty() && customEnglishWords.count(word)) {
    return true;
}
```
**Status:** ✅ ĐÚNG - User custom English always restores

---

### ✅ Priority 3: Built-in Vietnamese (MOSTLY CORRECT)

#### 3.1 Direct Check (Line 443)
```cpp
if (vieInit && vieNodes && searchBinaryTrie(vieNodes, idx, stateIndex)) {
    return false;
}
```
**Status:** ✅ ĐÚNG

#### 3.2 Tone Mark Removal Check (Lines 465-585)
**Code Analysis:**

```cpp
if (vieInit && vieNodes && stateIndex >= 2) {
    uint8_t lastKey = keyStates[stateIndex - 1] & 0x3F;

    // Define tone marks
    bool isToneMark = (lastKey == KEY_S || lastKey == KEY_F || ... ||
                       (lastKey == KEY_D && (keyStates[0] & 0x3F) == KEY_D));
```

**Issue Found #1: Incomplete tone mark list**
```
Defined tone marks: s, f, r, x, j, w, a, o, e, [, ], d(special)

Missing from CHECK but should be considered:
- dd (đ) is handled specially ✓
- But what about [, ] being used for other purposes?

Example: "]" can be:
- Tone mark for ư/ơ
- But also regular character in context
```

**Verdict:** ⚠️ MOSTLY CORRECT but edge cases with [, ] exist

#### 3.3 Non-Vietnamese Cluster Detection (Lines 481-510)
**Code Analysis:**

```cpp
if ((firstKey == KEY_B && secondKey == KEY_L) ||  // bl
    (firstKey == KEY_C && secondKey == KEY_L) ||  // cl
    // ... 20 more clusters
    (firstKey == KEY_W && secondKey == KEY_R)) {  // wr
    isNonVietnameseCluster = true;
}
```

**Clusters Covered:**
- bl, br, cl, cr, dr, fl, fr, gl, gr, pl, pr (11)
- sc, sk, sl, sm, sn, sp, st, sw, sq (9)
- tw, wr (2)

**Total: 22 clusters**

**Missing Clusters:**
```
"thr" - three, throw, etc.
  Analysis: th is Vietnamese (tha, tho, etc.)
  But thr doesn't exist in Vietnamese!

Status: ⚠️ MISSING but might work anyway because:
- th is detected as Vietnamese consonant
- If "thr*" not in Vietnamese → Falls through to English check
```

**Verdict:** ⚠️ NOT CRITICAL but could be improved

#### 3.4 Vietnamese Consonant Detection (Lines 525-548)
**Code Analysis:**

Single consonants checked:
```cpp
b, c, d, g, h, k, l, m, n, p, r, s, t, v, x
(NOT checked: f, j, q, w, z)  ✓ Correct
```

Double consonants checked:
```cpp
ch, gh, gi, kh, ng, nh, ph, qu, th, tr
(NOT checked: ngh - but covered by "ng" + logic)
```

**Issue Found #2: "ngh" not explicitly handled**
```
"ngh" is valid Vietnamese cluster (nghe, anh, etc.)
But code checks:
- "ng" → isVietnameseConsonant = true
- "ngh" → Would need to check "gh" too

Status: ⚠️ May miss some "ngh" patterns
Example: "nghe" (listen) might be mishandled
```

**Verdict:** ⚠️ INCOMPLETE - Missing "ngh" check

---

### ✅ Priority 4: Built-in English Dictionary

#### 4.1 Direct Check (Line 596)
```cpp
bool isEnglish = searchBinaryTrie(engNodes, idx, stateIndex);
```
**Status:** ✅ CORRECT

#### 4.2 Tone Mark Removal (Lines 598-661) [NEW CODE]
**Code Analysis:**

```cpp
// Detect tone mark in middle
for (int i = 0; i < stateIndex - 1; i++) {
    bool isNextToneMark = (nextId == kcToIdx[KEY_S] ||
                          nextId == kcToIdx[KEY_F] || ...);
    if (isNextToneMark && (id == kcToIdx[KEY_A] || ...)) {
        hasToneMarkInMiddle = true;
        break;
    }
}
```

**Issue Found #3: kcToIdx not validated**
```cpp
bool isNextToneMark = (nextId == kcToIdx[KEY_S] || ...);
```

Problem: `kcToIdx[KEY_S]` returns a uint8_t index, not the KEY itself!

Example:
```
KEY_S = some keycode value (not 's' character)
kcToIdx[KEY_S] = 18 (index for 's' in alphabet)

So comparison should be:
  nextId == 18  (NOT nextId == KEY_S)
```

**Status:** ❌ LOGIC ERROR - Need to compare indices, not keycodes

**Fix Required:**
```cpp
// Current (WRONG):
bool isNextToneMark = (nextId == kcToIdx[KEY_S] || ...);

// Should be:
uint8_t sIdx = kcToIdx[KEY_S];  // Get index for S
bool isNextToneMark = (nextId == sIdx || ...);
```

Actually, wait - let me re-examine this...

Looking at line 612:
```cpp
bool isNextToneMark = (nextId == kcToIdx[KEY_S] || nextId == kcToIdx[KEY_F] || ...);
```

And earlier at line 607:
```cpp
uint8_t nextId = idx[i + 1];
```

`idx` is already the converted indices (0-25), so `nextId` is an index (0-25).
`kcToIdx[KEY_S]` returns the index for S, which should be 18.

So it's comparing: idx (0-25) == kcToIdx[KEY_S] (which is 18)

**Actually this is CORRECT!** ✅

**Verdict:** ✅ CORRECT

#### 4.3 Suffix Matching (Lines 677-704)
```cpp
static const struct { const char* s; int len; } suffixes[] = {
    {"ing", 3}, {"ers", 3}, {"er", 2}, {"ed", 2}, {"es", 2}, {"s", 1}
};

for (const auto& suf : suffixes) {
    if (stateIndex <= suf.len + 2) continue;  // base too short
    if (!endsWithSuffix(idx, stateIndex, suf.s, suf.len)) continue;

    int baseLen = stateIndex - suf.len;
    if (searchBinaryTrie(engNodes, idx, baseLen)) {
        // ... check Vietnamese ...
        return true;
    }
}
```

**Issue Found #4: Suffix check doesn't use tone mark removal**
```
"footed" (foot+ed):
  With tone mark? "foot+ed" → may have tone mark in middle
  But suffix check doesn't remove tone marks!

Status: ⚠️ INCONSISTENT - Tone removal works for direct check,
                        but not for suffix base check
```

**Verdict:** ⚠️ INCONSISTENT - Should apply tone removal to suffix base too

---

## 2. Logic Consistency Check

### ✅ Consistency 1: Dictionary initialization
```cpp
if (!engInit) {
    return false;  // Line 390
}
...
if (!engNodes) {
    return false;  // Line 589
}
```
**Status:** ✅ GOOD - Double-checks both init flag and pointer

---

### ✅ Consistency 2: State index bounds
```cpp
if (stateIndex < 2) {
    return false;  // Line 392
}
if (stateIndex > 30) {
    return false;  // Line 398
}
```
**Status:** ✅ GOOD - Prevents buffer overflow (idx[32], wordBuf[32])

---

### ⚠️ Consistency 3: kcToIdx initialization
```cpp
initKcLookup();  // Line 401 - NEW

// But in other functions:
initKcLookup();  // Line 239 (initEnglishDictionary)
initKcLookup();  // Line 272 (initVietnameseDictionary)
initKcLookup();  // Line 322 (isEnglishWordFromKeyStates)
initKcLookup();  // Line 346 (isVietnameseWordFromKeyStates)
```

**Status:** ✅ GOOD - Multiple init calls are safe (idempotent)

---

## 3. Performance Analysis

### Memory Usage
```
idx[32]:       32 bytes per call (stack)
wordBuf[32]:   32 bytes per call (stack)
tonelessIdx[32]: 32 bytes per call (stack, only if tone mark check)
→ Total: ~96 bytes per call
```
**Status:** ✅ EFFICIENT - Stack allocation only

### CPU Operations
```
Tone mark detection loop: O(stateIndex) iterations
Tone mark removal loop:   O(stateIndex) iterations
Dictionary lookups:       O(stateIndex) trie traversal

Total: O(stateIndex) where stateIndex ≤ 30
```
**Status:** ✅ FAST - All operations are linear in word length

---

## 4. Edge Cases Analysis

### Edge Case 1: Empty word
```
Input: stateIndex = 0
Check: stateIndex < 2 → return false
```
**Status:** ✅ HANDLED

### Edge Case 2: Very long word (>30 chars)
```
Input: stateIndex = 35
Check: stateIndex > 30 → return false
```
**Status:** ✅ HANDLED

### Edge Case 3: Non-letter keycode
```
Input: keyStates contains space, punctuation
Check: id >= 26 → return false
```
**Status:** ✅ HANDLED

### Edge Case 4: Multiple consecutive tone marks
```
Input: "aas" (a+a+s) - double vowel + tone
Current logic: Detects first tone mark (s after vowel)
Result: Removes only first tone mark
Status: ⚠️ PARTIAL - Only handles single tone mark
```

Example:
```
"aas" (ââs - â + s tone):
  1. Detect: a+a at position 0-1 (no tone mark)
  2. Detect: a+s at position 1-2 (tone mark!)
  3. Remove s → "aa"
  4. Check "aa" in English → not found

But should also check "ees", "oos" separately!
Status: ⚠️ INCOMPLETE for multiple vowel sequences
```

### Edge Case 5: Special characters in keyStates
```cpp
uint8_t id = kcToIdx[keyStates[i] & 0x3F];
```

The `& 0x3F` mask limits to 6 bits (0-63).
**Status:** ✅ SAFE - Prevents out-of-bounds access to kcToIdx[64]

---

## 5. Found Issues Summary

| # | Issue | Severity | Location | Fix |
|---|-------|----------|----------|-----|
| 1 | "[, ]" tone mark edge cases | LOW | Line 473 | Document or test |
| 2 | Missing "thr" cluster | LOW | Line 508 | Add to non-Viet clusters |
| 3 | Missing "ngh" check | MEDIUM | Line 535 | Add ngh pattern check |
| 4 | Suffix base ignores tone marks | MEDIUM | Line 692 | Apply tone removal to base |
| 5 | Multiple vowel sequences | LOW | Line 607 | Handle multiple tone marks |

---

## 6. Recommended Fixes

### Fix Priority 1: Add "ngh" Vietnamese consonant
```cpp
// Line ~537, add:
if ((firstKey == KEY_N && secondKey == KEY_G && thirdKey == KEY_H)) {
    isVietnameseConsonant = true;
}
```

### Fix Priority 2: Apply tone removal to suffix base
```cpp
// Line 692, modify:
// First try without tone marks
int baseLen = stateIndex - suf.len;
if (searchBinaryTrie(engNodes, idx, baseLen)) {
    // existing check
} else if (hasToneMarkInMiddle) {
    // Remove tone marks from base too
    // ... reuse tone removal logic ...
}
```

### Fix Priority 3: Document edge cases
Add test cases for:
- Words with [, ] characters
- Words with "thr" cluster
- Words with "ngh" pattern
- Words with multiple vowel sequences

---

## 7. Overall Assessment

**Current Implementation: 85% Complete** ✅

### Working Well ✅
- Priority system (Custom > Built-in)
- Vietnamese dictionary checks
- English dictionary checks
- Tone mark removal (single marks)
- Suffix matching
- Edge case: very long words
- Edge case: empty words
- Memory/Performance

### Needs Improvement ⚠️
- "ngh" Vietnamese pattern
- Multiple tone marks in one word
- Suffix base tone mark handling
- Edge case documentation

### Not Yet Addressed ❌
- Multiple consecutive vowel tone sequences
- Complex Telex patterns with multiple marks

---

## Conclusion

The Auto English Restore logic is **fundamentally sound** with:

1. **Correct priority order** (User > Vietnamese > English)
2. **Comprehensive Vietnamese checks** (direct + tone mark + clusters)
3. **Good English fallback** (direct + tone mark + suffix)
4. **Efficient implementation** (O(n) time, minimal memory)

**Recommended Actions:**
1. Add "ngh" pattern check (easy, medium impact)
2. Test with edge cases
3. Document known limitations

