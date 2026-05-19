import Foundation

// Custom assertion helper
func assertEqual(_ actual: String, _ expected: String, _ message: String, file: String = #file, line: Int = #line) {
    if actual != expected {
        print("❌ FAIL: \(message)")
        print("   Expected: \"\(expected)\"")
        print("   Actual:   \"\(actual)\"")
        print("   At:       \(file):\(line)")
        exit(1)
    }
}

let composer = PHTVVietnameseComposer()

print("Running PHTVVietnameseComposer tests...")

// Test 1: Telex Tone Marker Recognition with Raw Vowel W
assertEqual(composer.compose("mwfng", style: .telex), "mừng", "mwfng -> mừng")
assertEqual(composer.compose("mwf", style: .telex), "mừ", "mwf -> mừ")
assertEqual(composer.compose("dwfng", style: .telex), "dừng", "dwfng -> dừng")
assertEqual(composer.compose("ddwfng", style: .telex), "đừng", "ddwfng -> đừng")
assertEqual(composer.compose("duowngf", style: .telex), "dường", "duowngf -> dường")
assertEqual(composer.compose("dduowngf", style: .telex), "đường", "dduowngf -> đường")
assertEqual(composer.compose("suownf", style: .telex), "sườn", "suownf -> sườn")

// Test 2: Tone Placement for Initial Consonant GI
assertEqual(composer.compose("giups", style: .telex), "giúp", "giups -> giúp")
assertEqual(composer.compose("giangr", style: .telex), "giảng", "giangr -> giảng")
assertEqual(composer.compose("giayf", style: .telex), "giày", "giayf -> giày")
assertEqual(composer.compose("gieets", style: .telex), "giết", "gieets -> giết")
assertEqual(composer.compose("gioir", style: .telex), "giỏi", "gioir -> giỏi")
assertEqual(composer.compose("gif", style: .telex), "gì", "gif -> gì")
assertEqual(composer.compose("ginf", style: .telex), "gìn", "ginf -> gìn")

// Test 3: Tone Placement for Initial Consonant QU
assertEqual(composer.compose("quans", style: .telex), "quán", "quans -> quán")
assertEqual(composer.compose("quawns", style: .telex), "quắn", "quawns -> quắn")
assertEqual(composer.compose("queor", style: .telex), "quẻo", "queor -> quẻo")
assertEqual(composer.compose("quys", style: .telex), "quý", "quys -> quý")
assertEqual(composer.compose("quyeets", style: .telex), "quyết", "quyeets -> quyết")

// Test 4: Traditional Regression Cases
assertEqual(composer.compose("sai", style: .telex), "sai", "sai -> sai")
assertEqual(composer.compose("sau", style: .telex), "sau", "sau -> sau")
assertEqual(composer.compose("fan", style: .telex), "fan", "fan -> fan")
assertEqual(composer.compose("rum", style: .telex), "rum", "rum -> rum")
assertEqual(composer.compose("xin", style: .telex), "xin", "xin -> xin")
assertEqual(composer.compose("jam", style: .telex), "jam", "jam -> jam")
assertEqual(composer.compose("zap", style: .telex), "zap", "zap -> zap")
assertEqual(composer.compose("huowsng", style: .telex), "hướng", "huowsng -> hướng")

// Test 5: Vowel Combination Edge Cases
assertEqual(composer.compose("khoas", style: .telex), "khoá", "khoas -> khoá")
assertEqual(composer.compose("khuys", style: .telex), "khuý", "khuys -> khuý")
assertEqual(composer.compose("hoaf", style: .telex), "hoà", "hoaf -> hoà")

// Test 6: VNI Method Edge Cases
assertEqual(composer.compose("mu7ng2", style: .vni), "mừng", "mu7ng2 -> mừng")
assertEqual(composer.compose("giu1p", style: .vni), "giúp", "giu1p -> giúp")
assertEqual(composer.compose("qua1n", style: .vni), "quán", "qua1n -> quán")
assertEqual(composer.compose("sai", style: .vni), "sai", "sai -> sai")

// Test 7: Telex Consecutive W Collapsing
assertEqual(composer.compose("ww", style: .telex), "w", "ww -> w")
assertEqual(composer.compose("WW", style: .telex), "W", "WW -> W")
assertEqual(composer.compose("uww", style: .telex), "ưw", "uww -> ưw")
assertEqual(composer.compose("oww", style: .telex), "ơw", "oww -> ơw")
assertEqual(composer.compose("aww", style: .telex), "ăw", "aww -> ăw")
assertEqual(composer.compose("huoww", style: .telex), "hươw", "huoww -> hươw")

// Test 8: Telex Tone Removal (Gỡ Dấu)
assertEqual(composer.compose("as", style: .telex), "á", "as -> á")
assertEqual(composer.compose("ass", style: .telex), "as", "ass -> as")
assertEqual(composer.compose("asss", style: .telex), "ás", "asss -> ás")
assertEqual(composer.compose("assss", style: .telex), "ass", "assss -> ass")
assertEqual(composer.compose("asf", style: .telex), "à", "asf -> à")
assertEqual(composer.compose("asff", style: .telex), "af", "asff -> af")
assertEqual(composer.compose("asfs", style: .telex), "á", "asfs -> á")
assertEqual(composer.compose("asnhs", style: .telex), "anhs", "asnhs -> anhs")
assertEqual(composer.compose("sais", style: .telex), "sái", "sais -> sái")
assertEqual(composer.compose("saiss", style: .telex), "sais", "saiss -> sais")
assertEqual(composer.compose("chafof", style: .telex), "chaof", "chafof -> chaof")

// Test 9: VNI Tone Removal (Gỡ Dấu)
assertEqual(composer.compose("a1", style: .vni), "á", "a1 -> á")
assertEqual(composer.compose("a11", style: .vni), "a1", "a11 -> a1")
assertEqual(composer.compose("a111", style: .vni), "á1", "a111 -> á1")
assertEqual(composer.compose("a1111", style: .vni), "a11", "a1111 -> a11")

print("✨ ALL TESTS PASSED SUCCESSFULLY! (50+ assertions)")
