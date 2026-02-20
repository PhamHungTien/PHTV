//
//  AppDelegate+StatusBarMenu.mm
//  PHTV
//
//  Status bar menu construction and refresh logic extracted from AppDelegate.
//

#import "AppDelegate+StatusBarMenu.h"
#import "AppDelegate+InputState.h"
#import "AppDelegate+LoginItem.h"
#import "AppDelegate+Private.h"
#import "AppDelegate+SettingsActions.h"
#import "AppDelegate+UIActions.h"
#import <Carbon/Carbon.h>
#include "../Core/Engine/Engine.h"

static inline void PHTVAppendHotkeyComponent(NSMutableString *hotKey,
                                             BOOL *hasComponent,
                                             NSString *component) {
    if (*hasComponent) {
        [hotKey appendString:@" + "];
    }
    [hotKey appendString:component];
    *hasComponent = YES;
}

static inline NSString *PHTVHotkeyKeyDisplayLabel(unsigned short keyCode) {
    if (keyCode == kVK_Space || keyCode == KEY_SPACE) {
        return @"␣";
    }

    const Uint16 keyChar = keyCodeToCharacter(static_cast<Uint32>(keyCode) | CAPS_MASK);
    if (keyChar >= 33 && keyChar <= 126) {
        const unichar displayChar = (unichar)keyChar;
        return [NSString stringWithCharacters:&displayChar length:1];
    }

    return [NSString stringWithFormat:@"KEY_%hu", keyCode];
}

@interface AppDelegate (StatusBarMenuPrivate)
- (void)setInputTypeMenu:(NSMenuItem *)parent;
- (void)setCodeMenu:(NSMenuItem *)parent;
- (void)setOptionsMenu:(NSMenuItem *)parent;
@end

@implementation AppDelegate (StatusBarMenu)

- (void)createStatusBarMenu {
    // Must be on main thread
    if (![NSThread isMainThread]) {
        NSLog(@"[StatusBar] createStatusBarMenu called off main thread - dispatching to main");
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self createStatusBarMenu];
        });
        return;
    }

    NSLog(@"[StatusBar] Creating status bar menu...");

    // Get system status bar
    NSStatusBar *statusBar = [NSStatusBar systemStatusBar];

    // Create status item with VARIABLE length (important for text)
    self.statusItem = [statusBar statusItemWithLength:NSVariableStatusItemLength];

    if (!self.statusItem) {
        NSLog(@"[StatusBar] FATAL - Failed to create status item");
        return;
    }

    // Get button reference
    NSStatusBarButton *button = self.statusItem.button;
    if (!button) {
        NSLog(@"[StatusBar] FATAL - Status item has no button");
        return;
    }

    // Configure button with native appearance
    button.title = @"En";
    button.toolTip = @"PHTV - Bộ gõ tiếng Việt";

    // Modern button styling
    if (@available(macOS 11.0, *)) {
        button.bezelStyle = NSBezelStyleTexturedRounded;
    }

    // Create menu with native styling
    self.statusMenu = [[NSMenu alloc] init];
    self.statusMenu.autoenablesItems = NO;

    // Use system font for consistency
    if (@available(macOS 10.15, *)) {
        self.statusMenu.font = [NSFont menuFontOfSize:0];
    }

    // === LANGUAGE TOGGLE ===
    self.menuInputMethod = [[NSMenuItem alloc] initWithTitle:@"Bật Tiếng Việt"
                                                       action:@selector(onInputMethodSelected)
                                                keyEquivalent:@"v"];
    self.menuInputMethod.target = self;
    self.menuInputMethod.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    [self.statusMenu addItem:self.menuInputMethod];

    [self.statusMenu addItem:[NSMenuItem separatorItem]];

    // === INPUT TYPE HEADER ===
    NSMenuItem *menuInputType = [[NSMenuItem alloc] initWithTitle:@"Kiểu gõ"
                                                            action:nil
                                                     keyEquivalent:@""];
    menuInputType.enabled = YES;
    [self.statusMenu addItem:menuInputType];

    // === CODE TABLE HEADER ===
    NSMenuItem *menuCode = [[NSMenuItem alloc] initWithTitle:@"Bảng mã"
                                                       action:nil
                                                keyEquivalent:@""];
    menuCode.enabled = YES;
    [self.statusMenu addItem:menuCode];

    // === TYPING OPTIONS HEADER ===
    NSMenuItem *menuOptions = [[NSMenuItem alloc] initWithTitle:@"Tùy chọn gõ"
                                                          action:nil
                                                   keyEquivalent:@""];
    menuOptions.enabled = YES;
    [self.statusMenu addItem:menuOptions];

    [self.statusMenu addItem:[NSMenuItem separatorItem]];

    // === TOOLS ===
    self.mnuQuickConvert = [[NSMenuItem alloc] initWithTitle:@"Chuyển mã nhanh"
                                                      action:@selector(onQuickConvert)
                                               keyEquivalent:@""];
    self.mnuQuickConvert.target = self;
    [self.statusMenu addItem:self.mnuQuickConvert];

    [self.statusMenu addItem:[NSMenuItem separatorItem]];

    // === SETTINGS ===
    NSMenuItem *startupItem = [[NSMenuItem alloc] initWithTitle:@"Khởi động cùng hệ thống"
                                                          action:@selector(toggleStartupItem:)
                                                   keyEquivalent:@""];
    startupItem.target = self;
    [self.statusMenu addItem:startupItem];

    [self.statusMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *controlPanelItem = [[NSMenuItem alloc] initWithTitle:@"Bảng điều khiển..."
                                                               action:@selector(onControlPanelSelected)
                                                        keyEquivalent:@","];
    controlPanelItem.target = self;
    controlPanelItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [self.statusMenu addItem:controlPanelItem];

    NSMenuItem *macroItem = [[NSMenuItem alloc] initWithTitle:@"Gõ tắt..."
                                                        action:@selector(onMacroSelected)
                                                 keyEquivalent:@"m"];
    macroItem.target = self;
    macroItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [self.statusMenu addItem:macroItem];

    NSMenuItem *aboutItem = [[NSMenuItem alloc] initWithTitle:@"Giới thiệu"
                                                        action:@selector(onAboutSelected)
                                                 keyEquivalent:@""];
    aboutItem.target = self;
    [self.statusMenu addItem:aboutItem];

    [self.statusMenu addItem:[NSMenuItem separatorItem]];

    // === QUIT ===
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Thoát PHTV"
                                                       action:@selector(terminate:)
                                                keyEquivalent:@"q"];
    quitItem.target = NSApp;
    quitItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [self.statusMenu addItem:quitItem];

    // Setup submenus
    [self setInputTypeMenu:menuInputType];
    [self setCodeMenu:menuCode];
    [self setOptionsMenu:menuOptions];

    // ================================================
    // CRITICAL: Assign menu to status item
    // This is what makes the menu bar icon clickable!
    // ================================================
    self.statusItem.menu = self.statusMenu;

    // Log success
    NSLog(@"[StatusBar] Menu created successfully");
    NSLog(@"[StatusBar] Total items: %ld", (long)self.statusMenu.numberOfItems);
    NSLog(@"[StatusBar] Button title: '%@'", button.title);
    NSLog(@"[StatusBar] Menu assigned: %@", self.statusItem.menu ? @"YES" : @"NO");

    // Update UI with current settings (no animation on startup)
    [self fillDataWithAnimation:NO];
}

