//
//  AppDelegate+Private.h
//  PHTV
//
//  Internal declarations shared by AppDelegate categories.
//

#ifndef AppDelegate_Private_h
#define AppDelegate_Private_h

#import "AppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate ()
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMenu *statusMenu;
@property (nonatomic, strong, nullable) NSMenuItem *menuInputMethod;
@property (nonatomic, strong, nullable) NSMenuItem *mnuTelex;
@property (nonatomic, strong, nullable) NSMenuItem *mnuVNI;
@property (nonatomic, strong, nullable) NSMenuItem *mnuSimpleTelex1;
@property (nonatomic, strong, nullable) NSMenuItem *mnuSimpleTelex2;
@property (nonatomic, strong, nullable) NSMenuItem *mnuUnicode;
@property (nonatomic, strong, nullable) NSMenuItem *mnuTCVN;
@property (nonatomic, strong, nullable) NSMenuItem *mnuVNIWindows;
@property (nonatomic, strong, nullable) NSMenuItem *mnuUnicodeComposite;
@property (nonatomic, strong, nullable) NSMenuItem *mnuVietnameseLocaleCP1258;
@property (nonatomic, strong, nullable) NSMenuItem *mnuQuickConvert;
@property (nonatomic, strong, nullable) NSMenuItem *mnuSpellCheck;
@property (nonatomic, strong, nullable) NSMenuItem *mnuAllowConsonantZFWJ;
@property (nonatomic, strong, nullable) NSMenuItem *mnuModernOrthography;
@property (nonatomic, strong, nullable) NSMenuItem *mnuQuickTelex;
@property (nonatomic, strong, nullable) NSMenuItem *mnuUpperCaseFirstChar;
@property (nonatomic, strong, nullable) NSMenuItem *mnuAutoRestoreEnglishWord;
@property (nonatomic, assign) CGFloat statusBarFontSize;
@property (nonatomic, strong) dispatch_queue_t updateQueue;
@property (nonatomic, assign) NSInteger lastInputMethod;
@property (nonatomic, assign) NSInteger lastCodeTable;
@property (nonatomic, assign) BOOL isUpdatingUI;
@property (nonatomic, assign) CFAbsoluteTime lastDefaultsApplyTime;
@property (nonatomic, assign) NSUInteger lastSettingsChangeToken;
@property (nonatomic, assign) BOOL hasLastDockVisibilityRequest;
@property (nonatomic, assign) BOOL lastDockVisibilityRequest;
@property (nonatomic, assign) BOOL lastDockForceFrontRequest;
@property (nonatomic, assign) CFAbsoluteTime lastDockVisibilityRequestTime;
@property (nonatomic, assign) BOOL settingsWindowOpen;

@property (nonatomic, strong, nullable) NSTimer *accessibilityMonitor;
@property (nonatomic, assign) BOOL wasAccessibilityEnabled;
@property (nonatomic, assign) NSUInteger accessibilityStableCount;
@property (nonatomic, assign) BOOL isAttemptingTCCRepair;
@property (nonatomic, assign) BOOL didAttemptTCCRepairOnce;
@property (nonatomic, strong, nullable) NSTimer *healthCheckTimer;
@property (nonatomic, assign) BOOL needsRelaunchAfterPermission;

@property (nonatomic, assign) NSInteger savedLanguageBeforeExclusion;
@property (nonatomic, copy, nullable) NSString *previousBundleIdentifier;
@property (nonatomic, assign) BOOL isInExcludedApp;
@property (nonatomic, assign) BOOL savedSendKeyStepByStepBeforeApp;
@property (nonatomic, assign) BOOL isInSendKeyStepByStepApp;
@property (nonatomic, assign) BOOL isUpdatingLanguage;
@property (nonatomic, assign) BOOL isUpdatingInputType;
@property (nonatomic, assign) BOOL isUpdatingCodeTable;
@property (nonatomic, strong, nullable) id appearanceObserver;
@property (nonatomic, strong, nullable) id inputSourceObserver;
@property (nonatomic, assign) NSInteger savedLanguageBeforeNonLatin;
@property (nonatomic, assign) BOOL isInNonLatinInputSource;

- (void)fillDataWithAnimation:(BOOL)animated;
- (void)handleHotkeyChanged:(NSNotification * _Nullable)notification;
- (void)handleEmojiHotkeySettingsChanged:(NSNotification * _Nullable)notification;
- (void)handleTCCDatabaseChanged:(NSNotification * _Nullable)notification;
- (void)handleMenuBarIconSizeChanged:(NSNotification * _Nullable)notification;
- (void)handleSettingsChanged:(NSNotification * _Nullable)notification;
- (void)handleMacrosUpdated:(NSNotification * _Nullable)notification;
- (void)handleUserDefaultsDidChange:(NSNotification * _Nullable)notification;
@end

NS_ASSUME_NONNULL_END

#endif /* AppDelegate_Private_h */
