#!/usr/bin/env python3
"""
Generate pre-built binary trie for instant loading.
Downloads complete Vietnamese dictionary (74K+ words) and creates optimized binary tries.

Binary Trie Format (PHT3):
- Header: "PHT3" (4 bytes) + node_count (4 bytes) + word_count (4 bytes)
- Nodes: Array of nodes, each node contains:
  - 26 x uint32 child indices (0xFFFFFFFF = no child)
  - 1 byte isEnd flag
  - Total: 105 bytes per node
"""

import struct
import os
import urllib.request
import sys

# Vietnamese character to Telex base mapping
# Maps each Vietnamese character to its Telex raw key sequence
VIET_CHAR_MAP = {
    # a variants
    'a': 'a', 'à': 'af', 'á': 'as', 'ả': 'ar', 'ã': 'ax', 'ạ': 'aj',
    'ă': 'aw', 'ằ': 'awf', 'ắ': 'aws', 'ẳ': 'awr', 'ẵ': 'awx', 'ặ': 'awj',
    'â': 'aa', 'ầ': 'aaf', 'ấ': 'aas', 'ẩ': 'aar', 'ẫ': 'aax', 'ậ': 'aaj',
    # e variants
    'e': 'e', 'è': 'ef', 'é': 'es', 'ẻ': 'er', 'ẽ': 'ex', 'ẹ': 'ej',
    'ê': 'ee', 'ề': 'eef', 'ế': 'ees', 'ể': 'eer', 'ễ': 'eex', 'ệ': 'eej',
    # i variants
    'i': 'i', 'ì': 'if', 'í': 'is', 'ỉ': 'ir', 'ĩ': 'ix', 'ị': 'ij',
    # o variants
    'o': 'o', 'ò': 'of', 'ó': 'os', 'ỏ': 'or', 'õ': 'ox', 'ọ': 'oj',
    'ô': 'oo', 'ồ': 'oof', 'ố': 'oos', 'ổ': 'oor', 'ỗ': 'oox', 'ộ': 'ooj',
    'ơ': 'ow', 'ờ': 'owf', 'ớ': 'ows', 'ở': 'owr', 'ỡ': 'owx', 'ợ': 'owj',
    # u variants
    'u': 'u', 'ù': 'uf', 'ú': 'us', 'ủ': 'ur', 'ũ': 'ux', 'ụ': 'uj',
    'ư': 'uw', 'ừ': 'uwf', 'ứ': 'uws', 'ử': 'uwr', 'ữ': 'uwx', 'ự': 'uwj',
    # y variants
    'y': 'y', 'ỳ': 'yf', 'ý': 'ys', 'ỷ': 'yr', 'ỹ': 'yx', 'ỵ': 'yj',
    # đ
    'đ': 'dd',
}

# Add uppercase versions
for char, telex in list(VIET_CHAR_MAP.items()):
    upper = char.upper()
    if upper != char:
        VIET_CHAR_MAP[upper] = telex

def vietnamese_to_telex_variants(word):
    """
    Convert Vietnamese word to ALL possible Telex raw key sequences.
    Returns list of variants:
    - Inline tone: "còn" -> "cofn" (tone right after vowel)
    - End tone: "còn" -> "conf" (tone at end of word)
    - Base only: "con" -> "con" (no tone)
    """
    base_chars = []
    tones = []

    for char in word:
        if char in VIET_CHAR_MAP:
            telex = VIET_CHAR_MAP[char]
            # Separate base and tone
            if len(telex) >= 2 and telex[-1] in 'fsrxj':
                base_chars.append(telex[:-1])
                tones.append(telex[-1])
            else:
                base_chars.append(telex)
        elif char.isascii() and char.isalpha():
            base_chars.append(char.lower())
        else:
            return []  # Invalid character

    if not base_chars:
        return []

    base_word = ''.join(base_chars)
    variants = set()

    # Always add base word (no tone version)
    variants.add(base_word)

    if tones:
        # Variant 1: Inline tone (original position) - "cofn"
        inline = []
        tone_idx = 0
        for char in word:
            if char in VIET_CHAR_MAP:
                telex = VIET_CHAR_MAP[char]
                inline.append(telex)
            elif char.isascii() and char.isalpha():
                inline.append(char.lower())
        variants.add(''.join(inline))

        # Variant 2: All tones at end - "conf"
        variants.add(base_word + ''.join(tones))

        # Variant 3: Single tone at end (for words with one tone)
        if len(tones) == 1:
            variants.add(base_word + tones[0])

    return list(variants)