- (void)setQuickConvertString {
    NSMutableString *hotKey = [NSMutableString string];
    BOOL hasComponent = NO;
    const int quickConvertHotkey = gConvertToolOptions.hotKey;

    if (HAS_CONTROL(quickConvertHotkey)) {
        PHTVAppendHotkeyComponent(hotKey, &hasComponent, @"⌃");
    }
    if (HAS_OPTION(quickConvertHotkey)) {
        PHTVAppendHotkeyComponent(hotKey, &hasComponent, @"⌥");
    }
    if (HAS_COMMAND(quickConvertHotkey)) {
        PHTVAppendHotkeyComponent(hotKey, &hasComponent, @"⌘");
    }
    if (HAS_SHIFT(quickConvertHotkey)) {
        PHTVAppendHotkeyComponent(hotKey, &hasComponent, @"⇧");
    }

    if (HOTKEY_HAS_KEY(quickConvertHotkey)) {
        const unsigned short keyCode = (unsigned short)GET_SWITCH_KEY(quickConvertHotkey);
        PHTVAppendHotkeyComponent(hotKey, &hasComponent, PHTVHotkeyKeyDisplayLabel(keyCode));
    }

    [self.mnuQuickConvert setTitle:hasComponent
                                  ? [NSString stringWithFormat:@"Chuyển mã nhanh - [%@]", [hotKey uppercaseString]]
                                  : @"Chuyển mã nhanh"];
}

