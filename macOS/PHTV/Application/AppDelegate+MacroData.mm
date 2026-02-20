//
//  AppDelegate+MacroData.mm
//  PHTV
//
//  Macro synchronization and dictionary bootstrap extracted from AppDelegate.
//

#import "AppDelegate+MacroData.h"
#import "PHTVLiveDebug.h"
#include "../Core/Engine/Engine.h"

static NSString *const PHTVDefaultsKeyMacroList = @"macroList";
static NSString *const PHTVDefaultsKeyMacroListCorruptedBackup = @"macroList.corruptedBackup";
static NSString *const PHTVDefaultsKeyMacroData = @"macroData";
static NSString *const PHTVDefaultsKeyCustomDictionary = @"customDictionary";
static NSString *const PHTVDefaultsKeySpelling = @"Spelling";

static inline int PHTVReadIntWithFallback(NSUserDefaults *defaults, NSString *key, int fallbackValue) {
    if ([defaults objectForKey:key] == nil) {
        return fallbackValue;
    }
    return (int)[defaults integerForKey:key];
}

#ifdef __cplusplus
extern "C" {
#endif
void initMacroMap(const unsigned char*, const int&);
void RequestNewSession(void);
#ifdef __cplusplus
}
#endif

@interface AppDelegate (MacroDataPrivate)
- (void)syncMacrosFromUserDefaultsResetSession:(BOOL)resetSession;
@end

@implementation AppDelegate (MacroData)

