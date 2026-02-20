//
//  PHTVSettingsRuntime.h
//  PHTV
//
//  Shared settings helpers used by AppDelegate categories.
//

#ifndef PHTVSettingsRuntime_h
#define PHTVSettingsRuntime_h

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

static inline int PHTVReadIntWithFallback(NSUserDefaults *defaults, NSString *key, int fallbackValue) {
    if ([defaults objectForKey:key] == nil) {
        return fallbackValue;
    }
    return (int)[defaults integerForKey:key];
}

static inline void PHTVLoadEmojiHotkeySettings(NSUserDefaults *defaults,
                                                volatile int *enabled,
                                                volatile int *modifiers,
                                                volatile int *keyCode) {
    // Default: enabled + Command+E.
    id enabledObject = [defaults objectForKey:@"vEnableEmojiHotkey"];
    *enabled = (enabledObject == nil) ? 1 : ([defaults boolForKey:@"vEnableEmojiHotkey"] ? 1 : 0);

    id modifiersObject = [defaults objectForKey:@"vEmojiHotkeyModifiers"];
    if (modifiersObject == nil) {
        *modifiers = (int)NSEventModifierFlagCommand;
    } else {
        *modifiers = (int)[defaults integerForKey:@"vEmojiHotkeyModifiers"];
    }

    id keyCodeObject = [defaults objectForKey:@"vEmojiHotkeyKeyCode"];
    if (keyCodeObject == nil) {
        *keyCode = 14; // E key default.
    } else {
        *keyCode = (int)[defaults integerForKey:@"vEmojiHotkeyKeyCode"];
    }
}

static inline NSUInteger PHTVFoldSettingsToken(NSUInteger token, id _Nullable value) {
    const NSUInteger hashValue = value ? (NSUInteger)[value hash] : 0u;
    return (token * 16777619u) ^ hashValue;
}

static inline NSUInteger PHTVComputeSettingsToken(NSUserDefaults *defaults) {
    NSUInteger token = 2166136261u;

    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"Spelling"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"ModernOrthography"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"QuickTelex"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"UseMacro"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"UseMacroInEnglishMode"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"vAutoCapsMacro"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"SendKeyStepByStep"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"UseSmartSwitchKey"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"UpperCaseFirstChar"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"vAllowConsonantZFWJ"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"vQuickStartConsonant"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"vQuickEndConsonant"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"vRememberCode"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"vPerformLayoutCompat"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"vShowIconOnDock"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"vRestoreOnEscape"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"vCustomEscapeKey"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"vPauseKeyEnabled"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"vPauseKey"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"vAutoRestoreEnglishWord"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"vEnableEmojiHotkey"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"vEmojiHotkeyModifiers"]);
    token = PHTVFoldSettingsToken(token, [defaults objectForKey:@"vEmojiHotkeyKeyCode"]);

    return token;
}

NS_ASSUME_NONNULL_END

#endif /* PHTVSettingsRuntime_h */