- (void)setInputTypeMenu:(NSMenuItem *)parent {
    // Create submenu if not exists
    if (!parent.submenu) {
        NSMenu *sub = [[NSMenu alloc] init];
        sub.autoenablesItems = NO;
        parent.submenu = sub;
    }

    NSMenu *sub = parent.submenu;
    [sub removeAllItems]; // Clear old items

    self.mnuTelex = [[NSMenuItem alloc] initWithTitle:@"Telex" action:@selector(onInputTypeSelected:) keyEquivalent:@""];
    self.mnuTelex.target = self;
    self.mnuTelex.tag = 0;
    [sub addItem:self.mnuTelex];

    self.mnuVNI = [[NSMenuItem alloc] initWithTitle:@"VNI" action:@selector(onInputTypeSelected:) keyEquivalent:@""];
    self.mnuVNI.target = self;
    self.mnuVNI.tag = 1;
    [sub addItem:self.mnuVNI];

    self.mnuSimpleTelex1 = [[NSMenuItem alloc] initWithTitle:@"Simple Telex 1" action:@selector(onInputTypeSelected:) keyEquivalent:@""];
    self.mnuSimpleTelex1.target = self;
    self.mnuSimpleTelex1.tag = 2;
    [sub addItem:self.mnuSimpleTelex1];

    self.mnuSimpleTelex2 = [[NSMenuItem alloc] initWithTitle:@"Simple Telex 2" action:@selector(onInputTypeSelected:) keyEquivalent:@""];
    self.mnuSimpleTelex2.target = self;
    self.mnuSimpleTelex2.tag = 3;
    [sub addItem:self.mnuSimpleTelex2];
}

- (void)setCodeMenu:(NSMenuItem *)parent {
    // Create submenu if not exists
    if (!parent.submenu) {
        NSMenu *sub = [[NSMenu alloc] init];
        sub.autoenablesItems = NO;
        parent.submenu = sub;
    }

    NSMenu *sub = parent.submenu;
    [sub removeAllItems]; // Clear old items

    self.mnuUnicode = [[NSMenuItem alloc] initWithTitle:@"Unicode dựng sẵn" action:@selector(onCodeSelected:) keyEquivalent:@""];
    self.mnuUnicode.target = self;
    self.mnuUnicode.tag = 0;
    [sub addItem:self.mnuUnicode];

    self.mnuTCVN = [[NSMenuItem alloc] initWithTitle:@"TCVN3 (ABC)" action:@selector(onCodeSelected:) keyEquivalent:@""];
    self.mnuTCVN.target = self;
    self.mnuTCVN.tag = 1;
    [sub addItem:self.mnuTCVN];

    self.mnuVNIWindows = [[NSMenuItem alloc] initWithTitle:@"VNI Windows" action:@selector(onCodeSelected:) keyEquivalent:@""];
    self.mnuVNIWindows.target = self;
    self.mnuVNIWindows.tag = 2;
    [sub addItem:self.mnuVNIWindows];

    self.mnuUnicodeComposite = [[NSMenuItem alloc] initWithTitle:@"Unicode tổ hợp" action:@selector(onCodeSelected:) keyEquivalent:@""];
    self.mnuUnicodeComposite.target = self;
    self.mnuUnicodeComposite.tag = 3;
    [sub addItem:self.mnuUnicodeComposite];

    self.mnuVietnameseLocaleCP1258 = [[NSMenuItem alloc] initWithTitle:@"Vietnamese Locale CP 1258" action:@selector(onCodeSelected:) keyEquivalent:@""];
    self.mnuVietnameseLocaleCP1258.target = self;
    self.mnuVietnameseLocaleCP1258.tag = 4;
    [sub addItem:self.mnuVietnameseLocaleCP1258];
}

- (void)setOptionsMenu:(NSMenuItem *)parent {
    if (!parent.submenu) {
        NSMenu *sub = [[NSMenu alloc] init];
        sub.autoenablesItems = NO;
        parent.submenu = sub;
    }

    NSMenu *sub = parent.submenu;
    [sub removeAllItems];

    self.mnuSpellCheck = [[NSMenuItem alloc] initWithTitle:@"Kiểm tra chính tả" action:@selector(toggleSpellCheck:) keyEquivalent:@""];
    self.mnuSpellCheck.target = self;
    [sub addItem:self.mnuSpellCheck];

    self.mnuModernOrthography = [[NSMenuItem alloc] initWithTitle:@"Chính tả mới (oà, uý)" action:@selector(toggleModernOrthography:) keyEquivalent:@""];
    self.mnuModernOrthography.target = self;
    [sub addItem:self.mnuModernOrthography];

    [sub addItem:[NSMenuItem separatorItem]];

    self.mnuQuickTelex = [[NSMenuItem alloc] initWithTitle:@"Gõ nhanh Telex" action:@selector(toggleQuickTelex:) keyEquivalent:@""];
    self.mnuQuickTelex.target = self;
    [sub addItem:self.mnuQuickTelex];

    self.mnuAllowConsonantZFWJ = [[NSMenuItem alloc] initWithTitle:@"Phụ âm Z, F, W, J" action:@selector(toggleAllowConsonantZFWJ:) keyEquivalent:@""];
    self.mnuAllowConsonantZFWJ.target = self;
    [sub addItem:self.mnuAllowConsonantZFWJ];

    [sub addItem:[NSMenuItem separatorItem]];

    self.mnuUpperCaseFirstChar = [[NSMenuItem alloc] initWithTitle:@"Viết hoa đầu câu" action:@selector(toggleUpperCaseFirstChar:) keyEquivalent:@""];
    self.mnuUpperCaseFirstChar.target = self;
    [sub addItem:self.mnuUpperCaseFirstChar];

    self.mnuAutoRestoreEnglishWord = [[NSMenuItem alloc] initWithTitle:@"Tự động khôi phục tiếng Anh" action:@selector(toggleAutoRestoreEnglishWord:) keyEquivalent:@""];
    self.mnuAutoRestoreEnglishWord.target = self;
    [sub addItem:self.mnuAutoRestoreEnglishWord];
}