def vietnamese_to_telex(word):
    """
    Convert Vietnamese word to Telex raw key sequence (primary variant).
    For backwards compatibility - returns inline tone version.
    """
    variants = vietnamese_to_telex_variants(word)
    return variants[0] if variants else None

class TrieNode:
    __slots__ = ['children', 'is_end', 'index']
    def __init__(self):
        self.children = [None] * 26
        self.is_end = False
        self.index = 0

class Trie:
    def __init__(self):
        self.root = TrieNode()
        self.nodes = [self.root]
        self.word_count = 0

    def insert(self, word):
        """Insert a word (must be lowercase a-z only). Returns True if new word added."""
        node = self.root
        for c in word:
            idx = ord(c) - ord('a')
            if idx < 0 or idx >= 26:
                return False
            if node.children[idx] is None:
                new_node = TrieNode()
                new_node.index = len(self.nodes)
                self.nodes.append(new_node)
                node.children[idx] = new_node
            node = node.children[idx]
        if not node.is_end:
            node.is_end = True
            self.word_count += 1
            return True
        return False

    def serialize(self):
        """Serialize trie to binary format (PHT3 - uint32 indices)."""
        data = bytearray()
        for node in self.nodes:
            for i in range(26):
                if node.children[i] is not None:
                    data.extend(struct.pack('<I', node.children[i].index))
                else:
                    data.extend(struct.pack('<I', 0xFFFFFFFF))
            data.append(1 if node.is_end else 0)
        return bytes(data)

def write_binary_trie(trie, output_path):
    """Write trie to binary file with PHT3 format."""
    with open(output_path, 'wb') as f:
        f.write(b'PHT3')
        f.write(struct.pack('<I', len(trie.nodes)))
        f.write(struct.pack('<I', trie.word_count))
        f.write(trie.serialize())

    file_size = os.path.getsize(output_path)
    print(f"  ✓ Nodes: {len(trie.nodes):,}, Words: {trie.word_count:,}, Size: {file_size:,} bytes")
    return file_size

def download_file(url, dest):
    """Download file from URL with progress indicator."""
    print(f"  Downloading from {url}...")
    try:
        urllib.request.urlretrieve(url, dest)
        return True
    except Exception as e:
        print(f"  ✗ Download failed: {e}")
        return False

