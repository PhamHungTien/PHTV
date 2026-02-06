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
static NSSet* _safariAppSet = nil;  // Safari always uses Shift+Left strategy
static NSSet* _browserAppSet = nil;
static NSSet* _terminalAppSet = nil;
static NSSet* _fastTerminalAppSet = nil;
static NSSet* _mediumTerminalAppSet = nil;
static NSSet* _slowTerminalAppSet = nil;
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

        // Safari set - used for specific Safari optimizations (Shift+Left strategy)
        _safariAppSet = [NSSet setWithArray:@[@"com.apple.Safari",
                                              @"com.apple.SafariTechnologyPreview",
                                              @"com.apple.Safari.WebApp.*"]];

        // Apps with unicode compound issues (Safari + Chromium-based browsers)
        _unicodeCompoundAppSet = [NSSet setWithArray:@[
                                                        // Safari (WebKit) - needs same compound handling as Chromium
                                                        @"com.apple.Safari",
                                                        @"com.apple.SafariTechnologyPreview",
                                                        @"com.apple.Safari.WebApp.*",
                                                        // Chromium-based browsers
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
                                                        @"com.operasoftware.Opera",
                                                        @"notion.id",
                                                        // Chromium-based PWAs/Web Apps
                                                        @"com.google.Chrome.app.*",
                                                        @"com.brave.Browser.app.*",
                                                        @"com.microsoft.edgemac.app.*",
                                                        @"com.microsoft.edgemac.Dev.app.*",
                                                        @"com.microsoft.edgemac.Beta.app.*",
                                                        @"com.microsoft.Edge.app.*",
                                                        @"com.microsoft.Edge.Dev.app.*",
                                                        @"com.thebrowser.Browser.app.*",
                                                        @"org.chromium.Chromium.app.*",
                                                        @"com.vivaldi.Vivaldi.app.*",
                                                        @"com.operasoftware.Opera.app.*"]];

        // All browsers (36+ entries)
        _browserAppSet = [NSSet setWithArray:@[
            // Safari (WebKit)
            @"com.apple.Safari",
            @"com.apple.SafariTechnologyPreview",
            @"com.apple.Safari.WebApp.*",
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
            // AI-powered browsers
            @"ai.perplexity.comet",
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
            // Chromium-based PWAs/Web Apps (installed via "Install as App" / "Add to Dock")
            // Pattern: {BaseBundleID}.app.{profile}-{app_id}
            @"com.google.Chrome.app.*",
            @"com.google.Chrome.canary.app.*",
            @"com.google.Chrome.dev.app.*",
            @"com.google.Chrome.beta.app.*",
            @"org.chromium.Chromium.app.*",
            @"com.brave.Browser.app.*",
            @"com.brave.Browser.beta.app.*",
            @"com.brave.Browser.nightly.app.*",
            @"com.microsoft.edgemac.app.*",
            @"com.microsoft.edgemac.Dev.app.*",
            @"com.microsoft.edgemac.Beta.app.*",
            @"com.microsoft.edgemac.Canary.app.*",
            @"com.microsoft.Edge.app.*",
            @"com.microsoft.Edge.Dev.app.*",
            @"com.thebrowser.Browser.app.*",
            @"com.vivaldi.Vivaldi.app.*",
            @"com.operasoftware.Opera.app.*",
            @"com.operasoftware.OperaGX.app.*",
            @"com.coccoc.browser.app.*",
            @"com.kagi.kagimacOS.app.*",
            @"com.sigmaos.sigmaos.macos.app.*",
            @"com.pushplaylabs.sidekick.app.*",
            @"com.bookry.wavebox.app.*",
            @"com.collovos.naver.whale.app.*",
            @"ru.yandex.desktop.yandex-browser.app.*",
            // Electron-based apps
            @"com.tinyspeck.slackmacgap",
            @"com.hnc.Discord",
            @"com.electron.discord",
            @"com.github.GitHubClient",
            @"com.figma.Desktop",
            @"com.linear",
            @"com.logseq.logseq",
            @"md.obsidian"
        ]];

        // Terminal apps (CLI)
        _terminalAppSet = [NSSet setWithArray:@[
            // Apple Terminal
            @"com.apple.Terminal",
            // Fast terminals (GPU-accelerated)
            @"io.alacritty",
            @"com.mitchellh.ghostty",
            @"net.kovidgoyal.kitty",
            @"com.github.wez.wezterm",
            @"com.raphaelamorim.rio",
            // Medium speed terminals
            @"com.googlecode.iterm2",
            @"dev.warp.Warp-Stable",
            @"co.zeit.hyper",
            @"org.tabby",
            @"com.termius-dmg.mac"
        ]];

        // Fast terminals (lower delay)
        _fastTerminalAppSet = [NSSet setWithArray:@[
            @"io.alacritty",
            @"com.mitchellh.ghostty",
            @"com.raphaelamorim.rio"
        ]];

        // Medium terminals (balanced delay)
        _mediumTerminalAppSet = [NSSet setWithArray:@[
            @"com.apple.Terminal",
            @"net.kovidgoyal.kitty",
            @"com.github.wez.wezterm",
            @"com.googlecode.iterm2",
            @"dev.warp.Warp-Stable",
            @"co.zeit.hyper",
            @"org.tabby",
            @"com.termius-dmg.mac"
        ]];

        // Slow terminals (reserved for apps that still drop chars with medium delays)
        _slowTerminalAppSet = [NSSet setWithArray:@[]];

        // Force precomposed Unicode
        _forcePrecomposedAppSet = [NSSet setWithArray:@[@"com.apple.Spotlight",
                                                         @"com.apple.systemuiserver",
                                                         @"com.raycast.*"]];

        // Precomposed Unicode with batched sending
        _precomposedBatchedAppSet = [NSSet setWithArray:@[@"net.whatsapp.WhatsApp",
                                                           @"notion.id"]];

        // Step-by-step key sending (timing sensitive)
        _stepByStepAppSet = [NSSet setWithArray:@[@"com.apple.loginwindow",
                                                   @"com.apple.SecurityAgent",
                                                   @"com.alfredapp.Alfred",
                                                   @"com.apple.launchpad",
                                                   @"notion.id",
                                                   @"com.apple.Safari",
                                                   @"com.apple.SafariTechnologyPreview",
                                                   @"com.apple.Safari.WebApp.*"]];

        // Disable Vietnamese input
        _disableVietnameseAppSet = [NSSet setWithArray:@[@"com.apple.apps.launcher",
                                                          @"com.apple.ScreenContinuity"]];
    }
}

