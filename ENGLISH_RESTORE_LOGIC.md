# Nguyên lý hoạt động của chức năng tự khôi phục tiếng Anh

## Tổng quan

Chức năng "Auto English Restore" của PHTV tự động phát hiện và khôi phục các từ tiếng Anh mà người dùng gõ nhưng bị lỡ biến thành "tiếng Việt". Điều này xảy ra vì:

1. Khi gõ bằng Telex, một số chuỗi phím sẽ tạo dấu Vietnamese
2. Ví dụ: "e" + "s" → "é" (e + sắc tone)
3. Engine cần phát hiện đây là tiếng Anh, không phải tiếng Việt, và khôi phục

---

## Kiến trúc quyết định (Decision Flow)

### 📊 Sơ đồ ưu tiên

```
Từ tiếng Anh cần khôi phục?
    ↓
┌─────────────────────────────────────┐
│ PRIORITY 1: Custom Vietnamese       │  ← User đánh dấu là Việt?
│ (User-defined blacklist)            │    → KHÔNG khôi phục (false)
└─────────────────────────────────────┘
    ↓ (Nếu không có)
┌─────────────────────────────────────┐
│ PRIORITY 2: Custom English          │  ← User đánh dấu là English?
│ (User-defined whitelist)            │    → KHÔI PHỤC (true)
└─────────────────────────────────────┘
    ↓ (Nếu không có)
┌─────────────────────────────────────┐
│ PRIORITY 3: Built-in Vietnamese     │  ← Có trong từ điển Việt?
│ Dictionary Check                    │    → KHÔNG khôi phục (false)
│ - Direct check                      │
│ - Check with tone mark removal      │
│ - Check with non-Vietnamese cluster │
└─────────────────────────────────────┘
    ↓ (Nếu không có trong Vietnamese)
┌─────────────────────────────────────┐
│ PRIORITY 4: Built-in English        │  ← Có trong từ điển English?
│ Dictionary Check                    │    → KHÔI PHỤC (true)
│ - Direct check                      │
│ - Check with tone mark removal      │
│ - Check with suffix matching        │
└─────────────────────────────────────┘
    ↓ (Nếu không có)
    KHÔNG khôi phục (false)
```

---

## Chi tiết từng Priority Level

### Priority 1: Custom Vietnamese Dictionary (User Blacklist)
**File:** `EnglishWordDetector.cpp`, dòng 424-430

```cpp
// PRIORITY 1: Check custom Vietnamese - if user marked as Vietnamese, never restore
if (!customVietnameseWords.empty() && customVietnameseWords.count(word)) {
    return false;  // User explicitly marked as Vietnamese - do NOT restore
}
```

**Mục đích:**
- Tôn trọng lựa chọn người dùng
- Nếu người dùng đánh dấu một từ là tiếng Việt, **LUÔN** không khôi phục

**Ví dụ:**
- User đánh dấu "fix" → "fix" được coi là tiếng Việt → Không khôi phục

---

### Priority 2: Custom English Dictionary (User Whitelist)
**File:** `EnglishWordDetector.cpp`, dòng 432-438

```cpp
// PRIORITY 2: Check custom English - if user marked as English, always restore
if (!customEnglishWords.empty() && customEnglishWords.count(word)) {
    return true;  // User explicitly marked as English - restore
}
```

**Mục đích:**
- Cho phép user ghi đè lựa chọn tự động
- Nếu user đánh dấu một từ là tiếng Anh, **LUÔN** khôi phục

**Ví dụ:**
- User đánh dấu "vinfast" (thương hiệu) → Custom English → Khôi phục

---

### Priority 3: Built-in Vietnamese Dictionary
**File:** `EnglishWordDetector.cpp`, dòng 440-585

Đây là phần **quan trọng nhất** vì tiếng Việt được ưu tiên cao hơn tiếng Anh.

#### 3.1: Kiểm tra trực tiếp (Direct Check)
```cpp
// PRIORITY 3: Check built-in Vietnamese dictionary FIRST
if (vieInit && vieNodes && searchBinaryTrie(vieNodes, idx, stateIndex)) {
    return false;  // It's a Vietnamese word - do NOT restore
}
```

**Ví dụ:**
- Từ "không" → Tìm thấy trong từ điển Việt → KHÔNG khôi phục

#### 3.2: Kiểm tra với loại bỏ dấu tone mark (Tone Mark Removal)
**File:** `EnglishWordDetector.cpp`, dòng 465-585

**Vấn đề:** Khi người dùng gõ từ tiếng Việt với dấu, nó có thể có tone mark ở cuối:
```
Gõ "đi" (d + i + d):
  KeyStates = [D, I, D]
  Từ điển Việt chỉ có "di" (2 ký tự), không có "did" (3 ký tự)
  → Cần loại bỏ D cuối (tone mark) rồi check lại
```

**Logic:**

```
Nếu ký tự cuối là tone mark (s, f, r, x, j, w, a, o, e, [, ])
  AND từ bắt đầu bằng nguyên âm/phụ âm tiếng Việt:
    → Check "di" thay vì "did"
    → Nếu "di" có trong từ điển Việt → KHÔNG khôi phục
```

