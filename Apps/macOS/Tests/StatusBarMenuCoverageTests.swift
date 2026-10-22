import AppKit
import XCTest
@testable import PHTV

final class StatusBarMenuCoverageTests: XCTestCase {
    @MainActor
    func testEverySettingsPageIsReachableFromMenuBar() {
        let menu = NSMenu()
        StatusBarMenuManager.shared.menuNeedsUpdate(menu)

        let settings = menu.items.first { $0.title == "Các mục cài đặt" }?.submenu
        XCTAssertNotNil(settings)
        for tab in SettingsTab.allCases {
            let item = settings?.items.first { $0.title == tab.title + "..." }
            XCTAssertNotNil(item, "Missing menu destination: \(tab.title)")
            XCTAssertNotNil(item?.action)
            XCTAssertNotNil(item?.target)
        }
    }

    @MainActor
    func testQuickToolsAndSupportActionsAreReachable() {
        let menu = NSMenu()
        StatusBarMenuManager.shared.menuNeedsUpdate(menu)
        let tools = menu.items.first { $0.title == "Công cụ" }?.submenu

        for title in ["Mở PHTV Picker", "Mở Clipboard", "Quản lý gõ tắt...", "Chuyển đổi bảng mã...", "Lau bàn phím..."] {
            XCTAssertNotNil(tools?.items.first { $0.title == title }?.action, title)
        }
        let support = menu.items.first { $0.title == "Hỗ trợ" }?.submenu
        for title in ["Hướng dẫn sử dụng", "Báo lỗi...", "Ủng hộ PHTV...", "Kiểm tra cập nhật..."] {
            XCTAssertNotNil(support?.items.first { $0.title == title }?.action, title)
        }
        XCTAssertNotNil(menu.items.first { $0.title == "Thoát hoàn toàn PHTV" }?.action)
    }
    @MainActor
    func testNativeMenuChoicesAndShortcutsAreComplete() {
        let menu = NSMenu()
        StatusBarMenuManager.shared.menuNeedsUpdate(menu)
        let typing = menu.items.first { $0.title == "Bộ gõ" }?.submenu
        for title in InputMethod.allCases.map(\.displayName) + CodeTable.allCases.map(\.displayName) {
            XCTAssertNotNil(typing?.items.first { $0.title == title }?.action, title)
        }
        XCTAssertEqual(menu.items.first { $0.title == "Mở Cài đặt..." }?.keyEquivalent, ",")
        XCTAssertEqual(menu.items.first { $0.title == "Thoát hoàn toàn PHTV" }?.keyEquivalent, "q")
        let features = menu.items.first { $0.title == "Tính năng" }?.submenu
        XCTAssertNotNil(features?.items.first { $0.title == "Bỏ qua nội dung nhạy cảm" }?.action)
        XCTAssertNil(features?.items.first { $0.title == "Mở Clipboard" })
        func verify(_ menu: NSMenu) {
            let actionable = menu.items.filter { $0.action != nil || $0.submenu != nil }
            XCTAssertEqual(Set(actionable.map(\.title)).count, actionable.count)
            for item in menu.items {
                if item.action != nil { XCTAssertNotNil(item.target, item.title) }
                if let submenu = item.submenu { verify(submenu) }
            }
        }
        verify(menu)
    }

}
