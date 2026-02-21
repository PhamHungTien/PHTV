//
//  PHTVEngineCxxInterop.hpp
//  PHTV
//
//  Swift-facing C++ interop wrappers around engine helpers.
//

#ifndef PHTVEngineCxxInterop_hpp
#define PHTVEngineCxxInterop_hpp

#ifdef __cplusplus

#include "../../Core/Engine/Engine.h"
#include "../../Core/PHTVConstants.h"

extern volatile int vInputType __attribute__((swift_attr("nonisolated(unsafe)")));
extern int vFreeMark __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vCodeTable __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vCheckSpelling __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vUseModernOrthography __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vQuickTelex __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vAllowConsonantZFWJ __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vQuickStartConsonant __attribute__((swift_attr("nonisolated(unsafe)")));
extern volatile int vQuickEndConsonant __attribute__((swift_attr("nonisolated(unsafe)")));

#endif

#endif /* PHTVEngineCxxInterop_hpp */
