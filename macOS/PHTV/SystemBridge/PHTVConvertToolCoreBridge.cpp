//
//  PHTVConvertToolCoreBridge.cpp
//  PHTV
//
//  C bridge for ConvertTool C++ options.
//

#include "../Core/Engine/ConvertTool.h"
#include "../Core/PHTVConstants.h"

extern "C" {

void PHTVSetConvertToolOptions(bool dontAlertWhenCompleted,
                               bool toAllCaps,
                               bool toAllNonCaps,
                               bool toCapsFirstLetter,
                               bool toCapsEachWord,
                               bool removeMark,
                               int fromCode,
                               int toCode,
                               int hotKey) {
    const int clampedFromCode = phtv_clamp_code_table(fromCode);
    const int clampedToCode = phtv_clamp_code_table(toCode);

    gConvertToolOptions.dontAlertWhenCompleted = dontAlertWhenCompleted;
    gConvertToolOptions.toAllCaps = toAllCaps;
    gConvertToolOptions.toAllNonCaps = toAllNonCaps;
    gConvertToolOptions.toCapsFirstLetter = toCapsFirstLetter;
    gConvertToolOptions.toCapsEachWord = toCapsEachWord;
    gConvertToolOptions.removeMark = removeMark;
    gConvertToolOptions.fromCode = static_cast<Uint8>(clampedFromCode);
    gConvertToolOptions.toCode = static_cast<Uint8>(clampedToCode);
    gConvertToolOptions.hotKey = hotKey;
}

int PHTVDefaultConvertToolHotKey(void) {
    return defaultConvertToolOptions().hotKey;
}

void PHTVResetConvertToolOptions(void) {
    resetConvertToolOptions();
}

void PHTVNormalizeConvertToolOptions(void) {
    normalizeConvertToolOptions();
}

} // extern "C"
