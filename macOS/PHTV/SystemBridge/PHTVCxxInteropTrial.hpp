//
//  PHTVCxxInteropTrial.hpp
//  PHTV
//
//  Minimal C++ APIs imported directly by Swift via C++ interoperability.
//

#ifndef PHTVCxxInteropTrial_hpp
#define PHTVCxxInteropTrial_hpp

#ifdef __cplusplus

inline constexpr int phtvCxxInteropProbeValue() noexcept {
    return 20260221;
}

inline int phtvCxxInteropAdd(int lhs, int rhs) noexcept {
    return lhs + rhs;
}

#endif

#endif /* PHTVCxxInteropTrial_hpp */
