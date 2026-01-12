//
//  PHTVAppDetectionManager.mm
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#import "PHTVAppDetectionManager.h"
#import "PHTVCacheManager.h"

@implementation PHTVAppDetectionManager

// App detection sets
static NSSet* _niceSpaceAppSet = nil;
static NSSet* _unicodeCompoundAppSet = nil;
static NSSet* _browserAppSet = nil;
static NSSet* _forcePrecomposedAppSet = nil;
static NSSet* _precomposedBatchedAppSet = nil;
static NSSet* _stepByStepAppSet = nil;
static NSSet* _disableVietnameseAppSet = nil;

#pragma mark - Initialization

+ (void)initialize {
    if (self == [PHTVAppDetectionManager class]) {
        // Apps that need special empty character (0x200C)
        _niceSpaceAppSet = [NSSet setWithArray:@[@"com.sublimetext.3",
                                                  @"com.sublimetext.2"]];

        // Apps with unicode compound issues
        _unicodeCompoundAppSet = [NSSet setWithArray:@[@"com.apple.",
                                                        @"com.google.Chrome",
                                                        @"com.brave.Browser",
                                                        @"com.microsoft.edgemac",
                                                        @"com.microsoft.edgemac.Dev",
                                                        @"com.microsoft.edgemac.Beta",
                                                        @"com.microsoft.Edge",
                                                        @"com.microsoft.Edge.Dev",
                                                        @"com.thebrowser.Browser",
                                                        @"company.thebrowser.dia",
                                                        @"org.chromium.Chromium",
                                                        @"com.vivaldi.Vivaldi",
                                                        @"com.operasoftware.Opera"]];

        // All browsers (36+ entries)
        _browserAppSet = [NSSet setWithArray:@[
            // Safari (WebKit)
            @"com.apple.Safari",
            @"com.apple.SafariTechnologyPreview",
            // Firefox (Gecko)
            @"org.mozilla.firefox",
            @"org.mozilla.firefoxdeveloperedition",
            @"org.mozilla.nightly",
            @"app.zen-browser.zen",
            // Chrome (all variants)
            @"com.google.Chrome",
            @"com.google.Chrome.canary",
            @"com.google.Chrome.dev",
            @"com.google.Chrome.beta",
            // Chromium-based browsers
            @"org.chromium.Chromium",
            @"com.brave.Browser",
            @"com.brave.Browser.beta",
            @"com.brave.Browser.nightly",
            // Microsoft Edge (all variants)
            @"com.microsoft.edgemac",
            @"com.microsoft.edgemac.Dev",
            @"com.microsoft.edgemac.Beta",
            @"com.microsoft.edgemac.Canary",
            @"com.microsoft.Edge",
            @"com.microsoft.Edge.Dev",
            // Arc Browser
            @"com.thebrowser.Browser",
            // Vietnamese browsers
            @"com.visualkit.browser",
            @"com.coccoc.browser",
            // Other Chromium-based browsers
            @"com.vivaldi.Vivaldi",
            @"com.operasoftware.Opera",
            @"com.operasoftware.OperaGX",
            @"com.kagi.kagimacOS",
            @"com.duckduckgo.macos.browser",
            @"com.sigmaos.sigmaos.macos",
            @"com.pushplaylabs.sidekick",
            @"com.bookry.wavebox",
            @"com.mighty.app",
            @"com.collovos.naver.whale",
            @"ru.yandex.desktop.yandex-browser",
            // Electron-based apps
            @"com.tinyspeck.slackmacgap",
            @"com.hnc.Discord",
            @"com.electron.discord",
            @"com.github.GitHubClient",
            @"com.figma.Desktop",
            @"notion.id",
            @"com.linear",
            @"com.logseq.logseq",
            @"md.obsidian"
        ]];

        // Force precomposed Unicode
        _forcePrecomposedAppSet = [NSSet setWithArray:@[@"com.apple.Spotlight",
                                                         @"com.apple.systemuiserver"]];

        // Precomposed Unicode with batched sending
        _precomposedBatchedAppSet = [NSSet setWithArray:@[@"net.whatsapp.WhatsApp",
                                                           @"notion.id"]];

        // Step-by-step key sending (timing sensitive)
        _stepByStepAppSet = [NSSet setWithArray:@[@"com.apple.loginwindow",
                                                   @"com.apple.SecurityAgent",
                                                   @"com.raycast.macos",
                                                   @"com.alfredapp.Alfred",
                                                   @"com.apple.launchpad",
                                                   @"notion.id"]];

        // Disable Vietnamese input
        _disableVietnameseAppSet = [NSSet setWithArray:@[@"com.apple.apps.launcher",
                                                          @"com.apple.ScreenContinuity"]];
    }
}

