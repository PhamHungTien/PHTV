import CoreGraphics
import XCTest
@testable import PHTV

final class EventCallbackOwnershipTests: XCTestCase {
    func testSyntheticPassthroughReturnsTheOriginalEvent() throws {
        let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true))
        event.setIntegerValueField(.eventSourceUserData, value: EventSourceMarker.phtv)
        // The synthetic fast path never dereferences the proxy; no tap is
        // installed and no real key is posted by this test.
        let proxy = try XCTUnwrap(OpaquePointer(bitPattern: 1))
        let returned = try XCTUnwrap(
            PHTVEventCallbackService.handle(proxy: proxy, type: .keyDown, event: event, refcon: nil)
        )
        XCTAssertTrue(returned.takeUnretainedValue() === event)
    }

    func testRepeatedPassthroughDoesNotExtendEventLifetime() throws {
        weak var observedEvent: CGEvent?
        let proxy = try XCTUnwrap(OpaquePointer(bitPattern: 1))
        try autoreleasepool {
            let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true))
            observedEvent = event
            event.setIntegerValueField(.eventSourceUserData, value: EventSourceMarker.phtv)
            for _ in 0..<1_000 {
                let returned = try XCTUnwrap(
                    PHTVEventCallbackService.handle(proxy: proxy, type: .keyDown, event: event, refcon: nil)
                )
                // Do not takeRetainedValue(): Quartz does not consume an
                // additional retain when this is the original input event.
                XCTAssertTrue(returned.takeUnretainedValue() === event)
            }
        }
        XCTAssertNil(observedEvent, "Returning the original event must not leak a retain per callback")
    }
}
