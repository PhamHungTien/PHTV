//
//  NativeTextReplacementTypingTests.swift
//  PHTV
//
//  Regression coverage for issue #244: with "Dùng Text Replacements của
//  macOS" on, AI chat boxes leave shortcut expansion to macOS. A word that
//  only starts like a native shortcut (o… → omw, d… → dtd) must still be
//  composed as Vietnamese, including right after a space.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
@testable import PHTV

final class NativeTextReplacementTypingTests: XCTestCase {
    /// The defaults macOS ships for a Vietnamese user.
    private let systemReplacements: [[String: Any]] = [
        ["replace": "omw", "with": "On my way!", "on": 1],
        ["replace": "dtd", "with": "Đang trên đường!", "on": 1]
    ]

    override func setUp() {
        super.setUp()
        PHTVEngineRuntimeFacade.setCurrentLanguage(1)   // Vietnamese
        PHTVEngineRuntimeFacade.setCurrentInputType(0)  // Telex
        PHTVEngineRuntimeFacade.setCurrentCodeTable(0)  // Unicode
        PHTVEngineRuntimeFacade.setUseMacro(1)
        PHTVEngineRuntimeFacade.setQuickTelex(0)
        PHTVEngineRuntimeFacade.setAutoCapsMacro(0)
        PHTVEngineRuntimeFacade.setCheckSpelling(1)
        engineInitialize()
        loadMacros(PHTVSystemTextReplacementService.mergedRuntimeMacros(
            userMacros: [],
            useSystemTextReplacements: true,
            rawItems: systemReplacements
        ))
        PHTVEngineRuntimeFacade.setNativeSystemTextReplacementMode(true)
    }

    override func tearDown() {
        PHTVEngineRuntimeFacade.setNativeSystemTextReplacementMode(false)
        loadMacros([])
        PHTVEngineRuntimeFacade.setUseMacro(0)
        PHTVEngineRuntimeFacade.setUseModernOrthography(1)
        engineInitialize()
        super.tearDown()
    }

    func testWordsAfterSpaceStillComposeWhenTheyStartLikeANativeShortcut() {
        for modern: Int32 in [0, 1] {
            PHTVEngineRuntimeFacade.setUseModernOrthography(modern)
            XCTAssertEqual(screen(afterTyping: "anh owr nhaf ddungs khoong ddi"),
                           "anh ở nhà đúng không đi", "modern=\(modern)")
            XCTAssertEqual(screen(afterTyping: "tooi ddang oong ddaay"),
                           "tôi đang ông đây", "modern=\(modern)")
            XCTAssertEqual(screen(afterTyping: "vaayj, owr ddos"),
                           "vậy, ở đó", "modern=\(modern)")
        }
    }

    func testWordsAtStartOfInputComposeWhenTheyStartLikeANativeShortcut() {
        XCTAssertEqual(screen(afterTyping: "owr"), "ở")
        XCTAssertEqual(screen(afterTyping: "ddi"), "đi")
        XCTAssertEqual(screen(afterTyping: "Ddi"), "Đi")
    }

    func testNativeShortcutStaysRawSoMacOSCanExpandIt() {
        XCTAssertEqual(screen(afterTyping: "omw"), "omw")
        XCTAssertEqual(screen(afterTyping: "anh omw"), "anh omw")
        XCTAssertEqual(screen(afterTyping: "tooi dtd"), "tôi dtd")
    }

    // MARK: - Helpers

    private func loadMacros(_ macros: [MacroItem]) {
        PHTVEngineDataBridge.initializeMacroMap(with: MacroStorage.engineBinaryData(from: macros))
    }

    /// Feeds `text` key by key and applies each engine decision the way the
    /// event tap does: pass the physical key through, or delete `hBPC`
    /// characters and insert the engine's output.
    private func screen(afterTyping text: String) -> String {
        // A local engine keeps the keystroke sequence atomic in app-hosted tests.
        let engine = PHTVVietnameseEngine()
        engine.refreshRuntimeLayoutSnapshot()
        engine.startNewSession()
        var screen: [Character] = []

        for character in text {
            let isUppercase = character.isUppercase
            engine.vKeyHandleEvent(
                event: .keyboard,
                state: .keyDown,
                data: keyCode(for: Character(character.lowercased())),
                capsStatus: isUppercase ? 1 : 0,
                otherControlKey: false
            )

            switch engine.hCode {
            case HookCodeState.willProcess.rawValue:
                screen.removeLast(min(engine.hBPC, screen.count))
                screen.append(contentsOf: emittedText(engine))
            case HookCodeState.restore.rawValue, HookCodeState.restoreAndStartNewSession.rawValue:
                screen.removeLast(min(engine.hBPC, screen.count))
                screen.append(contentsOf: emittedText(engine))
                screen.append(character)
            case HookCodeState.replaceMacro.rawValue:
                XCTFail("PHTV must leave native shortcuts to macOS: \(text)")
                return String(screen)
            default:
                screen.append(character)
            }
        }
        return String(screen)
    }

    private func emittedText(_ engine: PHTVVietnameseEngine) -> String {
        guard engine.hNCC > 0 else { return "" }
        var scalars = String.UnicodeScalarView()
        for index in stride(from: engine.hNCC - 1, through: 0, by: -1) {
            let data = engine.hData[index]
            let codePoint: UInt32
            if (data & EngineBitMask.pureCharacter) != 0 {
                codePoint = data & ~EngineBitMask.caps
            } else if (data & EngineBitMask.charCode) == 0 {
                codePoint = UInt32(EngineMacroKeyMap.character(for: data))
            } else {
                codePoint = data & 0xFFFF
            }
            if codePoint != 0, let scalar = UnicodeScalar(codePoint) {
                scalars.append(scalar)
            }
        }
        return String(scalars)
    }

    private func keyCode(for character: Character) -> UInt16 {
        switch character {
        case "a": return KEY_A; case "b": return KEY_B; case "c": return KEY_C
        case "d": return KEY_D; case "e": return KEY_E; case "f": return KEY_F
        case "g": return KEY_G; case "h": return KEY_H; case "i": return KEY_I
        case "j": return KEY_J; case "k": return KEY_K; case "l": return KEY_L
        case "m": return KEY_M; case "n": return KEY_N; case "o": return KEY_O
        case "p": return KEY_P; case "q": return KEY_Q; case "r": return KEY_R
        case "s": return KEY_S; case "t": return KEY_T; case "u": return KEY_U
        case "v": return KEY_V; case "w": return KEY_W; case "x": return KEY_X
        case "y": return KEY_Y; case "z": return KEY_Z
        case ",": return KEY_COMMA; case ".": return KEY_DOT
        default: return KEY_SPACE
        }
    }
}
