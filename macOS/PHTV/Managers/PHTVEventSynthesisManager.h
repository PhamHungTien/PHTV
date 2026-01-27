//
//  PHTVEventSynthesisManager.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#ifndef PHTVEventSynthesisManager_h
#define PHTVEventSynthesisManager_h

#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Carbon/Carbon.h>
#import "PHTVTimingManager.h"

// C++ interop for engine types
#ifdef __cplusplus
#include <vector>
typedef uint16_t Uint16;
typedef uint32_t Uint32;
typedef uint8_t Byte;
#else
typedef uint16_t Uint16;
typedef uint32_t Uint32;
typedef uint8_t Byte;
#endif

@interface PHTVEventSynthesisManager : NSObject

// Initialization
+ (void)initialize;
+ (void)initializeEventSource;
+ (CGEventSourceRef)getEventSource;

// Core Send Functions
+ (void)sendPureCharacter:(Uint16)ch;
+ (void)sendKeyCode:(Uint32)data;
+ (void)sendVirtualKey:(Byte)vKey;
+ (void)sendEmptyCharacter;
+ (void)sendPhysicalBackspace;
+ (void)sendBackspace;
+ (void)sendShiftAndLeftArrow;

// Batch Operations
+ (void)sendBackspaceSequence:(int)count isTerminalApp:(BOOL)isTerminal;
+ (void)sendBackspaceSequenceWithDelay:(int)count delayType:(DelayType)delayType;
+ (void)sendNewCharString:(BOOL)dataFromMacro offset:(Uint16)offset;

// Utilities
+ (void)sendCutKey;
+ (void)postSyntheticEvent:(CGEventTapProxy)proxy event:(CGEventRef)event;

// Sync Key Management (for VNI/Unicode Compound)
+ (void)insertKeyLength:(Uint16)length;
+ (void)clearSyncKey;
+ (NSUInteger)getSyncKeyCount;

// Proxy and Flags
+ (void)setCurrentProxy:(CGEventTapProxy)proxy;
+ (CGEventTapProxy)getCurrentProxy;
+ (void)setCurrentFlags:(CGEventFlags)flags;
+ (CGEventFlags)getCurrentFlags;

@end

#endif /* PHTVEventSynthesisManager_h */
