//
//  SingleModifierHotkeyTests.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
import AppKit
@testable import PHTV

final class SingleModifierHotkeyTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        PHTVModifierRuntimeStateService.resetTransientHotkeyState(savedLanguage: 1)
    }

    func testIsSingleModifierKeyHelper() {
        let leftOptionMask = Int32(1 << SingleModifierKey.leftOption.rawValue)
        let rightOptionMask = Int32(1 << SingleModifierKey.rightOption.rawValue)
        
        // Left Option keycode is 58
        XCTAssertTrue(PHTVHotkeyService.isSingleModifierKey(keyCode: 58, mask: leftOptionMask))
        XCTAssertFalse(PHTVHotkeyService.isSingleModifierKey(keyCode: 58, mask: rightOptionMask))
        
        // Right Option keycode is 61
        XCTAssertTrue(PHTVHotkeyService.isSingleModifierKey(keyCode: 61, mask: rightOptionMask))
        XCTAssertFalse(PHTVHotkeyService.isSingleModifierKey(keyCode: 61, mask: leftOptionMask))
        
        // Left Control keycode is 59
        let leftControlMask = Int32(1 << SingleModifierKey.leftControl.rawValue)
        XCTAssertTrue(PHTVHotkeyService.isSingleModifierKey(keyCode: 59, mask: leftControlMask))
        XCTAssertFalse(PHTVHotkeyService.isSingleModifierKey(keyCode: 59, mask: leftOptionMask))
    }
    
    func testCleanPressAndReleaseTriggersLanguageSwitch() {
        // 1. Simulate Press Left Option (keycode: 58)
        let pressResult = PHTVEventContextBridgeService.handleModifierPress(
            withFlags: UInt64(CGEventFlags.maskAlternate.rawValue),
            keyCode: 58,
            restoreOnEscape: 0,
            customEscapeKey: 0,
            pauseKeyEnabled: 0,
            pauseKeyCode: 0,
            currentLanguage: 1,
            switchHotkey: 58,
            switchHotkey2: 0
        )
        
        XCTAssertEqual(PHTVModifierRuntimeStateService.singleModifierSwitchPressedKeyValue(), 58)
        XCTAssertFalse(PHTVModifierRuntimeStateService.keyPressedWhileSingleModifierHeldValue())
        XCTAssertFalse(pressResult.shouldUpdateLanguage)
        
        // 2. Simulate Release Left Option (keycode: 58)
        let releaseResult = PHTVEventContextBridgeService.handleModifierRelease(
            oldFlags: UInt64(CGEventFlags.maskAlternate.rawValue),
            newFlags: 0,
            keyCode: 58,
            restoreOnEscape: 0,
            customEscapeKey: 0,
            switchHotkey: 58,
            switchHotkey2: 0,
            convertHotkey: 0,
            emojiEnabled: 0,
            emojiModifiers: 0,
            emojiKeyCode: 0,
            tempOffSpellingEnabled: 0,
            tempOffEngineEnabled: 0,
            pauseKeyEnabled: 0,
            pauseKeyCode: 0,
            currentLanguage: 1
        )
        
        XCTAssertEqual(releaseResult.releaseAction, PHTVModifierReleaseAction.switchLanguage.rawValue)
        XCTAssertEqual(PHTVModifierRuntimeStateService.singleModifierSwitchPressedKeyValue(), 0)
        XCTAssertFalse(PHTVModifierRuntimeStateService.keyPressedWhileSingleModifierHeldValue())
    }
    
    func testTypingDuringModifierHoldBlocksSwitch() {
        // 1. Press Left Option (keycode: 58)
        _ = PHTVEventContextBridgeService.handleModifierPress(
            withFlags: UInt64(CGEventFlags.maskAlternate.rawValue),
            keyCode: 58,
            restoreOnEscape: 0,
            customEscapeKey: 0,
            pauseKeyEnabled: 0,
            pauseKeyCode: 0,
            currentLanguage: 1,
            switchHotkey: 58,
            switchHotkey2: 0
        )
        
        XCTAssertEqual(PHTVModifierRuntimeStateService.singleModifierSwitchPressedKeyValue(), 58)
        XCTAssertFalse(PHTVModifierRuntimeStateService.keyPressedWhileSingleModifierHeldValue())
        
        // 2. Simulate Key Down (e.g. key A) while held
        PHTVEventContextBridgeService.applyKeyDownModifierTracking(
            forFlags: UInt64(CGEventFlags.maskAlternate.rawValue),
            restoreOnEscape: 0,
            customEscapeKey: 0,
            switchHotkey: 0,
            switchHotkey2: 0,
            convertHotkey: 0,
            emojiEnabled: 0,
            emojiModifiers: 0,
            emojiHotkeyKeyCode: 0
        )
        
        XCTAssertTrue(PHTVModifierRuntimeStateService.keyPressedWhileSingleModifierHeldValue())
        
        // 3. Release Left Option (keycode: 58)
        let releaseResult = PHTVEventContextBridgeService.handleModifierRelease(
            oldFlags: UInt64(CGEventFlags.maskAlternate.rawValue),
            newFlags: 0,
            keyCode: 58,
            restoreOnEscape: 0,
            customEscapeKey: 0,
            switchHotkey: 58,
            switchHotkey2: 0,
            convertHotkey: 0,
            emojiEnabled: 0,
            emojiModifiers: 0,
            emojiKeyCode: 0,
            tempOffSpellingEnabled: 0,
            tempOffEngineEnabled: 0,
            pauseKeyEnabled: 0,
            pauseKeyCode: 0,
            currentLanguage: 1
        )
        
        XCTAssertEqual(releaseResult.releaseAction, PHTVModifierReleaseAction.none.rawValue)
        XCTAssertEqual(PHTVModifierRuntimeStateService.singleModifierSwitchPressedKeyValue(), 0)
        XCTAssertFalse(PHTVModifierRuntimeStateService.keyPressedWhileSingleModifierHeldValue())
    }

    func testPressingSecondModifierBlocksSwitch() {
        // 1. Press Left Option (keycode: 58)
        _ = PHTVEventContextBridgeService.handleModifierPress(
            withFlags: UInt64(CGEventFlags.maskAlternate.rawValue),
            keyCode: 58,
            restoreOnEscape: 0,
            customEscapeKey: 0,
            pauseKeyEnabled: 0,
            pauseKeyCode: 0,
            currentLanguage: 1,
            switchHotkey: 58,
            switchHotkey2: 0
        )
        
        XCTAssertEqual(PHTVModifierRuntimeStateService.singleModifierSwitchPressedKeyValue(), 58)
        
        // 2. Press Left Command (keycode: 55)
        _ = PHTVEventContextBridgeService.handleModifierPress(
            withFlags: UInt64(CGEventFlags.maskAlternate.rawValue | CGEventFlags.maskCommand.rawValue),
            keyCode: 55,
            restoreOnEscape: 0,
            customEscapeKey: 0,
            pauseKeyEnabled: 0,
            pauseKeyCode: 0,
            currentLanguage: 1,
            switchHotkey: 58,
            switchHotkey2: 0
        )
        
        XCTAssertTrue(PHTVModifierRuntimeStateService.keyPressedWhileSingleModifierHeldValue())
        
        // 3. Release Left Option (keycode: 58)
        let releaseResult = PHTVEventContextBridgeService.handleModifierRelease(
            oldFlags: UInt64(CGEventFlags.maskAlternate.rawValue | CGEventFlags.maskCommand.rawValue),
            newFlags: UInt64(CGEventFlags.maskCommand.rawValue),
            keyCode: 58,
            restoreOnEscape: 0,
            customEscapeKey: 0,
            switchHotkey: 58,
            switchHotkey2: 0,
            convertHotkey: 0,
            emojiEnabled: 0,
            emojiModifiers: 0,
            emojiKeyCode: 0,
            tempOffSpellingEnabled: 0,
            tempOffEngineEnabled: 0,
            pauseKeyEnabled: 0,
            pauseKeyCode: 0,
            currentLanguage: 1
        )
        
        XCTAssertEqual(releaseResult.releaseAction, PHTVModifierReleaseAction.none.rawValue)
    }
}