**Các tone mark Telex:**
| Phím | Tên | Ký hiệu |
|------|-----|---------|
| s | sắc | ´ |
| f | huyền | ` |
| r | hỏi | ? |
| x | ngã | ~ |
| j | nặng | . |
| w | horn (ơ, ư) | ^ |
| a, o, e | circumflex (â, ê, ô) | ^ |
| [, ] | brevis/horn | ^ |

**Ví dụ case này:**
```
"did" (d+i+d):
  1. Check "did" trong Việt → KHÔNG có
  2. Detect: D cuối = tone mark
  3. Check: firstKey = D (Vietnamese consonant)
  4. Check "di" (bỏ D cuối) → CÓ trong Việt
  5. → KHÔNG khôi phục "did"
```

#### 3.3: Kiểm tra cụm phụ âm không phải tiếng Việt
**File:** `EnglishWordDetector.cpp`, dòng 481-510

**Vấn đề:** Một số cụm phụ âm chỉ tồn tại trong tiếng Anh:

```
"clear" (c+l+e+a+r):
  1. Detect tone mark? → KHÔNG (r là phụ âm, không phải tone mark)
  2. Nhưng "cl" là cụm không có trong tiếng Việt
  3. → Bỏ qua kiểm tra tone mark, đi thẳng check English
```

**Các cụm không phải Việt:**
- Đầu từ: bl, br, cl, cr, dr, fl, fr, gl, gr, pl, pr
- Với s: sc, sk, sl, sm, sn, sp, st, sw, sq
- Khác: tw, wr

---

### Priority 4: Built-in English Dictionary
**File:** `EnglishWordDetector.cpp`, dòng 587-704

#### 4.1: Kiểm tra trực tiếp
```cpp
bool isEnglish = searchBinaryTrie(engNodes, idx, stateIndex);
if (isEnglish) return true;  // Found in English dictionary → RESTORE
```

#### 4.2: Loại bỏ dấu tone mark ở giữa từ (NEW FIX - Issue #57)
**File:** `EnglishWordDetector.cpp`, dòng 598-661

**Vấn đề gốc:**
```
"livestream" gõ thành "l+i+v+e+s+t+r+e+a+m":
  Người dùng vô tình gõ "e+s" → tạo "é"
  Output hiển thị: "livétream"

Trước đó:
  1. Check "livestream" → CÓ (trong dictionary)
  2. Check "livestream" trong Việt → KHÔNG
  3. → KHÔI PHỤC thành "livestream" ✓

Nhưng nếu "livestream" KHÔNG trong dictionary:
  1. Check "livestream" → KHÔNG CÓ
  2. → KHÔNG khôi phục ✗
```

**Giải pháp:**
```
Nếu từ KHÔNG tìm thấy trong English:
  1. Detect: Có tone mark (s, f, r, x, j, w) ở giữa từ?
  2. Nếu có → Loại bỏ tone mark
  3. Check từ không dấu trong English
  4. Nếu có → KHÔI PHỤC
```

**Ví dụ:**
```
"livestream" (l+i+v+e+s+t+r+e+a+m):
  1. Check "livestream" → KHÔNG có (hoặc không lúc này)
  2. Detect: s sau e (vowel) = tone mark
  3. Loại bỏ s → "livestream"
  4. Check "livestream" → CÓ
  5. Check "livestream" trong Việt → KHÔNG
  6. → KHÔI PHỤC ✓
```

#### 4.3: Kiểm tra suffix (Suffix Matching)
**File:** `EnglishWordDetector.cpp`, dòng 677-704

**Vấn đề:**
```
"footer" (foot + er):
  - "footer" có thể không có trong dictionary
  - Nhưng "foot" + "er" là cấu trúc English phổ biến
```

**Các suffix được hỗ trợ:**
- ing (3 ký tự)
- ers (3 ký tự)
- er (2 ký tự)
- ed (2 ký tự)
- es (2 ký tự)
- s (1 ký tự)

---

## Các Edge Case & Xử lý đặc biệt

### Edge Case 1: "did" vs "fix"
**Vấn đề:** Cả hai có D, nhưng D có ý nghĩa khác nhau:
- "did": D cuối = tone mark (đi → di + d tone)
- "fix": x cuối = tone mark (é → e + s tone)

**Giải pháp:**
```cpp
// Chỉ treat D cuối là tone mark nếu D đầu cũng là D
(lastKey == KEY_D && (keyStates[0] & 0x3F) == KEY_D)
```

### Edge Case 2: "theme" vs "therefore"
**Vấn đề:**
```
"theme" (t+h+e+m+e):
  1. th = Vietnamese consonant
  2. e+m+e = CÓ tone mark?
  3. "the" (bỏ m) → CÓ trong Việt? Không
  4. → Kiểm tra English

"therefore" (t+h+e+r+e+f+o+r+e):
  1. th = Vietnamese consonant
  2. Có tone mark e+r và e+f?
  3. "therefoe" (bỏ r, f) → CÓ trong Việt? Không
  4. → Kiểm tra English