def build_english_dictionary(resources_dir):
    """Build English dictionary binary with common words only."""
    print("\n" + "="*60)
    print("BUILDING ENGLISH DICTIONARY")
    print("="*60)

    output_path = os.path.join(resources_dir, 'en_dict.bin')

    # Download common English words (prioritize frequency lists)
    temp_file = '/tmp/en_words_full.txt'

    # Priority: frequency-based lists (common programming/tech words)
    urls_priority = [
        # Google 10K most common (highest priority)
        ('https://raw.githubusercontent.com/first20hours/google-10000-english/master/google-10000-english.txt', 10000),
        # MIT word list (common words)
        ('https://www.mit.edu/~ecprice/wordlist.10000', 10000),
    ]

    words = set()

    # Blacklist: Vietnamese abbreviations that should NOT be in English dictionary
    # These are common Vietnamese texting shortcuts that conflict with Text Replacement
    blacklist = {
        'dc',    # được (Vietnamese)
        'ko',    # không (Vietnamese)
        'k',     # không (Vietnamese)
        'dc',    # được (Vietnamese - texting)
        'dk',    # được không (Vietnamese - texting)
        'cx',    # cũng (Vietnamese - texting)
        'nx',    # nữa (Vietnamese - texting)
        'vs',    # với (Vietnamese - texting)
        'ms',    # mới (Vietnamese - texting)
        'cs',    # chỉ (Vietnamese - texting)
    }

    for url, limit in urls_priority:
        if download_file(url, temp_file):
            count = 0
            with open(temp_file, 'r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    word = line.strip().lower()
                    if word and 2 <= len(word) <= 20:  # Limit word length
                        if word not in blacklist and all(c.isalpha() and c.isascii() for c in word):
                            words.add(word)
                            count += 1
                            if count >= limit:
                                break
            print(f"  Loaded {len(words):,} words so far")

    # Also check local file
    local_en = os.path.join(resources_dir, 'en_words.txt')
    if os.path.exists(local_en):
        with open(local_en, 'r', encoding='utf-8') as f:
            for line in f:
                word = line.strip().lower()
                if word and 2 <= len(word) <= 20:
                    if word not in blacklist and all(c.isalpha() and c.isascii() for c in word):
                        words.add(word)
        print(f"  Added local words, total: {len(words):,}")

    if not words:
        print("  ✗ No English words found!")
        return False

    # Build trie
    print(f"  Building trie with {len(words):,} unique words...")
    trie = Trie()
    for word in sorted(words):
        trie.insert(word)

    write_binary_trie(trie, output_path)

    # Cleanup temp file
    if os.path.exists(temp_file):
        os.remove(temp_file)

    return True

def build_vietnamese_dictionary(resources_dir):
    """Build Vietnamese dictionary binary with complete word list."""
    print("\n" + "="*60)
    print("BUILDING VIETNAMESE DICTIONARY")
    print("="*60)

    output_path = os.path.join(resources_dir, 'vi_dict.bin')

    # Download complete Vietnamese word list (74K+ words)
    temp_file = '/tmp/vi_words_full.txt'
    urls = [
        'https://vietnamese-wordlist.duyet.net/Viet74K.txt',
    ]

    vietnamese_words = set()

    # Add common Vietnamese single-syllable words that might be missing
    common_vi_words = [
        # Common words
        'và', 'của', 'có', 'các', 'là', 'được', 'trong', 'cho', 'không', 'người',
        'với', 'một', 'đã', 'công', 'để', 'những', 'khi', 'đến', 'về', 'này',
        'như', 'từ', 'theo', 'trên', 'tại', 'sau', 'cũng', 'hay', 'còn', 'nhiều',
        'ra', 'đi', 'làm', 'nên', 'thì', 'mà', 'đó', 'sẽ', 'hơn', 'vào',
        'nếu', 'rất', 'hoặc', 'vì', 'bị', 'lại', 'qua', 'năm', 'nước', 'đây',
        'hết', 'ai', 'gì', 'đâu', 'bao', 'sao', 'nào', 'thế', 'vậy', 'đều',
        # Pronouns
        'tôi', 'bạn', 'anh', 'chị', 'em', 'ông', 'bà', 'cô', 'chú', 'bác',
        'họ', 'chúng', 'mình', 'ta', 'nó', 'hắn', 'ấy', 'kia', 'đấy',
        # Common verbs
        'ăn', 'uống', 'ngủ', 'đọc', 'viết', 'nói', 'nghe', 'xem', 'nhìn', 'thấy',
        'biết', 'hiểu', 'nghĩ', 'muốn', 'cần', 'phải', 'nên', 'được', 'bị',
        'yêu', 'ghét', 'sợ', 'vui', 'buồn', 'khóc', 'cười', 'chạy', 'đi', 'đứng',
        'ngồi', 'nằm', 'bay', 'bơi', 'leo', 'nhảy', 'đánh', 'bắt', 'giữ', 'mở',
        'đóng', 'kéo', 'đẩy', 'nâng', 'hạ', 'gọi', 'hỏi', 'trả', 'lời', 'đáp',
        'dùng', 'bỏ', 'lấy', 'cho', 'tặng', 'mua', 'bán', 'thuê', 'trả', 'vay',
        'gửi', 'nhận', 'đem', 'mang', 'chở', 'giao', 'nhập', 'xuất',
        # Common nouns
        'nhà', 'cửa', 'đường', 'phố', 'xe', 'tàu', 'máy', 'điện', 'nước', 'lửa',
        'đất', 'trời', 'mây', 'mưa', 'gió', 'nắng', 'sấm', 'chớp', 'tuyết', 'sương',
        'cây', 'hoa', 'lá', 'quả', 'rau', 'củ', 'hạt', 'gạo', 'cơm', 'thịt',
        'cá', 'trứng', 'sữa', 'bánh', 'kẹo', 'rượu', 'bia', 'trà', 'cà', 'phê',
        'bàn', 'ghế', 'giường', 'tủ', 'kệ', 'đèn', 'quạt', 'ti', 'vi', 'máy',
        'sách', 'vở', 'bút', 'thước', 'kéo', 'dao', 'kìm', 'búa', 'đinh', 'ốc',
        'áo', 'quần', 'váy', 'giày', 'dép', 'mũ', 'nón', 'kính', 'túi', 'ví',
        'tay', 'chân', 'đầu', 'mắt', 'mũi', 'miệng', 'tai', 'tóc', 'răng', 'lưỡi',
        'tim', 'gan', 'phổi', 'thận', 'ruột', 'dạ', 'máu', 'xương', 'da', 'thịt',
        # Adjectives
        'tốt', 'xấu', 'đẹp', 'xinh', 'cao', 'thấp', 'to', 'nhỏ', 'dài', 'ngắn',
        'rộng', 'hẹp', 'dày', 'mỏng', 'nặng', 'nhẹ', 'cứng', 'mềm', 'nóng', 'lạnh',
        'ấm', 'mát', 'khô', 'ướt', 'sạch', 'bẩn', 'mới', 'cũ', 'già', 'trẻ',
        'nhanh', 'chậm', 'sớm', 'muộn', 'đúng', 'sai', 'thật', 'giả', 'khó', 'dễ',
        # Numbers
        'một', 'hai', 'ba', 'bốn', 'năm', 'sáu', 'bảy', 'tám', 'chín', 'mười',
        'trăm', 'nghìn', 'vạn', 'triệu', 'tỷ',
        # Time
        'giờ', 'phút', 'giây', 'ngày', 'đêm', 'sáng', 'trưa', 'chiều', 'tối',
        'tuần', 'tháng', 'năm', 'mùa', 'xuân', 'hạ', 'thu', 'đông',
        # Programming terms (Vietnamese)
        'mã', 'lỗi', 'chạy', 'dừng', 'lưu', 'xóa', 'tìm', 'sửa', 'thêm', 'bớt',
        'tệp', 'thư', 'mục', 'ổ', 'đĩa', 'ảnh', 'video', 'nhạc', 'phim',
    ]
    vietnamese_words.update(common_vi_words)
    print(f"  Added {len(common_vi_words)} common words")

    for url in urls:
        if download_file(url, temp_file):
            with open(temp_file, 'r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    # Each line may contain a phrase, split into individual words
                    line = line.strip()
                    if not line:
                        continue

                    # Split by space/hyphen to get individual words
                    parts = line.replace('-', ' ').split()
                    for word in parts:
                        word = word.strip()
                        if word and len(word) >= 1:
                            vietnamese_words.add(word)

            print(f"  Loaded {len(vietnamese_words):,} Vietnamese words total")
            break  # Use first successful download

    # Also check local file
    local_vi = os.path.join(resources_dir, 'vi_words.txt')
    if os.path.exists(local_vi):
        with open(local_vi, 'r', encoding='utf-8') as f:
            for line in f:
                word = line.strip()
                if word:
                    for part in word.replace('-', ' ').split():
                        if part:
                            vietnamese_words.add(part)
        print(f"  Added local words, total: {len(vietnamese_words):,}")

    if not vietnamese_words:
        print("  ✗ No Vietnamese words found!")
        return False

    # Convert to Telex (ALL variants) and build trie
    print(f"  Converting {len(vietnamese_words):,} words to Telex (all variants)...")
    trie = Trie()
    telex_words = set()

    for word in vietnamese_words:
        # Get ALL variants (inline tone, end tone, base)
        variants = vietnamese_to_telex_variants(word)
        for telex in variants:
            if telex and 2 <= len(telex) <= 30:
                if all(c.isalpha() and c.isascii() for c in telex):
                    telex_words.add(telex)

    print(f"  Generated {len(telex_words):,} unique Telex patterns (with variants)")

    for word in sorted(telex_words):
        trie.insert(word)

    write_binary_trie(trie, output_path)

    # Print some examples with ALL variants
    print("\n  Sample conversions (all variants):")
    test_words = ['còn', 'công', 'được', 'không', 'đến']
    for w in test_words:
        variants = vietnamese_to_telex_variants(w)
        print(f"    {w} → {variants}")

    # Cleanup temp file
    if os.path.exists(temp_file):
        os.remove(temp_file)

    return True

def cleanup_txt_files(resources_dir):
    """Remove old txt files after successful binary generation."""
    print("\n" + "="*60)
    print("CLEANUP")
    print("="*60)

    txt_files = ['en_words.txt', 'vi_words.txt']
    for filename in txt_files:
        filepath = os.path.join(resources_dir, filename)
        if os.path.exists(filepath):
            os.remove(filepath)
            print(f"  ✓ Removed {filename}")
        else:
            print(f"  - {filename} not found (already removed)")

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    resources_dir = os.path.join(script_dir, '..', 'Resources')

    print("="*60)
    print("PHTV Dictionary Generator")
    print("="*60)
    print(f"Resources directory: {resources_dir}")

    # Build dictionaries
    en_ok = build_english_dictionary(resources_dir)
    vi_ok = build_vietnamese_dictionary(resources_dir)

    if en_ok and vi_ok:
        # Ask before cleanup
        if len(sys.argv) > 1 and sys.argv[1] == '--cleanup':
            cleanup_txt_files(resources_dir)
        else:
            print("\n  Run with --cleanup to remove txt files")

    print("\n" + "="*60)
    print("DONE!")
    print("="*60)

    # Show final file sizes
    for name in ['en_dict.bin', 'vi_dict.bin']:
        path = os.path.join(resources_dir, name)
        if os.path.exists(path):
            size = os.path.getsize(path)
            print(f"  {name}: {size:,} bytes ({size/1024:.1f} KB)")

if __name__ == '__main__':
    main()
