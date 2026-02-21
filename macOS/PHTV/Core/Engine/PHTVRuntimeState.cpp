//
//  PHTVRuntimeState.cpp
//  PHTV
//
//  Global runtime state shared by engine and Swift C++ interop wrappers.
//

#include "Engine.h"

// see document in Engine.h
// VOLATILE: Ensures thread-safe reads in event tap callback
// These are written on main thread, read on event tap thread
volatile int vInputType = 0;
int vFreeMark = 0;
volatile int vCodeTable = 0;
volatile int vCheckSpelling = 1;
volatile int vUseModernOrthography = 1;
volatile int vQuickTelex = 0;
volatile int vUseMacro = 1;
volatile int vAutoCapsMacro = 0;
volatile int vUpperCaseFirstChar = 0;
volatile int vUpperCaseExcludedForCurrentApp = 0;  // 1 = current app is in uppercase excluded list
volatile int vAllowConsonantZFWJ = 1;
volatile int vQuickStartConsonant = 0;
volatile int vQuickEndConsonant = 0;

// Restore to raw keys (customizable key)
volatile int vRestoreOnEscape = 1; //enable restore to raw keys feature (default: ON)

// Auto restore English word feature
volatile int vAutoRestoreEnglishWord = 1; //auto restore English words (default: ON)
