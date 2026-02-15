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
@property (nonatomic, assign) CGFloat statusBarFontSize;
@property (nonatomic, strong) dispatch_queue_t updateQueue;
@property (nonatomic, assign) NSInteger lastInputMethod;
@property (nonatomic, assign) NSInteger lastCodeTable;
@property (nonatomic, assign) BOOL isUpdatingUI;
@property (nonatomic, assign) CFAbsoluteTime lastDefaultsApplyTime;

@property (nonatomic, strong, nullable) NSTimer *accessibilityMonitor;
@property (nonatomic, assign) BOOL wasAccessibilityEnabled;
@property (nonatomic, assign) NSUInteger accessibilityStableCount;
@property (nonatomic, assign) BOOL isAttemptingTCCRepair;
@property (nonatomic, assign) BOOL didAttemptTCCRepairOnce;
@property (nonatomic, strong, nullable) NSTimer *healthCheckTimer;
@property (nonatomic, assign) BOOL needsRelaunchAfterPermission;

- (void)onControlPanelSelected;
- (void)fillDataWithAnimation:(BOOL)animated;
@end

NS_ASSUME_NONNULL_END

#endif /* AppDelegate_Private_h */
