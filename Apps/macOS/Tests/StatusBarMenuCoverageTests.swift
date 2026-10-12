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
        for title in ["Báo lỗi...", "Ủng hộ PHTV...", "Kiểm tra cập nhật", "Thoát PHTV"] {
            XCTAssertNotNil(menu.items.first { $0.title == title }?.action, title)
        }
    }
}
