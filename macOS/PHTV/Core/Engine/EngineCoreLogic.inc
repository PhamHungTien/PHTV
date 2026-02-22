#include "EngineRuntimeAdapters.inc"
#include "EngineInputKeyMacros.inc"

#define VSI vowelStartIndex
#define VEI vowelEndIndex
#define VWSM vowelWillSetMark
#define hBPC HookState.backspaceCount
#define hNCC HookState.newCharCount
#define hCode HookState.code
#define hExt HookState.extCode
#define hData HookState.charData
#define GET getCharacterCode
#define hMacroKey HookState.macroKey
#define hMacroData HookState.macroData

#include "EngineCoreState.inc"
#include "EngineSessionBootstrap.inc"
#include "EngineSpellingCheck.inc"
#include "EngineGrammarCheck.inc"
#include "EngineSessionStateOps.inc"
#include "EngineCharacterTransform.inc"
#include "EngineMarkHandling.inc"

#include "EngineStandaloneAndCaps.inc"

#include "EngineMainKeyHandling.inc"

#include "EngineRestoreAndQuickConsonant.inc"
/*==========================================================================================================*/

#include "EngineEnglishMode.inc"

#include "EngineKeyHandleEvent.inc"

#include "EngineRestoreSession.inc"
