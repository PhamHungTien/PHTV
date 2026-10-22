import AppKit
import SwiftUI
import XCTest
@testable import PHTV

final class FloatingPanelVisibilityTests: XCTestCase {
    func testClipboardPanelCanReceiveKeysWithoutActivatingOrShowingDock() async {
        await MainActor.run {
            let policy = NSApp.activationPolicy()
            let panel = FloatingPanel(view: Text("Clipboard"), contentRect: NSRect(x: 0, y: 0, width: 380, height: 480))
            defer { panel.close() }
            XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
            XCTAssertFalse(panel.hidesOnDeactivate)
            XCTAssertFalse(panel.becomesKeyOnlyIfNeeded)
            XCTAssertTrue(panel.canBecomeKey)
            XCTAssertEqual(NSApp.activationPolicy(), policy)
        }
    }
}