#pragma mark - Bundle ID Matching

+ (BOOL)isBrowserApp:(NSString*)bundleId {
    return [self bundleIdMatchesAppSet:bundleId appSet:_browserAppSet];
}

+ (BOOL)isTerminalApp:(NSString*)bundleId {
    if (!bundleId) return NO;

    // JetBrains IDEs
    if ([bundleId hasPrefix:@"com.jetbrains"]) {
        return YES;
    }

    static NSSet<NSString*> *terminalApps = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        terminalApps = [NSSet setWithArray:@[
            @"com.apple.Terminal",
            @"com.googlecode.iterm2",
            @"io.alacritty",
            @"com.github.wez.wezterm",
            @"com.mitchellh.ghostty",
            @"dev.warp.Warp-Stable",
            @"net.kovidgoyal.kitty",
            @"co.zeit.hyper",
            @"org.tabby",
            @"com.raphaelamorim.rio",
            @"com.termius-dmg.mac",
            @"com.microsoft.VSCode",
            @"com.microsoft.VSCodeInsiders",
            @"com.google.antigravity",
            @"dev.zed.Zed",
            @"com.sublimetext.4",
            @"com.sublimetext.3",
            @"com.panic.Nova"
        ]];
    });
    return [terminalApps containsObject:bundleId];
}

+ (BOOL)isSpotlightLikeApp:(NSString*)bundleId {
    return [self bundleIdMatchesAppSet:bundleId appSet:_forcePrecomposedAppSet];
}

+ (BOOL)needsPrecomposedBatched:(NSString*)bundleId {
    return [self bundleIdMatchesAppSet:bundleId appSet:_precomposedBatchedAppSet];
}

+ (BOOL)needsStepByStep:(NSString*)bundleId {
    return [self bundleIdMatchesAppSet:bundleId appSet:_stepByStepAppSet];
}

+ (BOOL)containsUnicodeCompound:(NSString*)bundleId {
    return [self bundleIdMatchesAppSet:bundleId appSet:_unicodeCompoundAppSet];
}

+ (BOOL)shouldDisableVietnamese:(NSString*)bundleId {
    return [self bundleIdMatchesAppSet:bundleId appSet:_disableVietnameseAppSet];
}

+ (BOOL)needsNiceSpace:(NSString*)bundleId {
    return [self bundleIdMatchesAppSet:bundleId appSet:_niceSpaceAppSet];
}

#pragma mark - Focused App Detection

+ (NSString*)getFocusedAppBundleId {
    // Placeholder - will be implemented when extracting from PHTV.mm
    return nil;
}

+ (pid_t)getFocusedAppPID {
    // Placeholder - will be implemented when extracting from PHTV.mm
    return 0;
}

#pragma mark - Utility

+ (BOOL)bundleIdMatchesAppSet:(NSString*)bundleId appSet:(NSSet*)appSet {
    if (!bundleId || !appSet) {
        return NO;
    }

    // Exact match
    if ([appSet containsObject:bundleId]) {
        return YES;
    }

    // Prefix match (for bundle IDs like "com.apple.*")
    for (NSString* pattern in appSet) {
        if ([pattern hasSuffix:@"*"]) {
            NSString* prefix = [pattern substringToIndex:[pattern length] - 1];
            if ([bundleId hasPrefix:prefix]) {
                return YES;
            }
        }
    }

    return NO;
}

@end
