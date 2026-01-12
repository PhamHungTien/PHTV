//
//  PHTVEventSynthesisManager.mm
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVEventSynthesisManager.h"
#import "PHTVAppDetectionManager.h"
#import "PHTVTimingManager.h"
#import <vector>

@implementation PHTVEventSynthesisManager

// Event source and state
static CGEventSourceRef _myEventSource = NULL;
static CGEventRef _eventBackSpaceDown = NULL;
static CGEventRef _eventBackSpaceUp = NULL;
static CGEventTapProxy _currentProxy = NULL;
static CGEventFlags _currentFlags = 0;

// Sync key tracking (for VNI/Unicode Compound)
static std::vector<Uint16> _syncKey;

#pragma mark - Initialization

+ (void)initialize {
    if (self == [PHTVEventSynthesisManager class]) {
        // Reserve capacity for sync key vector
        _syncKey.reserve(256);
    }
}

+ (void)initializeEventSource {
    if (_myEventSource == NULL) {
        _myEventSource = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);

        // Pre-create backspace events for performance
        _eventBackSpaceDown = CGEventCreateKeyboardEvent(_myEventSource, (CGKeyCode)51, true);
        _eventBackSpaceUp = CGEventCreateKeyboardEvent(_myEventSource, (CGKeyCode)51, false);
    }
}

+ (CGEventSourceRef)getEventSource {
    if (_myEventSource == NULL) {
        [self initializeEventSource];
    }
    return _myEventSource;
}

#pragma mark - Core Send Functions

+ (void)sendPureCharacter:(Uint16)ch {
    // Placeholder - will be implemented when extracting from PHTV.mm
}

+ (void)sendKeyCode:(Uint32)data {
    // Placeholder - will be implemented when extracting from PHTV.mm
}

+ (void)sendVirtualKey:(Byte)vKey {
    // Placeholder - will be implemented when extracting from PHTV.mm
}

+ (void)sendEmptyCharacter {
    // Placeholder - will be implemented when extracting from PHTV.mm
}

+ (void)sendPhysicalBackspace {
    // Placeholder - will be implemented when extracting from PHTV.mm
}

+ (void)sendBackspace {
    // Placeholder - will be implemented when extracting from PHTV.mm
}

+ (void)sendShiftAndLeftArrow {
    // Placeholder - will be implemented when extracting from PHTV.mm
}

#pragma mark - Batch Operations

+ (void)sendBackspaceSequence:(int)count isTerminalApp:(BOOL)isTerminal {
    // Placeholder - will be implemented when extracting from PHTV.mm
}

+ (void)sendBackspaceSequenceWithDelay:(int)count delayType:(DelayType)delayType {
    // Placeholder - will be implemented when extracting from PHTV.mm
}

+ (void)sendNewCharString:(BOOL)dataFromMacro offset:(Uint16)offset {
    // Placeholder - will be implemented when extracting from PHTV.mm
}

#pragma mark - Utilities

+ (void)sendCutKey {
    // Send Cmd+X
    CGEventRef cutDown = CGEventCreateKeyboardEvent([self getEventSource], (CGKeyCode)7, true); // X key
    CGEventSetFlags(cutDown, kCGEventFlagMaskCommand);
    CGEventRef cutUp = CGEventCreateKeyboardEvent([self getEventSource], (CGKeyCode)7, false);

    CGEventPost(kCGHIDEventTap, cutDown);
    CGEventPost(kCGHIDEventTap, cutUp);

    CFRelease(cutDown);
    CFRelease(cutUp);
}

+ (void)postSyntheticEvent:(CGEventTapProxy)proxy event:(CGEventRef)event {
    CGEventPost(kCGHIDEventTap, event);
}

#pragma mark - Sync Key Management

+ (void)insertKeyLength:(Uint16)length {
    _syncKey.push_back(length);
}

+ (void)clearSyncKey {
    _syncKey.clear();
}

+ (NSUInteger)getSyncKeyCount {
    return _syncKey.size();
}

#pragma mark - Proxy and Flags

+ (void)setCurrentProxy:(CGEventTapProxy)proxy {
    _currentProxy = proxy;
}

+ (CGEventTapProxy)getCurrentProxy {
    return _currentProxy;
}

+ (void)setCurrentFlags:(CGEventFlags)flags {
    _currentFlags = flags;
}

+ (CGEventFlags)getCurrentFlags {
    return _currentFlags;
}

@end
