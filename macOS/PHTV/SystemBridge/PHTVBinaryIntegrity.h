//
//  PHTVBinaryIntegrity.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#ifndef PHTVBinaryIntegrity_h
#define PHTVBinaryIntegrity_h

#import <Foundation/Foundation.h>

/**
 Binary Integrity Protection System

 Detects and warns when the app binary is modified by optimization tools
 like CleanMyMac, which can cause TCC (Transparency, Consent, and Control)
 to revoke Accessibility permissions.

 Key features:
 - SHA-256 hash tracking between app launches
 - Architecture detection (Universal vs arm64-only)
 - Code signature verification
 - Automatic warning notifications
 */
@interface PHTVBinaryIntegrity : NSObject

#pragma mark - Architecture Detection

/**
 Returns human-readable architecture information.

 @return String like "Universal (arm64 + x86_64)" or "arm64 only (stripped by CleanMyMac?)"
 */
+ (NSString *)getBinaryArchitectures;

#pragma mark - Hash Tracking

/**
 Calculates SHA-256 hash of the executable binary.

 @return 64-character hex string of SHA-256 hash, or nil if error
 */
+ (NSString *)getBinaryHash;

/**
 Checks if binary changed since last app run.

 Compares current binary hash with saved hash from UserDefaults.
 Automatically saves new hash if changed.
 Posts "BinaryChangedBetweenRuns" notification if changed.

 @return YES if binary hash changed, NO if same or first run
 */
+ (BOOL)hasBinaryChangedSinceLastRun;

#pragma mark - Integrity Check

/**
 Performs comprehensive binary integrity check.

 Checks:
 1. Binary hash comparison (detect modifications)
 2. Architecture (detect Universal Binary stripping)
 3. Code signature validity

 Posts notifications:
 - "BinaryModifiedWarning" if stripped or changed
 - "BinarySignatureInvalid" if signature broken

 @return YES if binary is intact, NO if modified or invalid
 */
+ (BOOL)checkBinaryIntegrity;

@end

#endif /* PHTVBinaryIntegrity_h */
