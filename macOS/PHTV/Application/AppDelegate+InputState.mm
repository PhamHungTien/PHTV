//
//  AppDelegate+InputState.mm
//  PHTV
//
//  Input/language/code-table transitions extracted from AppDelegate.
//

#import "AppDelegate+InputState.h"
#import "AppDelegate+Private.h"
#import "AppDelegate+StatusBarMenu.h"

static NSString *const PHTVInputStateDefaultsKeyInputMethod = @"InputMethod";
static NSString *const PHTVInputStateDefaultsKeyInputType = @"InputType";
static NSString *const PHTVInputStateDefaultsKeyCodeTable = @"CodeTable";
static NSString *const PHTVInputStateNotificationLanguageChangedFromBackend = @"LanguageChangedFromBackend";

extern volatile int vLanguage;
extern volatile int vInputType;
extern volatile int vCodeTable;
extern volatile int vUseSmartSwitchKey;

#ifdef __cplusplus
extern "C" {
#endif
void OnTableCodeChange(void);
void OnInputMethodChanged(void);
void RequestNewSession(void);
#ifdef __cplusplus
}
#endif

@implementation AppDelegate (InputState)

- (void)handleLanguageChangedFromSwiftUI:(NSNotification *)notification {
    // Re-entry guard: prevent notification ping-pong
    if (self.isUpdatingLanguage) {
        #ifdef DEBUG
        NSLog(@"[SwiftUI] Ignoring language change (already updating)");
        #endif
        return;
    }

    NSNumber *language = notification.object;
    if (language) {
        int newLanguage = language.intValue;
        if (vLanguage != newLanguage) {
            #ifdef DEBUG
            NSLog(@"[SwiftUI] Language changing from %d to %d", vLanguage, newLanguage);
            #endif

            self.isUpdatingLanguage = YES;

            #ifdef DEBUG
            NSLog(@"========================================");
            NSLog(@"[SwiftUI] CHANGING LANGUAGE: %d -> %d", vLanguage, newLanguage);
            NSLog(@"========================================");
            #endif

            // CRITICAL: Synchronous state change to prevent race conditions
            // 1. Update global variable
            vLanguage = newLanguage;

            // If we are currently in an excluded app, update the "saved" language
            // so that when we switch back to a normal app, it restores the new selection.
            if (self.isInExcludedApp) {
                self.savedLanguageBeforeExclusion = newLanguage;
            }

            // 2. Memory barrier to ensure event tap thread sees new value
            __sync_synchronize();

            // 3. Save to UserDefaults (async - no synchronize, auto-saves periodically)
            [[NSUserDefaults standardUserDefaults] setInteger:vLanguage forKey:PHTVInputStateDefaultsKeyInputMethod];

            // 4. Reset engine state IMMEDIATELY (synchronous!)
            RequestNewSession();

            // 4. Update UI
            [self fillData];

            // 5. Notify engine (async is OK since state is reset) - only if SmartSwitchKey enabled
            if (vUseSmartSwitchKey) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    OnInputMethodChanged();
                });
            }

            NSLog(@"[SwiftUI] Language changed to: %d (engine reset complete)", vLanguage);

            self.isUpdatingLanguage = NO;
        }
    }
}

- (void)handleInputMethodChanged:(NSNotification *)notification {
    // Re-entry guard: prevent notification ping-pong
    if (self.isUpdatingInputType) {
        #ifdef DEBUG
        NSLog(@"[SwiftUI] Ignoring input method change (already updating)");
        #endif
        return;
    }

    NSNumber *inputMethod = notification.object;
    if (inputMethod) {
        int newIndex = inputMethod.intValue;
        if (vInputType != newIndex) {
            #ifdef DEBUG
            NSLog(@"[SwiftUI] Input method changing from %d to %d", vInputType, newIndex);
            #endif

            self.isUpdatingInputType = YES;

            #ifdef DEBUG
            NSLog(@"========================================");
            NSLog(@"[SwiftUI] CHANGING INPUT TYPE: %d -> %d", vInputType, newIndex);
            NSLog(@"========================================");
            #endif

            // CRITICAL: All changes must be synchronous to prevent race conditions
            // 1. Update global variable
            vInputType = newIndex;

            // 2. Memory barrier to ensure event tap thread sees new value
            __sync_synchronize();

            // 3. Save to UserDefaults (async - no synchronize, auto-saves periodically)
            [[NSUserDefaults standardUserDefaults] setInteger:newIndex forKey:PHTVInputStateDefaultsKeyInputType];

            // 4. Reset engine state IMMEDIATELY (synchronous, not async!)
            RequestNewSession();

            // 4. Update UI
            [self fillData];

            // 5. Notify engine (can be async since state is already reset) - only if SmartSwitchKey enabled
            if (vUseSmartSwitchKey) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    OnInputMethodChanged();
                });
            }

            NSLog(@"[SwiftUI] Input method changed to: %d (engine reset complete)", newIndex);

            self.isUpdatingInputType = NO;
        }
    }
}

