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
assertEqual(composer.compose("dwfng", style: .telex), "đừng", "dwfng -> đừng")
assertEqual(composer.compose("dwofng", style: .telex), "đường", "dwofng -> đường")
assertEqual(composer.compose("swofng", style: .telex), "sườn", "swofng -> sườn")

// Test 2: Tone Placement for Initial Consonant GI
assertEqual(composer.compose("giups", style: .telex), "giúp", "giups -> giúp")
assertEqual(composer.compose("giangr", style: .telex), "giảng", "giangr -> giảng")
assertEqual(composer.compose("giayf", style: .telex), "giày", "giayf -> giày")
assertEqual(composer.compose("gieetst", style: .telex), "giết", "gieetst -> giết")
assertEqual(composer.compose("gioir", style: .telex), "giỏi", "gioir -> giỏi")
assertEqual(composer.compose("gif", style: .telex), "gì", "gif -> gì")
assertEqual(composer.compose("ginn", style: .telex), "gìn", "ginn -> gìn")

// Test 3: Tone Placement for Initial Consonant QU
assertEqual(composer.compose("quans", style: .telex), "quán", "quans -> quán")
assertEqual(composer.compose("quanns", style: .telex), "quắn", "quanns -> quắn")
assertEqual(composer.compose("queor", style: .telex), "quẻo", "queor -> quẻo")
assertEqual(composer.compose("quys", style: .telex), "quý", "quys -> quý")
assertEqual(composer.compose("quyets", style: .telex), "quyết", "quyets -> quyết")

// Test 4: Traditional Regression Cases
assertEqual(composer.compose("sai", style: .telex), "sai", "sai -> sai")
assertEqual(composer.compose("sau", style: .telex), "sau", "sau -> sau")
assertEqual(composer.compose("fan", style: .telex), "fan", "fan -> fan")
assertEqual(composer.compose("rum", style: .telex), "rum", "rum -> rum")
assertEqual(composer.compose("xin", style: .telex), "xin", "xin -> xin")
assertEqual(composer.compose("jam", style: .telex), "jam", "jam -> jam")
assertEqual(composer.compose("zap", style: .telex), "zap", "zap -> zap")
assertEqual(composer.compose("huowsng", style: .telex), "hướng", "huowsng -> hướng")
assertEqual(composer.compose("huwongs", style: .telex), "hướng", "huwongs -> hướng")
assertEqual(composer.compose("huwong", style: .telex), "hương", "huwong -> hương")
assertEqual(composer.compose("huongw", style: .telex), "hương", "huongw -> hương")
assertEqual(composer.compose("huongws", style: .telex), "hướng", "huongws -> hướng")
assertEqual(composer.compose("HUWONGS", style: .telex), "HƯỚNG", "HUWONGS -> HƯỚNG")
assertEqual(composer.compose("Huwongs", style: .telex), "Hướng", "Huwongs -> Hướng")


// Test 5: Vowel Combination Edge Cases
assertEqual(composer.compose("khoas", style: .telex), "khoá", "khoas -> khoá")
assertEqual(composer.compose("khuys", style: .telex), "khuý", "khuys -> khuý")
assertEqual(composer.compose("hoaf", style: .telex), "hoà", "hoaf -> hoà")

// Test 6: VNI Method Edge Cases
assertEqual(composer.compose("m7n7g2", style: .vni), "mừng", "m7n7g2 -> mừng")
assertEqual(composer.compose("giu1p", style: .vni), "giúp", "giu1p -> giúp")
assertEqual(composer.compose("qua1n", style: .vni), "quán", "qua1n -> quán")
assertEqual(composer.compose("sai", style: .vni), "sai", "sai -> sai")
assertEqual(composer.compose("hu7ong", style: .vni), "hương", "hu7ong -> hương")
assertEqual(composer.compose("huong7", style: .vni), "hương", "huong7 -> hương")
assertEqual(composer.compose("hu7ong1", style: .vni), "hướng", "hu7ong1 -> hướng")
assertEqual(composer.compose("huong71", style: .vni), "hướng", "huong71 -> hướng")
assertEqual(composer.compose("HU7ONG1", style: .vni), "HƯỚNG", "HU7ONG1 -> HƯỚNG")
assertEqual(composer.compose("Hu7ong1", style: .vni), "Hướng", "Hu7ong1 -> Hướng")


print("✨ ALL TESTS PASSED SUCCESSFULLY! (40+ assertions)")
