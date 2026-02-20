//
//  AppDelegate+InputSourceMonitoring.mm
//  PHTV
//
//  Input source and appearance change monitoring extracted from AppDelegate.
//

#import "AppDelegate+InputSourceMonitoring.h"
#import "AppDelegate+Private.h"
#import "AppDelegate+StatusBarMenu.h"
#import <Carbon/Carbon.h>

static NSString *const PHTVDefaultsKeyInputMethod = @"InputMethod";
static NSString *const PHTVNotificationLanguageChangedFromObjC = @"LanguageChangedFromObjC";

extern volatile int vLanguage;
extern volatile int vOtherLanguage;

#ifdef __cplusplus
extern "C" {
#endif
void RequestNewSession(void);
void InvalidateLayoutCache(void);
#ifdef __cplusplus
}
#endif

@implementation AppDelegate (InputSourceMonitoring)

- (void)observeAppearanceChanges {
    self.appearanceObserver = [[NSDistributedNotificationCenter defaultCenter] addObserverForName:@"AppleInterfaceThemeChangedNotification"
                                                                                            object:nil
                                                                                             queue:[NSOperationQueue mainQueue]
                                                                                        usingBlock:^(NSNotification *note) {
        [self fillData];
    }];
}

// Check if input source is Latin-based (can type Vietnamese)
// Returns NO for non-Latin scripts: Japanese, Chinese, Korean, Arabic, Hebrew, Thai, Hindi, Greek, Cyrillic, etc.
- (BOOL)isLatinInputSource:(TISInputSourceRef)inputSource {
    if (inputSource == NULL) {
        return YES;
    }

    // First, check input source ID for common non-Latin input methods.
    CFStringRef sourceID = (CFStringRef)TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID);
    if (sourceID != NULL) {
        NSString *sourceIDStr = (__bridge NSString *)sourceID;

        static NSArray *nonLatinPatterns = nil;
        static dispatch_once_t patternToken;
        dispatch_once(&patternToken, ^{
            nonLatinPatterns = @[
                // Japanese
                @"com.apple.inputmethod.Kotoeri", @"com.apple.inputmethod.Japanese",
                @"com.google.inputmethod.Japanese", @"jp.co.atok",
                // Chinese
                @"com.apple.inputmethod.SCIM", @"com.apple.inputmethod.TCIM",
                @"com.apple.inputmethod.ChineseHandwriting",
                @"com.sogou.inputmethod", @"com.baidu.inputmethod",
                @"com.tencent.inputmethod", @"com.iflytek.inputmethod",
                // Korean
                @"com.apple.inputmethod.Korean", @"com.apple.inputmethod.KoreanIM",
                // Arabic
                @"com.apple.keylayout.Arabic", @"com.apple.keylayout.ArabicPC",
                // Hebrew
                @"com.apple.keylayout.Hebrew", @"com.apple.keylayout.HebrewQWERTY",
                // Thai
                @"com.apple.keylayout.Thai", @"com.apple.keylayout.ThaiPattachote",
                // Hindi/Devanagari
                @"com.apple.keylayout.Devanagari", @"com.apple.keylayout.Hindi",
                @"com.apple.inputmethod.Hindi",
                // Greek
                @"com.apple.keylayout.Greek", @"com.apple.keylayout.GreekPolytonic",
                // Cyrillic (Russian, Ukrainian, etc.)
                @"com.apple.keylayout.Russian", @"com.apple.keylayout.RussianPC",
                @"com.apple.keylayout.Ukrainian", @"com.apple.keylayout.Bulgarian",
                @"com.apple.keylayout.Serbian", @"com.apple.keylayout.Macedonian",
                // Georgian
                @"com.apple.keylayout.Georgian",
                // Armenian
                @"com.apple.keylayout.Armenian",
                // Tamil, Telugu, Kannada, Malayalam, etc.
                @"com.apple.keylayout.Tamil", @"com.apple.keylayout.Telugu",
                @"com.apple.keylayout.Kannada", @"com.apple.keylayout.Malayalam",
                @"com.apple.keylayout.Gujarati", @"com.apple.keylayout.Punjabi",
                @"com.apple.keylayout.Bengali", @"com.apple.keylayout.Oriya",
                // Myanmar, Khmer, Lao
                @"com.apple.keylayout.Myanmar", @"com.apple.keylayout.Khmer",
                @"com.apple.keylayout.Lao",
                // Tibetan, Nepali, Sinhala
                @"com.apple.keylayout.Tibetan", @"com.apple.keylayout.Nepali",
                @"com.apple.keylayout.Sinhala",
                // Emoji/Symbol input (should not trigger Vietnamese)
                @"com.apple.CharacterPaletteIM", @"com.apple.PressAndHold",
                @"com.apple.inputmethod.EmojiFunctionRowItem"
            ];
        });

        for (NSString *pattern in nonLatinPatterns) {
            if ([sourceIDStr containsString:pattern]) {
                return NO;
            }
        }
    }

    // Fallback: Check language code.
    CFArrayRef languages = (CFArrayRef)TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceLanguages);
    if (languages == NULL || CFArrayGetCount(languages) == 0) {
        return YES;
    }

    CFStringRef langRef = (CFStringRef)CFArrayGetValueAtIndex(languages, 0);
    if (langRef == NULL) {
        return YES;
    }

    NSString *language = (__bridge NSString *)langRef;

    static NSSet *latinLanguages = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        latinLanguages = [[NSSet alloc] initWithArray:@[
            // Western European
            @"en", @"de", @"fr", @"es", @"it", @"pt", @"nl", @"ca",
            // Nordic
            @"da", @"sv", @"no", @"nb", @"nn", @"fi", @"is", @"fo",
            // Eastern European (Latin script)
            @"pl", @"cs", @"sk", @"hu", @"ro", @"hr", @"sl", @"sr-Latn",
            // Baltic
            @"et", @"lv", @"lt",
            // Other European
            @"sq", @"bs", @"mt",
            // Turkish & Turkic (Latin script)
            @"tr", @"az", @"uz", @"tk",
            // Southeast Asian (Latin script)
            @"id", @"ms", @"vi", @"tl", @"jv", @"su",
            // African (Latin script)
            @"sw", @"ha", @"yo", @"ig", @"zu", @"xh", @"af",
            // Pacific
            @"mi", @"sm", @"to", @"haw",
            // Celtic
            @"ga", @"gd", @"cy", @"br",
            // Other
            @"eo", @"la", @"mul"
        ]];
    });

    return [latinLanguages containsObject:language];
}