```

### Edge Case 3: Vốn phụ âm vs Vốn nguyên âm
**Vấn đề:**
```
"aws" (a+w+s):
  - a = Vietnamese vowel
  - w+s = tone mark (ă)
  → Coi như tiếng Việt

"fix" (f+i+x):
  - f = NOT Vietnamese consonant
  - i+x = tone mark (í)
  → Bỏ qua tone mark check → Check English
```

---

## Quy trình hoàn chỉnh (Step-by-step Example)

### Ví dụ: "livestream"

**Input:** Người dùng gõ l-i-v-e-s-t-r-e-a-m

```
Step 1: KeyStates = [L, I, V, E, S, T, R, E, A, M]
        Chuyển thành từ = "livestream"

Step 2: Priority 1 - Custom Vietnamese?
        customVietnameseWords.count("livestream") → 0 (không)
        → Continue

Step 3: Priority 2 - Custom English?
        customEnglishWords.count("livestream") → 0 (không)
        → Continue

Step 4: Priority 3 - Built-in Vietnamese?
        searchBinaryTrie(vieNodes, "livestream") → false (không có)

        Kiểm tra tone mark:
        - lastKey = M (không phải tone mark)
        - Skip tone mark logic
        → Continue

Step 5: Priority 4 - Built-in English?
        searchBinaryTrie(engNodes, "livestream") → true (CÓ!)
        → RETURN true (KHÔI PHỤC)

Output: "livestream" được khôi phục ✓
```

### Ví dụ: "did"

**Input:** Người dùng gõ d-i-d

```
Step 1: KeyStates = [D, I, D]
        Chuyển thành từ = "did"

Step 2: Priority 1 - Custom Vietnamese?
        customVietnameseWords.count("did") → 0
        → Continue

Step 3: Priority 2 - Custom English?
        customEnglishWords.count("did") → 0
        → Continue

Step 4: Priority 3 - Built-in Vietnamese?
        searchBinaryTrie(vieNodes, "did") → false

        Kiểm tra tone mark:
        - lastKey = D
        - isToneMark? → YES (D cuối và D đầu)
        - firstKey = D (Vietnamese consonant)
        - Check "di" (bỏ D cuối):
          searchBinaryTrie(vieNodes, "di") → true (CÓ - đi!)
        → RETURN false (KHÔNG KHÔI PHỤC)

Output: "did" KHÔNG được khôi phục, giữ nguyên ✓
```

---

## Hiệu suất (Performance Characteristics)

### Time Complexity
- **O(n)**: Mỗi check là traversal trie có độ sâu = độ dài từ
- Thực tế: **O(word_length)** vì trie lookup là O(k) với k = word length

### Memory
- Dictionary: Binary trie file (74MB English, 1.9MB Vietnamese)
- Lookup: O(1) memory access (memory-mapped file)

### Caching
- `initKcLookup()`: Khởi tạo lookup table một lần → O(1) reuse

---

## Các Case đã test

### ✅ Working (Khôi phục đúng)
```
"livestream"     → "livestream" ✓
"screenshot"     → "screenshot" ✓
"clear"         → "clear" ✓
"search"        → "search" ✓
"footer"        → "footer" ✓
"zoomed"        → "zoomed" ✓
```

### ❌ Blocked (Không khôi phục)
```
"did"           → không khôi phục (đi) ✓
"cos"           → không khôi phục (có) ✓
"max"           → không khôi phục (mã) ✓
"aws"           → không khôi phục (ắ) ✓
"fix" (as Vi)   → không khôi phục (nếu user mark) ✓
```

---

## Tiềm ẩn Issues & Improvements

### Issue 1: Words with multiple tone marks
```
"được" (d+u+o+w+c):
  - u+o = tone mark? (ư)
  - o+w = tone mark? (ơ)
  → Multiple tone marks → Cần cải tiến
```

**Status:** Current code handles first tone mark only

### Issue 2: Compound words
```
"livestream" = "live" + "stream"
  → Both parts English, full word may not be in dictionary
  → Current: check suffix (ing, er, ed, etc.)
  → Improvement: check compound patterns (live+*, *+stream)
```

**Status:** Fixed by adding "livestream" to mandatory_words

### Issue 3: Performance with long words
```
"supercalifragilisticexpialidocious" (34 chars)
  → Trie traversal = O(34)
  → Still fast, but could cache results
```

**Status:** Acceptable for user input (rare >30 chars)

---

## Kết luận

Hệ thống Auto English Restore hoạt động dựa trên **ưu tiên rõ ràng**:

1. **User Custom** (highest priority)
2. **Vietnamese Dictionary** (medium priority)
3. **English Dictionary** (lowest priority)

Điều này đảm bảo:
- ✅ Tiếng Việt luôn được ưu tiên
- ✅ User có thể ghi đè tự động
- ✅ Tiếng Anh vẫn được khôi phục đúng lúc
- ✅ Edge cases (tone marks, clusters) được xử lý

