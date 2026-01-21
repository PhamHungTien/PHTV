//
//  PHTVBinaryIntegrity.m
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVBinaryIntegrity.h"

@implementation PHTVBinaryIntegrity

#pragma mark - Architecture Detection

+ (NSString *)getBinaryArchitectures {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *executablePath = [mainBundle executablePath];

    if (!executablePath) {
        return @"Unknown (no executable path)";
    }

    // Use 'file' command to check architectures
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/file"];
    [task setArguments:@[executablePath]];

    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    [task setStandardError:pipe];

    @try {
        [task launch];
        [task waitUntilExit];

        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

        // Parse output to determine architectures
        if ([output containsString:@"2 architectures"]) {
            // Universal Binary - GOOD
            if ([output containsString:@"arm64"] && [output containsString:@"x86_64"]) {
                return @"Universal (arm64 + x86_64)";
            }
            return @"Universal (2 architectures)";
        } else if ([output containsString:@"1 architecture"]) {
            // Single architecture - POTENTIALLY MODIFIED
            if ([output containsString:@"arm64"]) {
                return @"arm64 only (stripped by CleanMyMac?)";
            } else if ([output containsString:@"x86_64"]) {
                return @"x86_64 only";
            }
            return @"Single architecture";
        }

        return @"Unknown";
    } @catch (NSException *exception) {
        NSLog(@"[BinaryIntegrity] Error checking architectures: %@", exception);
        return @"Error checking";
    }
}

#pragma mark - Hash Tracking

+ (NSString *)getBinaryHash {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *executablePath = [mainBundle executablePath];

    if (!executablePath) {
        return nil;
    }

    // Calculate SHA-256 hash using shasum
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/shasum"];
    [task setArguments:@[@"-a", @"256", executablePath]];

    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];

    @try {
        [task launch];
        [task waitUntilExit];

        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

        // Parse output: "hash  filepath" → return just hash
        NSArray *components = [output componentsSeparatedByString:@" "];
        if (components.count > 0) {
            return [components[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }
    } @catch (NSException *exception) {
        NSLog(@"[BinaryIntegrity] Error calculating hash: %@", exception);
    }

    return nil;
}

+ (BOOL)hasBinaryChangedSinceLastRun {
    NSString *currentHash = [self getBinaryHash];
    if (!currentHash) {
        return NO;  // Cannot determine
    }

    // Load saved hash from UserDefaults
    NSString *savedHash = [[NSUserDefaults standardUserDefaults] stringForKey:@"BinaryHashAtLastRun"];

    if (!savedHash) {
        // First run - save current hash
        [[NSUserDefaults standardUserDefaults] setObject:currentHash forKey:@"BinaryHashAtLastRun"];
        [[NSUserDefaults standardUserDefaults] synchronize];

        NSLog(@"[BinaryIntegrity] First run - saved hash: %@...",
              [currentHash substringToIndex:MIN(16, currentHash.length)]);
        return NO;
    }

    // Compare hashes
    BOOL changed = ![currentHash isEqualToString:savedHash];

    if (changed) {
        NSLog(@"[BinaryIntegrity] 🚨 BINARY CHANGED DETECTED!");
        NSLog(@"[BinaryIntegrity] Previous: %@...",
              [savedHash substringToIndex:MIN(16, savedHash.length)]);
        NSLog(@"[BinaryIntegrity] Current:  %@...",
              [currentHash substringToIndex:MIN(16, currentHash.length)]);

        // Update saved hash
        [[NSUserDefaults standardUserDefaults] setObject:currentHash forKey:@"BinaryHashAtLastRun"];
        [[NSUserDefaults standardUserDefaults] synchronize];

        // Post notification for UI
        dispatch_async(dispatch_get_main_queue(), ^{
            NSDictionary *info = @{
                @"previousHash": savedHash,
                @"currentHash": currentHash,
                @"architecture": [self getBinaryArchitectures]
            };
            [[NSNotificationCenter defaultCenter] postNotificationName:@"BinaryChangedBetweenRuns"
                                                                object:info];
        });
    }

    return changed;
}

#pragma mark - Integrity Check

+ (BOOL)checkBinaryIntegrity {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *executablePath = [mainBundle executablePath];

    if (!executablePath) {
        NSLog(@"[BinaryIntegrity] ❌ No executable path found");
        return NO;
    }

    // Step 1: Check if binary changed since last run
    BOOL binaryChanged = [self hasBinaryChangedSinceLastRun];
    if (binaryChanged) {
        NSLog(@"[BinaryIntegrity] ⚠️ Binary was modified between app runs - likely by CleanMyMac");
    }

    // Step 2: Get architecture info
    NSString *archInfo = [self getBinaryArchitectures];
    NSLog(@"[BinaryIntegrity] Binary architecture: %@", archInfo);

    // Step 3: Verify code signature
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/codesign"];
    [task setArguments:@[@"--verify", @"--deep", @"--strict", [mainBundle bundlePath]]];

    NSPipe *pipe = [NSPipe pipe];
    [task setStandardError:pipe];

    @try {
        [task launch];
        [task waitUntilExit];

        int status = [task terminationStatus];

        if (status == 0) {
            NSLog(@"[BinaryIntegrity] ✅ Code signature is valid");

            // Warn if architecture was stripped OR binary changed
            if ([archInfo containsString:@"CleanMyMac"] || binaryChanged) {
                NSLog(@"[BinaryIntegrity] ⚠️ WARNING: Binary appears to have been modified");
                NSLog(@"[BinaryIntegrity] ⚠️ This may cause Accessibility permission issues");
                NSLog(@"[BinaryIntegrity] ⚠️ Recommendation: Reinstall app from original build");

                // Post notification for UI to show warning
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"BinaryModifiedWarning"
                                                                        object:archInfo];
                });

                return NO;  // Signature valid but binary modified
            }

            return YES;  // All good
        } else {
            NSData *errorData = [[pipe fileHandleForReading] readDataToEndOfFile];
            NSString *errorOutput = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
            NSLog(@"[BinaryIntegrity] ❌ Code signature verification failed: %@", errorOutput);

            // Post notification for UI
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"BinarySignatureInvalid"
                                                                    object:errorOutput];
            });

            return NO;
        }
    } @catch (NSException *exception) {
        NSLog(@"[BinaryIntegrity] ❌ Error verifying signature: %@", exception);
        return NO;
    }
}

@end