- (void)handleCodeTableChanged:(NSNotification *)notification {
    NSNumber *codeTable = notification.object;
    if (codeTable) {
        int newIndex = codeTable.intValue;
        [self onCodeTableChanged:newIndex];
        #ifdef DEBUG
        NSLog(@"[SwiftUI] Code table changed to: %d", newIndex);
        #endif
    }
}

- (void)onImputMethodChanged:(BOOL)willNotify {
    // Re-entry guard: prevent notification ping-pong
    if (self.isUpdatingLanguage) {
        #ifdef DEBUG
        NSLog(@"[MenuBar] Ignoring language change (already updating)");
        #endif
        return;
    }

    NSInteger intInputMethod = [[NSUserDefaults standardUserDefaults] integerForKey:PHTVInputStateDefaultsKeyInputMethod];
    intInputMethod = (intInputMethod == 0) ? 1 : 0;

    if (vLanguage == (int)intInputMethod) {
        #ifdef DEBUG
        NSLog(@"[MenuBar] Language already at %d, skipping", vLanguage);
        #endif
        return;
    }

    #ifdef DEBUG
    NSLog(@"[MenuBar] Language changing from %d to %d", vLanguage, (int)intInputMethod);
    #endif

    self.isUpdatingLanguage = YES;

    #ifdef DEBUG
    NSLog(@"========================================");
    NSLog(@"[MenuBar] TOGGLING LANGUAGE: %d -> %d", vLanguage, (int)intInputMethod);
    NSLog(@"========================================");
    #endif

    // CRITICAL: Synchronous state change to prevent race conditions
    // 1. Update global variable
    vLanguage = (int)intInputMethod;

    // If we are currently in an excluded app, update the "saved" language
    // so that when we switch back to a normal app, it restores the new selection.
    if (self.isInExcludedApp) {
        self.savedLanguageBeforeExclusion = vLanguage;
    }

    // 2. Memory barrier to ensure event tap thread sees new value
    __sync_synchronize();

    // 3. Save to UserDefaults (async - no synchronize, auto-saves periodically)
    [[NSUserDefaults standardUserDefaults] setInteger:intInputMethod forKey:PHTVInputStateDefaultsKeyInputMethod];

    // 4. Reset engine state IMMEDIATELY (synchronous!)
    RequestNewSession();

    // 4. Update UI
    [self fillData];

    // 5. Notify SwiftUI about language change
    [[NSNotificationCenter defaultCenter] postNotificationName:PHTVInputStateNotificationLanguageChangedFromBackend object:@(vLanguage)];

    // 6. Notify engine (async is OK since state is already reset) - only if SmartSwitchKey enabled
    if (willNotify && vUseSmartSwitchKey) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            OnInputMethodChanged();
        });
    }

    #ifdef DEBUG
    NSLog(@"[MenuBar] Language changed to: %d (engine reset complete)", vLanguage);
    #endif

    self.isUpdatingLanguage = NO;
}

- (void)onInputMethodSelected {
    [self onImputMethodChanged:YES];
}

- (void)onInputTypeSelected:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem*) sender;
    [self onInputTypeSelectedIndex:(int)menuItem.tag];
}

