import XCTest
@testable import PHTV

final class SettingsSearchTests: XCTestCase {
    func testUnaccentedAndDecomposedVietnameseFindTheSameFeature() {
        for query in ["bo qua noi dung nhay cam", "BỎ QUA NỘI DUNG NHẠY CẢM", "Bỏ qua nội dung nhạy cảm".decomposedStringWithCanonicalMapping] {
            XCTAssertTrue(SettingsItem.search(query).contains { $0.title == "Bỏ qua nội dung nhạy cảm" })
        }
    }

    func testWordsCanMatchAcrossTitleAndSynonyms() {
        XCTAssertTrue(SettingsItem.search("  clipboard   nhay cam  ").contains { $0.title == "Bỏ qua nội dung nhạy cảm" })
        XCTAssertTrue(SettingsItem.search("khoi phuc esc").contains { $0.tab == .hotkeys })
        XCTAssertTrue(SettingsItem.search("GIF rieng tu").contains { $0.tab == .phtvPicker })
    }

    func testPreviouslyMissingFeaturesAreDiscoverable() {
        for (query, tab) in [("2 lan phim cach", SettingsTab.typing), ("text replacements", .macro), ("tu dong tai va cai dat", .system), ("dong cai dat", .system), ("xoa muc cu", .clipboardHistory), ("lau ban phim", .keyboardCleaning)] {
            XCTAssertTrue(SettingsItem.search(query).contains { $0.tab == tab }, query)
        }
    }

    func testCatalogHasStableUniqueIdentitiesAndEveryTitleCanBeFound() {
        let items = SettingsItem.allItems
        XCTAssertEqual(Set(items.map(\.id)).count, items.count)
        for item in items {
            XCTAssertTrue(SettingsItem.search(item.title).contains { $0.id == item.id }, item.title)
        }
        XCTAssertEqual(Set(items.map(\.tab)), Set(SettingsTab.allCases))
    }

    func testBlankAndUnknownQueriesHaveNoResults() {
        XCTAssertTrue(SettingsItem.search(" \n\t ").isEmpty)
        XCTAssertTrue(SettingsItem.search("no-such-phtv-setting-123456").isEmpty)
    }
}
