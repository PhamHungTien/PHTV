import PHTVCore
import PHTVCoreContracts
import XCTest

final class PHTVCoreTests: XCTestCase {
    func testSessionPassesThrough() {
        let session = PHTVCoreSession()
        let event = PHTVKeyEvent(
            kind: .keyDown,
            hardwareUsage: 0x04,
            logicalScalar: "a"
        )
        let context = PHTVInputContext(languageMode: .vietnamese)

        let plan = session.handle(event: event, context: context)

        XCTAssertEqual(plan.action, .passThrough)
        XCTAssertTrue(plan.replacement.isEmpty)
        XCTAssertEqual(plan.sessionGeneration, 1)
    }

    func testResetAdvancesGeneration() {
        let session = PHTVCoreSession()

        session.reset()

        XCTAssertEqual(session.generation, 2)
    }

    func testCapabilitiesAreHonest() {
        XCTAssertEqual(phtvCoreABIVersion(), PHTVCoreVersion.abi)
        XCTAssertTrue(PHTVCoreCapabilities.current.contains(.sessionABI))
        XCTAssertFalse(PHTVCoreCapabilities.current.contains(.vietnameseEngine))
    }

    func testCABIValidatesNullAndUndersizedInputs() {
        XCTAssertEqual(
            phtvCoreSessionCreate(nil),
            Int32(PHTV_CORE_STATUS_INVALID_ARGUMENT)
        )

        var session: UnsafeMutableRawPointer?
        XCTAssertEqual(
            phtvCoreSessionCreate(&session),
            Int32(PHTV_CORE_STATUS_OK)
        )
        defer {
            XCTAssertEqual(
                phtvCoreSessionDestroy(session),
                Int32(PHTV_CORE_STATUS_OK)
            )
        }

        var event = phtv_core_key_event_t()
        var context = phtv_core_input_context_t()
        var plan = phtv_core_edit_plan_t()

        XCTAssertEqual(
            phtvCoreSessionHandleEvent(
                session,
                &event,
                &context,
                &plan,
                nil,
                0
            ),
            Int32(PHTV_CORE_STATUS_UNSUPPORTED_ABI)
        )
    }

    func testCABILifecycleProducesVersionedEditPlan() {
        var session: UnsafeMutableRawPointer?
        XCTAssertEqual(
            phtvCoreSessionCreate(&session),
            Int32(PHTV_CORE_STATUS_OK)
        )
        defer {
            XCTAssertEqual(
                phtvCoreSessionDestroy(session),
                Int32(PHTV_CORE_STATUS_OK)
            )
        }

        var event = phtv_core_key_event_t()
        event.struct_size = UInt32(MemoryLayout.size(ofValue: event))
        event.kind = UInt32(PHTV_CORE_EVENT_KEY_DOWN)
        event.hardware_key = 0x04
        event.logical_scalar = 0x61

        var context = phtv_core_input_context_t()
        context.struct_size = UInt32(MemoryLayout.size(ofValue: context))
        context.language_mode = UInt32(PHTV_CORE_LANGUAGE_VIETNAMESE)
        context.app_rule = UInt32(PHTV_CORE_APP_RULE_INHERIT)

        var plan = phtv_core_edit_plan_t()
        plan.struct_size = UInt32(MemoryLayout.size(ofValue: plan))

        XCTAssertEqual(
            phtvCoreSessionHandleEvent(
                session,
                &event,
                &context,
                &plan,
                nil,
                0
            ),
            Int32(PHTV_CORE_STATUS_OK)
        )
        XCTAssertEqual(plan.action, UInt32(PHTV_CORE_EDIT_PASS_THROUGH))
        XCTAssertEqual(plan.replacement_length_utf16, 0)
        XCTAssertEqual(plan.session_generation, 1)

        XCTAssertEqual(
            phtvCoreSessionReset(session),
            Int32(PHTV_CORE_STATUS_OK)
        )
        plan.struct_size = UInt32(MemoryLayout.size(ofValue: plan))
        XCTAssertEqual(
            phtvCoreSessionHandleEvent(
                session,
                &event,
                &context,
                &plan,
                nil,
                0
            ),
            Int32(PHTV_CORE_STATUS_OK)
        )
        XCTAssertEqual(plan.session_generation, 2)
    }
}