- (void)onInputTypeSelectedIndex:(int)index {
    // Re-entry guard: prevent notification ping-pong
    if (self.isUpdatingInputType) {
        NSLog(@"[MenuBar] Ignoring input type change (already updating)");
        return;
    }

    if (vInputType == index) {
        NSLog(@"[MenuBar] Input type already at %d, skipping", index);
        return;
    }

    NSLog(@"[MenuBar] Input type changing from %d to %d", vInputType, index);

    self.isUpdatingInputType = YES;

    NSLog(@"========================================");
    NSLog(@"[MenuBar] CHANGING INPUT TYPE: %d -> %d", vInputType, index);
    NSLog(@"========================================");

    // CRITICAL: Synchronous state change to prevent race conditions
    // 1. Update global variable
    vInputType = index;

    // 2. Memory barrier to ensure event tap thread sees new value
    __sync_synchronize();

    // 3. Save to UserDefaults (async - no synchronize, auto-saves periodically)
    [[NSUserDefaults standardUserDefaults] setInteger:index forKey:PHTVInputStateDefaultsKeyInputType];

    // 4. Reset engine state IMMEDIATELY (synchronous!)
    RequestNewSession();

    // 4. Update UI
    [self fillData];

    // 5. Notify SwiftUI about input type change
    [[NSNotificationCenter defaultCenter] postNotificationName:PHTVInputStateNotificationLanguageChangedFromBackend object:@(vLanguage)];

    // 6. Notify engine (async is OK since state is already reset) - only if SmartSwitchKey enabled
    if (vUseSmartSwitchKey) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            OnInputMethodChanged();
        });
    }

    NSLog(@"[MenuBar] Input type changed to: %d (engine reset complete)", index);

    self.isUpdatingInputType = NO;
}

- (void)onCodeTableChanged:(int)index {
    // Re-entry guard: prevent notification ping-pong
    if (self.isUpdatingCodeTable) {
        NSLog(@"[MenuBar] Ignoring code table change (already updating)");
        return;
    }

    if (vCodeTable == index) {
        NSLog(@"[MenuBar] Code table already at %d, skipping", index);
        return;
    }

    NSLog(@"[MenuBar] Code table changing from %d to %d", vCodeTable, index);

    self.isUpdatingCodeTable = YES;

    NSLog(@"========================================");
    NSLog(@"[MenuBar] CHANGING CODE TABLE: %d -> %d", vCodeTable, index);
    NSLog(@"========================================");

    // CRITICAL: Synchronous state change to prevent race conditions
    // 1. Update global variable
    vCodeTable = index;

    // 2. Memory barrier to ensure event tap thread sees new value
    __sync_synchronize();

    // 3. Save to UserDefaults (async - no synchronize, auto-saves periodically)
    [[NSUserDefaults standardUserDefaults] setInteger:index forKey:PHTVInputStateDefaultsKeyCodeTable];

    // 4. Reset engine state IMMEDIATELY (synchronous!)
    RequestNewSession();

    // 4. Update UI
    [self fillData];

    // 5. Notify engine (async is OK since state is reset)
    // Always refresh macro conversion state when code table changes.
    // OnTableCodeChange() will internally skip per-app persistence when RememberCode is off.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        OnTableCodeChange();
    });

    NSLog(@"[MenuBar] Code table changed to: %d (engine reset complete)", index);

    self.isUpdatingCodeTable = NO;
}

- (void)onCodeSelected:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem*) sender;
    [self onCodeTableChanged:(int)menuItem.tag];
}

- (void)onInputMethodChangedFromSwiftUI:(NSNotification *)notification {
    NSNumber *newInputMethodValue = (NSNumber *)notification.object;
    if (newInputMethodValue) {
        int index = [newInputMethodValue intValue];
        NSLog(@"[SwiftUI] InputMethodChanged notification received: %d", index);
        [self onInputTypeSelectedIndex:index];
    }
}

- (void)onCodeTableChangedFromSwiftUI:(NSNotification *)notification {
    NSNumber *newCodeTableValue = (NSNumber *)notification.object;
    if (newCodeTableValue) {
        int index = [newCodeTableValue intValue];
        NSLog(@"[SwiftUI] CodeTableChanged notification received: %d", index);
        [self onCodeTableChanged:index];
    }
}

@end
