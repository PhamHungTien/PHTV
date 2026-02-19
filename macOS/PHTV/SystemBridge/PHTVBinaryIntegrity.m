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

    // Prefer lipo for robust architecture listing.
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/lipo"];
    [task setArguments:@[@"-archs", executablePath]];

    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    [task setStandardError:pipe];

    @try {
        [task launch];
        [task waitUntilExit];

        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

        if (task.terminationStatus == 0) {
            NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
            NSArray<NSString *> *tokens = [[output stringByTrimmingCharactersInSet:whitespace]
                                           componentsSeparatedByCharactersInSet:whitespace];
            NSSet<NSString *> *knownArchitectures = [NSSet setWithArray:@[@"arm64", @"arm64e", @"x86_64", @"i386"]];
            NSMutableArray<NSString *> *architectures = [NSMutableArray array];

            for (NSString *token in tokens) {
                if (token.length == 0) { continue; }
                if ([knownArchitectures containsObject:token]) {
                    [architectures addObject:token];
                }
            }

            if (architectures.count >= 2 &&
                [architectures containsObject:@"arm64"] &&
                [architectures containsObject:@"x86_64"]) {
                return @"Universal (arm64 + x86_64)";
            }
            if (architectures.count == 1) {
                return [NSString stringWithFormat:@"%@ only", architectures.firstObject];
            }
            if (architectures.count > 1) {
                return [NSString stringWithFormat:@"Multiple (%@)", [architectures componentsJoinedByString:@" + "]];
            }
        }

        // Fallback for environments where lipo is unavailable.
        NSTask *fallbackTask = [[NSTask alloc] init];
        [fallbackTask setLaunchPath:@"/usr/bin/file"];
        [fallbackTask setArguments:@[executablePath]];

        NSPipe *fallbackPipe = [NSPipe pipe];
        [fallbackTask setStandardOutput:fallbackPipe];
        [fallbackTask setStandardError:fallbackPipe];

        [fallbackTask launch];
        [fallbackTask waitUntilExit];

        NSData *fallbackData = [[fallbackPipe fileHandleForReading] readDataToEndOfFile];
        NSString *fallbackOutput = [[NSString alloc] initWithData:fallbackData encoding:NSUTF8StringEncoding];
        if ([fallbackOutput containsString:@"arm64"] && [fallbackOutput containsString:@"x86_64"]) {
            return @"Universal (arm64 + x86_64)";
        }
        if ([fallbackOutput containsString:@"arm64"]) {
            return @"arm64 only";
        }
        if ([fallbackOutput containsString:@"x86_64"]) {
            return @"x86_64 only";
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
        NSLog(@"[BinaryIntegrity] ⚠️ Binary hash changed since last run");
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

            // Warn if hash changed, but keep app healthy when signature stays valid.
            if (binaryChanged) {
                NSLog(@"[BinaryIntegrity] ⚠️ WARNING: Binary appears to have been modified");
                NSLog(@"[BinaryIntegrity] ⚠️ This may cause Accessibility permission issues");
                NSLog(@"[BinaryIntegrity] ⚠️ Recommendation: Reinstall app from original build");

                // Post notification for UI to show warning
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"BinaryModifiedWarning"
                                                                        object:archInfo];
                });
            }

            return YES;
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
