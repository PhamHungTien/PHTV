//
//  PHTVEngineCxxInterop.hpp
//  PHTV
//
//  Swift-facing C++ interop wrappers around engine helpers.
//

#ifndef PHTVEngineCxxInterop_hpp
#define PHTVEngineCxxInterop_hpp

#ifdef __cplusplus

#include <cstdint>
#include <ApplicationServices/ApplicationServices.h>

#include "../../Core/Engine/Engine.h"
#include "../../Core/PHTVConstants.h"

extern volatile int vLanguage __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vInputType __attribute__((swift_attr("nonisolated(unsafe)")));
extern int vFreeMark __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vCodeTable __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vSwitchKeyStatus __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vCheckSpelling __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vUseModernOrthography __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vQuickTelex __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vFixRecommendBrowser __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vUseMacro __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vUseMacroInEnglishMode __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vAutoCapsMacro __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vUseSmartSwitchKey __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vUpperCaseFirstChar __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vUpperCaseExcludedForCurrentApp __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vTempOffSpelling __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vAllowConsonantZFWJ __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vQuickStartConsonant __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vQuickEndConsonant __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vRememberCode __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vOtherLanguage __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vTempOffPHTV __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vRestoreOnEscape __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vCustomEscapeKey __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vPauseKeyEnabled __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vPauseKey __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vAutoRestoreEnglishWord __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vSendKeyStepByStep __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vPerformLayoutCompat __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vEnableEmojiHotkey __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vEmojiHotkeyModifiers __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vEmojiHotkeyKeyCode __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vSafeMode __attribute__((swift_attr("nonisolated(unsafe)")));
extern int vShowIconOnDock __attribute__((swift_attr("nonisolated(unsafe)")));

inline void phtvRuntimeBarrier() noexcept {
    __sync_synchronize();
}

// MARK: - Engine output state (pData) field accessors

extern vKeyHookState* pData __attribute__((swift_attr("nonisolated(unsafe)")));

#endif

#endif /* PHTVEngineCxxInterop_hpp */
