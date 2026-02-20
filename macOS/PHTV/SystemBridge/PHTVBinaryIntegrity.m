//
//  PHTVBinaryIntegrity.m
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVBinaryIntegrity.h"
#import "PHTV-Swift.h"

@implementation PHTVBinaryIntegrity

#pragma mark - Architecture Detection

+ (NSString *)getBinaryArchitectures {
    return [PHTVBinaryIntegrityService getBinaryArchitectures];
}

#pragma mark - Hash Tracking

+ (NSString *)getBinaryHash {
    return [PHTVBinaryIntegrityService getBinaryHash];
}

+ (BOOL)hasBinaryChangedSinceLastRun {
    return [PHTVBinaryIntegrityService hasBinaryChangedSinceLastRun];
}

#pragma mark - Integrity Check

+ (BOOL)checkBinaryIntegrity {
    return [PHTVBinaryIntegrityService checkBinaryIntegrity];
}

@end
