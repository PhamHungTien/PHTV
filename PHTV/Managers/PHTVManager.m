//
//  PHTVManager.m
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVManager.h"

extern void PHTVInit(void);

extern CGEventRef PHTVCallback(CGEventTapProxy proxy,
                                  CGEventType type,
                                  CGEventRef event,
                                  void *refcon);

extern NSString* ConvertUtil(NSString* str);

@interface PHTVManager ()

@end

@implementation PHTVManager {

}

static BOOL _isInited = NO;

static CFMachPortRef      eventTap;
static CGEventMask        eventMask;
static CFRunLoopSourceRef runLoopSource;
static NSUInteger         _tapReenableCount = 0;
static NSUInteger         _tapRecreateCount = 0;

#pragma mark - Core Functionality

+(BOOL)isInited {
    return _isInited;
}

+(BOOL)initEventTap {
    if (_isInited)
        return true;
    
    // Initialize PHTV engine
    PHTVInit();
    
    // Create an event tap. We are interested in key presses.
    eventMask = ((1 << kCGEventKeyDown) |
                 (1 << kCGEventKeyUp) |
                 (1 << kCGEventFlagsChanged) |
                 (1 << kCGEventLeftMouseDown) |
                 (1 << kCGEventRightMouseDown) |
                 (1 << kCGEventLeftMouseDragged) |
                 (1 << kCGEventRightMouseDragged));
    
    eventTap = CGEventTapCreate(kCGSessionEventTap,
                                kCGHeadInsertEventTap,
                                0,
                                eventMask,
                                PHTVCallback,
                                NULL);
    
    if (!eventTap) {
        fprintf(stderr, "Failed to create event tap\n");
        return NO;
    }
    
    _isInited = YES;
    
    // Create a run loop source.
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    
    // Add to the MAIN run loop (don't create new run loop!)
    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, kCFRunLoopCommonModes);
    
    // Enable the event tap.
    CGEventTapEnable(eventTap, true);
    
    // IMPORTANT: Do NOT call CFRunLoopRun() here!
    // The main run loop is already running. Calling CFRunLoopRun() would:
    // 1. Block the current thread indefinitely
    // 2. Prevent UI updates and menu bar interactions
    // 3. Make the app unresponsive
    //
    // The event tap will receive events automatically from the main run loop.
    
    NSLog(@"[EventTap] Enabled and added to main run loop");
    
    return YES;
}

+(BOOL)stopEventTap {
    if (_isInited) {
        NSLog(@"[EventTap] Stopping...");
        
        // Disable the event tap first
        CGEventTapEnable(eventTap, false);
        
        // Remove from run loop
        CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, kCFRunLoopCommonModes);
        CFRelease(runLoopSource);
        runLoopSource = nil;
        
        // Invalidate and release the event tap
        CFMachPortInvalidate(eventTap);
        CFRelease(eventTap);
        eventTap = nil;
        
        _isInited = false;
        
        NSLog(@"[EventTap] Stopped successfully");
    }
    return YES;
}

// Recover when the event tap is disabled by the system (timeout/user input)
+(void)handleEventTapDisabled:(CGEventType)type {
    if (!_isInited) return;

    const char *reason = (type == kCGEventTapDisabledByTimeout) ? "timeout" : "user input";
    NSLog(@"[EventTap] Disabled by %s — attempting to re-enable", reason);

    _tapReenableCount++;
    CGEventTapEnable(eventTap, true);

    // If re-enable failed (tap still disabled), recreate it on the main queue to avoid deadlocks
    if (!CGEventTapIsEnabled(eventTap)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!_isInited) return;
            NSLog(@"[EventTap] Re-enabling failed, recreating event tap");
            _tapRecreateCount++;
            [self stopEventTap];
            [self initEventTap];
        });
    }
}

// Query current state of the tap
+(BOOL)isEventTapEnabled {
    if (!_isInited || eventTap == nil) return NO;
    return CGEventTapIsEnabled(eventTap);
}

// Ensure the tap stays alive for long-running sessions
+(void)ensureEventTapAlive {
    if (!_isInited) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!_isInited) {
                [self initEventTap];
            }
        });
        return;
    }

    if (eventTap == nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self initEventTap];
        });
        return;
    }

    // Check if tap is disabled OR not receiving events properly
    BOOL isEnabled = CGEventTapIsEnabled(eventTap);
    
    if (!isEnabled) {
        _tapReenableCount++;
        NSLog(@"[EventTap] Health check: tap disabled — re-enabling (count=%lu)", (unsigned long)_tapReenableCount);
        CGEventTapEnable(eventTap, true);

        if (!CGEventTapIsEnabled(eventTap)) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!_isInited) return;
                _tapRecreateCount++;
                NSLog(@"[EventTap] Health check: re-enable failed — recreating tap (count=%lu)", (unsigned long)_tapRecreateCount);
                [self stopEventTap];
                [self initEventTap];
            });
        }
    } else {
        // Proactive: even if enabled, give it a quick re-enable nudge to keep it alive
        // This prevents macOS from silently disabling it
        CGEventTapEnable(eventTap, true);
    }
}

#pragma mark - Table Codes

+(NSArray*)getTableCodes {
    return [[NSArray alloc] initWithObjects:
            @"Unicode",
            @"TCVN3 (ABC)",
            @"VNI Windows",
            @"Unicode tổ hợp",
            @"Vietnamese Locale CP 1258", nil];
}

#pragma mark - Utilities

+(NSString*)getBuildDate {
    return [NSString stringWithUTF8String:__DATE__];
}

+(void)showMessage:(NSWindow*)window message:(NSString*)msg subMsg:(NSString*)subMsg {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:msg];
    [alert setInformativeText:subMsg];
    [alert addButtonWithTitle:@"OK"];
    if (window) {
        [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
        }];
    } else {
        [alert runModal];
    }
}

#pragma mark - Convert Feature

+(BOOL)quickConvert {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSString *htmlString = [pasteboard stringForType:NSPasteboardTypeHTML];
    NSString *rawString = [pasteboard stringForType:NSPasteboardTypeString];
    bool converted = false;
    
    if (htmlString != nil) {
        htmlString = ConvertUtil(htmlString);
        converted = true;
    }
    if (rawString != nil) {
        rawString = ConvertUtil(rawString);
        converted = true;
    }
    if (converted) {
        [pasteboard clearContents];
        if (htmlString != nil)
            [pasteboard setString:htmlString forType:NSPasteboardTypeHTML];
        if (rawString != nil)
            [pasteboard setString:rawString forType:NSPasteboardTypeString];
        
        return YES;
    }
    return NO;
}

#pragma mark - Application Support

+(NSString*)getApplicationSupportFolder {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *applicationSupportDirectory = [paths firstObject];
    return [NSString stringWithFormat:@"%@/PHTV", applicationSupportDirectory];
}

@end
