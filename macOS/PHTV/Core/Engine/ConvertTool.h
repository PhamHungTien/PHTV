//
//  ConvertTool.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#ifndef ConvertTool_h
#define ConvertTool_h

#include "DataType.h"
#include <string>

struct ConvertToolOptions {
    bool dontAlertWhenCompleted;
    bool toAllCaps;
    bool toAllNonCaps;
    bool toCapsFirstLetter;
    bool toCapsEachWord;
    bool removeMark;
    Uint8 fromCode;
    Uint8 toCode;
    int hotKey;
};

extern ConvertToolOptions gConvertToolOptions;

void resetConvertToolOptions();
std::string convertUtil(const std::string& sourceString);
void normalizeConvertToolOptions();

#endif /* ConvertTool_h */
