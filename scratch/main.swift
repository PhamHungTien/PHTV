import Foundation

// Define the PHTVInputStyle enum as it is in the main target
enum PHTVInputStyle: Int, CaseIterable {
    case telex = 0
    case vni = 1
    case simpleTelex1 = 2
    case simpleTelex2 = 3
}

// Simple test helper
var failedTests = 0
var passedTests = 0

func assertEqual(_ actual: String, _ expected: String, _ message: String = "", file: String = #file, line: Int = #line) {
    if actual == expected {
        passedTests += 1
    } else {
        failedTests += 1
        print("❌ Assertion Failed at \(file):\(line)")
        if !message.isEmpty {
            print("   Message: \(message)")
        }
        print("   Expected: \"\(expected)\"")
        print("   Actual:   \"\(actual)\"")
    }
}

func assertNotEqual(_ actual: String, _ expected: String, _ message: String = "", file: String = #file, line: Int = #line) {
    if actual != expected {
        passedTests += 1
    } else {
        failedTests += 1
        print("❌ Assertion Failed at \(file):\(line)")
        if !message.isEmpty {
            print("   Message: \(message)")
        }
        print("   Expected NOT to equal: \"\(expected)\"")
        print("   Actual:                \"\(actual)\"")
    }
}

let composer = PHTVVietnameseComposer()

print("--- Running PHTVVietnameseComposer Tests ---")

// 1. testTelexToneMarkerRecognitionWithRawVowelW
assertEqual(composer.compose("mwfng", style: PHTVInputStyle.telex), "mừng")
assertEqual(composer.compose("mwf", style: PHTVInputStyle.telex), "mừ")
assertEqual(composer.compose("dwfng", style: PHTVInputStyle.telex), "dừng")
assertEqual(composer.compose("ddwfng", style: PHTVInputStyle.telex), "đừng")
assertEqual(composer.compose("duowngf", style: PHTVInputStyle.telex), "dường")
assertEqual(composer.compose("dduowngf", style: PHTVInputStyle.telex), "đường")
assertEqual(composer.compose("suownf", style: PHTVInputStyle.telex), "sườn")

// 2. testTonePlacementForInitialConsonantGI
assertEqual(composer.compose("giups", style: PHTVInputStyle.telex), "giúp")
assertEqual(composer.compose("giangr", style: PHTVInputStyle.telex), "giảng")
assertEqual(composer.compose("giayf", style: PHTVInputStyle.telex), "giày")
assertEqual(composer.compose("gieets", style: PHTVInputStyle.telex), "giết")
assertEqual(composer.compose("gioir", style: PHTVInputStyle.telex), "giỏi")
assertEqual(composer.compose("gif", style: PHTVInputStyle.telex), "gì")
assertEqual(composer.compose("ginf", style: PHTVInputStyle.telex), "gìn")

// 3. testTonePlacementForInitialConsonantQU
assertEqual(composer.compose("quans", style: PHTVInputStyle.telex), "quán")
assertEqual(composer.compose("quawns", style: PHTVInputStyle.telex), "quắn")
assertEqual(composer.compose("queor", style: PHTVInputStyle.telex), "quẻo")
assertEqual(composer.compose("quys", style: PHTVInputStyle.telex), "quý")
assertEqual(composer.compose("quyeets", style: PHTVInputStyle.telex), "quyết")

// 4. testTraditionalRegressionCases
assertEqual(composer.compose("sai", style: PHTVInputStyle.telex), "sai")
assertEqual(composer.compose("sau", style: PHTVInputStyle.telex), "sau")
assertEqual(composer.compose("fan", style: PHTVInputStyle.telex), "fan")
assertEqual(composer.compose("rum", style: PHTVInputStyle.telex), "rum")
assertEqual(composer.compose("xin", style: PHTVInputStyle.telex), "xin")
assertEqual(composer.compose("jam", style: PHTVInputStyle.telex), "jam")
assertEqual(composer.compose("zap", style: PHTVInputStyle.telex), "zap")
assertEqual(composer.compose("huowsng", style: PHTVInputStyle.telex), "hướng")

// 5. testVowelCombinationEdgeCases
assertEqual(composer.compose("khoas", style: PHTVInputStyle.telex), "khoá")
assertEqual(composer.compose("khuys", style: PHTVInputStyle.telex), "khuý")
assertEqual(composer.compose("hoaf", style: PHTVInputStyle.telex), "hoà")

// 6. testVNIMethodEdgeCases
assertEqual(composer.compose("mu7ng2", style: PHTVInputStyle.vni), "mừng")
assertEqual(composer.compose("giu1p", style: PHTVInputStyle.vni), "giúp")
assertEqual(composer.compose("qua1n", style: PHTVInputStyle.vni), "quán")
assertEqual(composer.compose("sai", style: PHTVInputStyle.vni), "sai")

