//
//  AppDelegate+PermissionFlow.mm
//  PHTV
//
//  Accessibility permission flow extracted from AppDelegate.
//

#import "AppDelegate+PermissionFlow.h"
#import "../SystemBridge/PHTVAccessibilityManager.h"
#import "../SystemBridge/PHTVManager.h"

static NSString *const PHTVDefaultsKeyLastRunVersion = @"LastRunVersion";

@implementation AppDelegate (PermissionFlow)

- (void)askPermission {
    NSAlert *alert = [[NSAlert alloc] init];

    NSString *currentVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
    NSString *lastVersion = [[NSUserDefaults standardUserDefaults] stringForKey:PHTVDefaultsKeyLastRunVersion];

    if (lastVersion && ![lastVersion isEqualToString:currentVersion]) {
        [alert setMessageText:@"PHTV đã được cập nhật!"];
        [alert setInformativeText:[NSString stringWithFormat:@"Do macOS yêu cầu bảo mật, bạn cần cấp lại quyền trợ năng sau khi cập nhật ứng dụng lên phiên bản %@.\n\nỨng dụng sẽ tự động khởi động lại sau khi bạn cấp quyền.", currentVersion]];
    } else {
        [alert setMessageText:@"PHTV cần bạn cấp quyền để có thể hoạt động!"];
        [alert setInformativeText:@"Ứng dụng sẽ tự động khởi động lại sau khi bạn cấp quyền."];
    }

    [alert addButtonWithTitle:@"Không"];
    [alert addButtonWithTitle:@"Cấp quyền"];

    [alert.window makeKeyAndOrderFront:nil];
    [alert.window setLevel:NSStatusWindowLevel];

    NSModalResponse res = [alert runModal];

    if (res == 1001) {
        [PHTVAccessibilityManager openAccessibilityPreferences];

        [PHTVManager invalidatePermissionCache];
        NSLog(@"[Accessibility] User opening System Settings - cache invalidated");

        [[NSUserDefaults standardUserDefaults] setObject:currentVersion forKey:PHTVDefaultsKeyLastRunVersion];
    } else {
        [NSApp terminate:0];
    }
}

@end