// Handle input source change notification
// Supports auto-switching for all non-Latin keyboards.
- (void)handleInputSourceChanged:(NSNotification *)notification {
    InvalidateLayoutCache();

    if (!vOtherLanguage) {
        return;
    }

    TISInputSourceRef currentInputSource = TISCopyCurrentKeyboardInputSource();
    if (currentInputSource == NULL) {
        return;
    }

    BOOL isLatin = [self isLatinInputSource:currentInputSource];

    CFStringRef localizedName = (CFStringRef)TISGetInputSourceProperty(currentInputSource, kTISPropertyLocalizedName);
    CFStringRef sourceID = (CFStringRef)TISGetInputSourceProperty(currentInputSource, kTISPropertyInputSourceID);
    NSString *displayName = localizedName ? (__bridge NSString *)localizedName :
        (sourceID ? (__bridge NSString *)sourceID : @"Unknown");

    CFRelease(currentInputSource);

    if (!isLatin && !self.isInNonLatinInputSource) {
        self.savedLanguageBeforeNonLatin = vLanguage;
        self.isInNonLatinInputSource = YES;

        if (vLanguage != 0) {
            NSLog(@"[InputSource] Detected non-Latin keyboard: %@ -> Auto-switching PHTV to English", displayName);

            vLanguage = 0;
            __sync_synchronize();
            [[NSUserDefaults standardUserDefaults] setInteger:vLanguage forKey:PHTVDefaultsKeyInputMethod];
            RequestNewSession();
            [self fillData];

            [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationLanguageChangedFromObjC
                                                                object:@(vLanguage)];
        }
    } else if (isLatin && self.isInNonLatinInputSource) {
        self.isInNonLatinInputSource = NO;

        if (self.savedLanguageBeforeNonLatin != 0 && vLanguage == 0) {
            NSLog(@"[InputSource] Detected Latin keyboard: %@ -> Restoring PHTV to Vietnamese", displayName);

            vLanguage = (int)self.savedLanguageBeforeNonLatin;
            __sync_synchronize();
            [[NSUserDefaults standardUserDefaults] setInteger:vLanguage forKey:PHTVDefaultsKeyInputMethod];
            RequestNewSession();
            [self fillData];

            [[NSNotificationCenter defaultCenter] postNotificationName:PHTVNotificationLanguageChangedFromObjC
                                                                object:@(vLanguage)];
        }
    }
}

- (void)startInputSourceMonitoring {
    self.isInNonLatinInputSource = NO;
    self.savedLanguageBeforeNonLatin = 0;

    self.inputSourceObserver = [[NSDistributedNotificationCenter defaultCenter]
        addObserverForName:(NSString *)kTISNotifySelectedKeyboardInputSourceChanged
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *note) {
        [self handleInputSourceChanged:note];
    }];

    NSLog(@"[InputSource] Started monitoring input source changes");
}

- (void)stopInputSourceMonitoring {
    if (self.appearanceObserver) {
        [[NSDistributedNotificationCenter defaultCenter] removeObserver:self.appearanceObserver];
        self.appearanceObserver = nil;
    }
    if (self.inputSourceObserver) {
        [[NSDistributedNotificationCenter defaultCenter] removeObserver:self.inputSourceObserver];
        self.inputSourceObserver = nil;
    }
    self.isInNonLatinInputSource = NO;
}

@end