#pragma mark - Bundle ID Matching

+ (BOOL)isBrowserApp:(NSString*)bundleId {
    return [self bundleIdMatchesAppSet:bundleId appSet:_browserAppSet];
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

+ (BOOL)isSafariApp:(NSString*)bundleId {
    return [self bundleIdMatchesAppSet:bundleId appSet:_safariAppSet];
}

+ (BOOL)shouldDisableVietnamese:(NSString*)bundleId {
    return [self bundleIdMatchesAppSet:bundleId appSet:_disableVietnameseAppSet];
}

+ (BOOL)needsNiceSpace:(NSString*)bundleId {
    return [self bundleIdMatchesAppSet:bundleId appSet:_niceSpaceAppSet];
}

+ (BOOL)isTerminalApp:(NSString*)bundleId {
    return [self bundleIdMatchesAppSet:bundleId appSet:_terminalAppSet];
}

+ (BOOL)isFastTerminalApp:(NSString*)bundleId {
    return [self bundleIdMatchesAppSet:bundleId appSet:_fastTerminalAppSet];
}

+ (BOOL)isMediumTerminalApp:(NSString*)bundleId {
    return [self bundleIdMatchesAppSet:bundleId appSet:_mediumTerminalAppSet];
}

+ (BOOL)isSlowTerminalApp:(NSString*)bundleId {
    return [self bundleIdMatchesAppSet:bundleId appSet:_slowTerminalAppSet];
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