- (void)fillData {
    [self fillDataWithAnimation:YES];
}

- (void)fillDataWithAnimation:(BOOL)animated {
    (void)animated;

    if (!self.statusItem || !self.statusItem.button) {
        return;  // Silent fail - no logging on hot path
    }

    // PERFORMANCE: Use global variables directly (already in cache)
    // DO NOT re-read from UserDefaults - eliminates disk I/O
    NSInteger intInputMethod = vLanguage;
    NSInteger intInputType = vInputType;
    NSInteger intCode = vCodeTable;

    // PERFORMANCE: Skip animation for faster response
    // Users want instant feedback, not 150ms animation delay
    static NSFont *statusFont = nil;
    static CGFloat lastFontSize = 0.0;
    CGFloat desiredSize = (self.statusBarFontSize > 0.0) ? self.statusBarFontSize : 12.0;
    if (!statusFont || lastFontSize != desiredSize) {
        lastFontSize = desiredSize;
        statusFont = [NSFont monospacedSystemFontOfSize:desiredSize weight:NSFontWeightSemibold];
    }

    NSString *statusText = (intInputMethod == 1) ? @"Vi" : @"En";

    // PERFORMANCE: Use simple color, skip grayIcon check (not critical for UX)
    NSColor *textColor = (intInputMethod == 1) ? [NSColor systemBlueColor] : [NSColor secondaryLabelColor];

    NSDictionary *attributes = @{
        NSFontAttributeName: statusFont,
        NSForegroundColorAttributeName: textColor
    };
    NSAttributedString *newTitle = [[NSAttributedString alloc] initWithString:statusText attributes:attributes];

    // PERFORMANCE: No animation - instant update
    self.statusItem.button.attributedTitle = newTitle;

    // Update menu input method state
    [self.menuInputMethod setState:(intInputMethod == 1) ? NSControlStateValueOn : NSControlStateValueOff];

    // PERFORMANCE: Update only the active items, skip title updates
    [self.mnuTelex setState:(intInputType == 0) ? NSControlStateValueOn : NSControlStateValueOff];
    [self.mnuVNI setState:(intInputType == 1) ? NSControlStateValueOn : NSControlStateValueOff];
    [self.mnuSimpleTelex1 setState:(intInputType == 2) ? NSControlStateValueOn : NSControlStateValueOff];
    [self.mnuSimpleTelex2 setState:(intInputType == 3) ? NSControlStateValueOn : NSControlStateValueOff];

    // PERFORMANCE: Direct updates, skip array iteration
    [self.mnuUnicode setState:(intCode == 0) ? NSControlStateValueOn : NSControlStateValueOff];
    [self.mnuTCVN setState:(intCode == 1) ? NSControlStateValueOn : NSControlStateValueOff];
    [self.mnuVNIWindows setState:(intCode == 2) ? NSControlStateValueOn : NSControlStateValueOff];
    [self.mnuUnicodeComposite setState:(intCode == 3) ? NSControlStateValueOn : NSControlStateValueOff];
    [self.mnuVietnameseLocaleCP1258 setState:(intCode == 4) ? NSControlStateValueOn : NSControlStateValueOff];

    // Update typing features state
    [self.mnuSpellCheck setState:vCheckSpelling ? NSControlStateValueOn : NSControlStateValueOff];
    [self.mnuModernOrthography setState:vUseModernOrthography ? NSControlStateValueOn : NSControlStateValueOff];
    [self.mnuQuickTelex setState:vQuickTelex ? NSControlStateValueOn : NSControlStateValueOff];
    [self.mnuAllowConsonantZFWJ setState:vAllowConsonantZFWJ ? NSControlStateValueOn : NSControlStateValueOff];
    [self.mnuUpperCaseFirstChar setState:vUpperCaseFirstChar ? NSControlStateValueOn : NSControlStateValueOff];
    [self.mnuAutoRestoreEnglishWord setState:vAutoRestoreEnglishWord ? NSControlStateValueOn : NSControlStateValueOff];
}

@end
