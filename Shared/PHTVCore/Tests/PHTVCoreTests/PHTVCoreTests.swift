import PHTVCore
import PHTVCoreContracts
import Foundation
import XCTest

final class PHTVCoreTests: XCTestCase {
    private struct GoldenVectorFile: Decodable {
        let schemaVersion: Int
        let cases: [GoldenVector]
    }

    private struct GoldenVector: Decodable {
        let id: String
        let method: String
        let keys: String
        let expected: String
    }

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
        XCTAssertTrue(PHTVCoreCapabilities.current.contains(.telexEngine))
        XCTAssertTrue(PHTVCoreCapabilities.current.contains(.vniEngine))
        XCTAssertTrue(
            PHTVCoreCapabilities.current.isSuperset(of: .vietnameseEngine)
        )
    }

    func testSharedGoldenVectors() throws {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TestVectors/vietnamese-core-v1.json")
        let fixture = try JSONDecoder().decode(
            GoldenVectorFile.self,
            from: Data(contentsOf: fixtureURL)
        )

        XCTAssertEqual(fixture.schemaVersion, 1)
        XCTAssertGreaterThanOrEqual(fixture.cases.count, 40)

        for vector in fixture.cases {
            let method: PHTVInputMethod
            switch vector.method {
            case "telex":
                method = .telex
            case "vni":
                method = .vni
            default:
                XCTFail("Unknown input method in \(vector.id)")
                continue
            }

            XCTAssertEqual(
                render(vector.keys, method: method),
                vector.expected,
                vector.id
            )
        }
    }

    func testEnglishAndSensitiveContextsNeverTransformInput() {
        for context in [
            PHTVInputContext(languageMode: .english),
            PHTVInputContext(
                languageMode: .vietnamese,
                appRule: .lockEnglish
            ),
            PHTVInputContext(
                languageMode: .vietnamese,
                flags: [.sensitive]
            ),
        ] {
            let session = PHTVCoreSession()
            for scalar in "dd".unicodeScalars {
                let plan = session.handle(
                    event: PHTVKeyEvent(
                        kind: .keyDown,
                        hardwareUsage: 0,
                        logicalScalar: scalar
                    ),
                    context: context
                )
                XCTAssertEqual(plan.action, .passThrough)
            }
        }
    }

    func testBackspaceRecomputesTransformedComposition() {
        let session = PHTVCoreSession()
        let context = PHTVInputContext(languageMode: .vietnamese)
        _ = session.handle(
            event: PHTVKeyEvent(
                kind: .keyDown,
                hardwareUsage: 0,
                logicalScalar: "d"
            ),
            context: context
        )
        let transformed = session.handle(
            event: PHTVKeyEvent(
                kind: .keyDown,
                hardwareUsage: 0,
                logicalScalar: "d"
            ),
            context: context
        )
        XCTAssertEqual(transformed.replacement, "đ")

        let backspace = session.handle(
            event: PHTVKeyEvent(
                kind: .keyDown,
                hardwareUsage: 0x2A,
                logicalScalar: nil
            ),
            context: context
        )
        XCTAssertEqual(backspace.action, .replace)
        XCTAssertEqual(backspace.deleteBeforeUTF16, 1)
        XCTAssertEqual(backspace.replacement, "d")
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
        context.input_method = UInt32(PHTV_CORE_INPUT_TELEX)

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

    func testCABIBufferTooSmallDoesNotAdvanceComposition() {
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

        var context = phtv_core_input_context_t()
        context.struct_size = UInt32(MemoryLayout.size(ofValue: context))
        context.language_mode = UInt32(PHTV_CORE_LANGUAGE_VIETNAMESE)
        context.app_rule = UInt32(PHTV_CORE_APP_RULE_INHERIT)
        context.input_method = UInt32(PHTV_CORE_INPUT_TELEX)

        var event = phtv_core_key_event_t()
        event.struct_size = UInt32(MemoryLayout.size(ofValue: event))
        event.kind = UInt32(PHTV_CORE_EVENT_KEY_DOWN)
        event.logical_scalar = Unicode.Scalar("d").value

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
            Int32(PHTV_CORE_STATUS_BUFFER_TOO_SMALL)
        )
        XCTAssertEqual(plan.replacement_length_utf16, 1)

        var replacement = Array(repeating: UInt16(0), count: 1)
        plan.struct_size = UInt32(MemoryLayout.size(ofValue: plan))
        XCTAssertEqual(
            replacement.withUnsafeMutableBufferPointer { buffer in
                phtvCoreSessionHandleEvent(
                    session,
                    &event,
                    &context,
                    &plan,
                    buffer.baseAddress,
                    buffer.count
                )
            },
            Int32(PHTV_CORE_STATUS_OK)
        )
        XCTAssertEqual(String(decoding: replacement, as: UTF16.self), "đ")
    }

    private func render(
        _ keys: String,
        method: PHTVInputMethod
    ) -> String {
        let session = PHTVCoreSession()
        let context = PHTVInputContext(
            languageMode: .vietnamese,
            inputMethod: method
        )
        var output: [UInt16] = []

        for scalar in keys.unicodeScalars {
            let plan = session.handle(
                event: PHTVKeyEvent(
                    kind: .keyDown,
                    hardwareUsage: 0,
                    logicalScalar: scalar
                ),
                context: context
            )
            switch plan.action {
            case .passThrough:
                output.append(contentsOf: String(scalar).utf16)
            case .replace:
                let deleteCount = min(
                    Int(plan.deleteBeforeUTF16),
                    output.count
                )
                output.removeLast(deleteCount)
                output.append(contentsOf: plan.replacement.utf16)
            case .commit, .resetSession:
                XCTFail("Unexpected action while rendering \(keys)")
            }
        }

        return String(decoding: output, as: UTF16.self)
    }
}