// 7. testSpellingNormalization
assertEqual(composer.compose("huwongs", style: PHTVInputStyle.telex), "hướng")
assertEqual(composer.compose("huwong", style: PHTVInputStyle.telex), "hương")
assertEqual(composer.compose("huongw", style: PHTVInputStyle.telex), "hương")
assertEqual(composer.compose("huongws", style: PHTVInputStyle.telex), "hướng")
assertEqual(composer.compose("HUWONGS", style: PHTVInputStyle.telex), "HƯỚNG")
assertEqual(composer.compose("Huwongs", style: PHTVInputStyle.telex), "Hướng")

assertEqual(composer.compose("hu7ong", style: PHTVInputStyle.vni), "hương")
assertEqual(composer.compose("huong7", style: PHTVInputStyle.vni), "hương")
assertEqual(composer.compose("hu7ong1", style: PHTVInputStyle.vni), "hướng")
assertEqual(composer.compose("huong71", style: PHTVInputStyle.vni), "hướng")
assertEqual(composer.compose("HU7ONG1", style: PHTVInputStyle.vni), "HƯỚNG")
assertEqual(composer.compose("Hu7ong1", style: PHTVInputStyle.vni), "Hướng")

assertEqual(composer.compose("hứo", style: PHTVInputStyle.telex), "hướ")
assertEqual(composer.compose("huớ", style: PHTVInputStyle.telex), "hướ")
assertEqual(composer.compose("hứong", style: PHTVInputStyle.telex), "hướng")
assertEqual(composer.compose("huớng", style: PHTVInputStyle.telex), "hướng")
assertEqual(composer.compose("Hứong", style: PHTVInputStyle.telex), "Hướng")
assertEqual(composer.compose("HUỚNG", style: PHTVInputStyle.telex), "HƯỚNG")

// 8. testAutoRestoreEnglish
assertEqual(composer.compose("terminal", style: PHTVInputStyle.telex), "terminal")
assertEqual(composer.compose("microsoft", style: PHTVInputStyle.telex), "microsoft")
assertEqual(composer.compose("clear", style: PHTVInputStyle.telex), "clear")
assertEqual(composer.compose("email", style: PHTVInputStyle.telex), "email")
assertEqual(composer.compose("install", style: PHTVInputStyle.telex), "install")
assertEqual(composer.compose("facebook", style: PHTVInputStyle.telex), "facebook")
assertEqual(composer.compose("google", style: PHTVInputStyle.telex), "google")
assertEqual(composer.compose("local", style: PHTVInputStyle.telex), "local")
assertEqual(composer.compose("internet", style: PHTVInputStyle.telex), "internet")

assertNotEqual(composer.compose("terminal", style: PHTVInputStyle.telex, autoRestore: false), "terminal")

assertEqual(composer.compose("free", style: PHTVInputStyle.telex), "free")
assertEqual(composer.compose("book", style: PHTVInputStyle.telex), "book")
assertEqual(composer.compose("good", style: PHTVInputStyle.telex), "good")
assertEqual(composer.compose("size", style: PHTVInputStyle.telex), "size")
assertEqual(composer.compose("code", style: PHTVInputStyle.telex), "code")
assertEqual(composer.compose("make", style: PHTVInputStyle.telex), "make")

assertEqual(composer.compose("kieer", style: PHTVInputStyle.telex), "kiể")
assertEqual(composer.compose("kiee", style: PHTVInputStyle.telex), "kiê")
assertEqual(composer.compose("tieerng", style: PHTVInputStyle.telex), "tiểng")
assertEqual(composer.compose("tier", style: PHTVInputStyle.telex), "tier")
assertEqual(composer.compose("ties", style: PHTVInputStyle.telex), "ties")
assertEqual(composer.compose("bye", style: PHTVInputStyle.telex), "bye")

assertEqual(composer.compose("mwfng", style: PHTVInputStyle.telex), "mừng")
assertEqual(composer.compose("giups", style: PHTVInputStyle.telex), "giúp")
assertEqual(composer.compose("quans", style: PHTVInputStyle.telex), "quán")
assertEqual(composer.compose("huowsng", style: PHTVInputStyle.telex), "hướng")
assertEqual(composer.compose("xoong", style: PHTVInputStyle.telex), "xông")

print("--- Test Run Completed ---")
print("Passed: \(passedTests) assertions")
if failedTests > 0 {
    print("❌ Failed: \(failedTests) assertions")
    exit(1)
} else {
    print("✅ All tests passed successfully!")
    exit(0)
}