- (void)syncMacrosFromUserDefaultsResetSession:(BOOL)resetSession {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *macroListData = [defaults dataForKey:PHTVDefaultsKeyMacroList];

    if (macroListData && macroListData.length > 0) {
        NSError *error = nil;
        NSArray *macros = [NSJSONSerialization JSONObjectWithData:macroListData
                                                         options:NSJSONReadingMutableContainers
                                                           error:&error];
        if (error || ![macros isKindOfClass:[NSArray class]]) {
            NSLog(@"[AppDelegate] ERROR: Failed to parse macroList: %@", error);
            [defaults setObject:macroListData forKey:PHTVDefaultsKeyMacroListCorruptedBackup];
            [defaults removeObjectForKey:PHTVDefaultsKeyMacroList];
            [defaults removeObjectForKey:PHTVDefaultsKeyMacroData];

            uint16_t macroCount = 0;
            NSMutableData *emptyData = [NSMutableData data];
            [emptyData appendBytes:&macroCount length:2];
            initMacroMap((const unsigned char *)[emptyData bytes], (int)[emptyData length]);
            PHTV_LIVE_LOG(@"macroList parse failed, backed up to %@ and reset", PHTVDefaultsKeyMacroListCorruptedBackup);

            if (resetSession) {
                RequestNewSession();
            }
            return;
        }

        NSMutableData *binaryData = [NSMutableData data];
        uint16_t macroCount = (uint16_t)[macros count];
        [binaryData appendBytes:&macroCount length:2];

        // Snippet type mapping from Swift enum to C++ enum
        NSDictionary *snippetTypeMap = @{
            @"static": @0,
            @"date": @1,
            @"time": @2,
            @"datetime": @3,
            @"clipboard": @4,
            @"random": @5,
            @"counter": @6
        };

        for (NSDictionary *macro in macros) {
            if (![macro isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            NSString *shortcut = macro[@"shortcut"] ?: @"";
            NSString *expansion = macro[@"expansion"] ?: @"";
            NSString *snippetTypeStr = macro[@"snippetType"] ?: @"static";

            uint8_t shortcutLen = (uint8_t)[shortcut lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
            [binaryData appendBytes:&shortcutLen length:1];
            [binaryData appendData:[shortcut dataUsingEncoding:NSUTF8StringEncoding]];

            uint16_t expansionLen = (uint16_t)[expansion lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
            [binaryData appendBytes:&expansionLen length:2];
            [binaryData appendData:[expansion dataUsingEncoding:NSUTF8StringEncoding]];

            // Append snippet type (1 byte)
            uint8_t snippetType = [snippetTypeMap[snippetTypeStr] unsignedCharValue];
            [binaryData appendBytes:&snippetType length:1];
        }

        [defaults setObject:binaryData forKey:PHTVDefaultsKeyMacroData];

        initMacroMap((const unsigned char *)[binaryData bytes], (int)[binaryData length]);
        PHTV_LIVE_LOG(@"macros synced: count=%u", macroCount);
    } else {
        [defaults removeObjectForKey:PHTVDefaultsKeyMacroData];

        uint16_t macroCount = 0;
        NSMutableData *emptyData = [NSMutableData data];
        [emptyData appendBytes:&macroCount length:2];
        initMacroMap((const unsigned char *)[emptyData bytes], (int)[emptyData length]);
        PHTV_LIVE_LOG(@"macros cleared");
    }

    if (resetSession) {
        RequestNewSession();
    }
}

- (void)handleMacrosUpdated:(NSNotification *)notification {
    PHTV_LIVE_LOG(@"received MacrosUpdated");
    [self syncMacrosFromUserDefaultsResetSession:YES];
}

- (void)loadExistingMacros {
    // On app startup, sync macroData from macroList (source of truth).
    [self syncMacrosFromUserDefaultsResetSession:NO];
}

- (void)initEnglishWordDictionary {
    // Load English dictionary (binary only - PHT3 format)
    NSString *enBundlePath = [[NSBundle mainBundle] pathForResource:@"en_dict" ofType:@"bin"];
    if (enBundlePath) {
        std::string path = [enBundlePath UTF8String];
        if (initEnglishDictionary(path)) {
            NSLog(@"[EnglishWordDetector] English dictionary loaded: %zu words", getEnglishDictionarySize());
        } else {
            NSLog(@"[EnglishWordDetector] Failed to load English dictionary");
        }
    } else {
        NSLog(@"[EnglishWordDetector] en_dict.bin not found in bundle");
    }

    // Load Vietnamese dictionary (binary only - PHT3 format)
    NSString *viBundlePath = [[NSBundle mainBundle] pathForResource:@"vi_dict" ofType:@"bin"];
    if (viBundlePath) {
        std::string path = [viBundlePath UTF8String];
        if (initVietnameseDictionary(path)) {
            NSLog(@"[EnglishWordDetector] Vietnamese dictionary loaded: %zu words", getVietnameseDictionarySize());
        } else {
            NSLog(@"[EnglishWordDetector] Failed to load Vietnamese dictionary");
        }
    } else {
        NSLog(@"[EnglishWordDetector] vi_dict.bin not found in bundle");
    }

    // Load custom dictionary from UserDefaults
    [self syncCustomDictionaryFromUserDefaults];

    // CRITICAL FIX: Load spell check setting NOW (before event tap starts)
    // Problem: First keystroke may happen before vCheckSpelling is loaded from UserDefaults
    // This causes English word detection to skip spell check on first attempt
    // Solution: Ensure vCheckSpelling is set IMMEDIATELY after dictionary loads
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    vCheckSpelling = PHTVReadIntWithFallback(defaults, PHTVDefaultsKeySpelling, 1);
    NSLog(@"[EnglishWordDetector] Spell check enabled: %d", vCheckSpelling);
}

- (void)syncCustomDictionaryFromUserDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *customDictData = [defaults dataForKey:PHTVDefaultsKeyCustomDictionary];

    if (customDictData && customDictData.length > 0) {
        NSError *error = nil;
        NSArray *words = [NSJSONSerialization JSONObjectWithData:customDictData options:0 error:&error];

        if (error || !words) {
            NSLog(@"[CustomDictionary] Failed to parse JSON: %@", error.localizedDescription);
            return;
        }

        // Re-serialize to JSON string for C++ parser
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:words options:0 error:&error];
        if (jsonData) {
            initCustomDictionary((const char*)jsonData.bytes, (int)jsonData.length);
            NSLog(@"[CustomDictionary] Loaded %zu English, %zu Vietnamese custom words",
                  getCustomEnglishWordCount(), getCustomVietnameseWordCount());
        }
    } else {
        // Clear custom dictionary if no data
        clearCustomDictionary();
        NSLog(@"[CustomDictionary] No custom words found");
    }
}

- (void)handleCustomDictionaryUpdated:(NSNotification *)notification {
    PHTV_LIVE_LOG(@"received CustomDictionaryUpdated");
    [self syncCustomDictionaryFromUserDefaults];
}

@end
