//
//  LayoutCompatThreadSafetyTests.swift
//  PHTV
//
//  Regression coverage for issue #208: PHTV processes keys on a dedicated
//  event-tap thread, but resolving the keyboard layout goes through Carbon
//  TSM, which hard-asserts the main dispatch queue on recent macOS. Touching
//  it from the tap thread crashed on the first press of any key.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
import CoreGraphics
@testable import PHTV

final class LayoutCompatThreadSafetyTests: XCTestCase {

    private let noValue = UInt16.max

    private func makeKeyEvent(_ keyCode: UInt16) -> CGEvent? {
        guard let source = CGEventSource(stateID: .privateState) else { return nil }
        let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true)
        event?.flags = []
        return event
    }

    override func tearDown() {
        PHTVCacheStateService.invalidateLayoutCache()
        super.tearDown()
    }

    func testConversionOffMainThreadNeverResolvesLayoutAndFallsBack() throws {
        let event = try XCTUnwrap(makeKeyEvent(KEY_A))
        // A value no real conversion can produce: if the tap thread resolved
        // the layout (pre-fix behaviour, and a TSM crash on macOS 27) it would
        // return KEY_A instead of this sentinel.
        let sentinel: UInt16 = 4096

        var result: UInt16 = 0
        let done = expectation(description: "off-main conversion returns")
        DispatchQueue.global(qos: .userInteractive).async {
            // Invalidate here so no main-queue prewarm can refill the cache
            // between the reset and the lookup below.
            PHTVCacheStateService.invalidateLayoutCache()
            result = PHTVHotkeyService.convertEventToKeyboardLayoutCompatKeyCode(
                event,
                fallback: sentinel
            )
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        XCTAssertEqual(
            result,
            sentinel,
            "Off-main conversion must pass the key through instead of resolving the layout"
        )
    }

    func testPrewarmOnMainThreadPopulatesLayoutCache() throws {
        XCTAssertTrue(Thread.isMainThread, "XCTest is expected to run this on the main thread")

        PHTVCacheStateService.invalidateLayoutCache()
        XCTAssertEqual(PHTVCacheStateService.cachedLayoutConversion(KEY_A), noValue)

        PHTVHotkeyService.prewarmLayoutCompatCache()

        XCTAssertNotEqual(
            PHTVCacheStateService.cachedLayoutConversion(KEY_A),
            noValue,
            "Prewarm must resolve the layout on the main thread and fill the cache"
        )
    }

    func testOffMainConversionUsesPrewarmedCacheValue() throws {
        PHTVCacheStateService.invalidateLayoutCache()
        PHTVHotkeyService.prewarmLayoutCompatCache()

        let cached = PHTVCacheStateService.cachedLayoutConversion(KEY_S)
        try XCTSkipIf(cached == noValue, "Layout did not resolve on this machine")

        let event = try XCTUnwrap(makeKeyEvent(KEY_S))
        var result: UInt16 = 0
        let done = expectation(description: "off-main conversion returns cached value")
        DispatchQueue.global(qos: .userInteractive).async {
            result = PHTVHotkeyService.convertEventToKeyboardLayoutCompatKeyCode(
                event,
                fallback: 0
            )
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        XCTAssertEqual(result, cached, "Tap thread must serve the prewarmed cache, not the fallback")
    }
}
