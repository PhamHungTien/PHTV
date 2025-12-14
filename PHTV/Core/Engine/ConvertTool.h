//
//  ConvertTool.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 9/4/19.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#ifndef ConvertTool_h
#define ConvertTool_h

#include "DataType.h"
#include <string>
using namespace std;

extern bool convertToolDontAlertWhenCompleted;
extern bool convertToolToAllCaps;
extern bool convertToolToAllNonCaps;
extern bool convertToolToCapsFirstLetter;
extern bool convertToolToCapsEachWord;
extern bool convertToolRemoveMark;
extern Uint8 convertToolFromCode;
extern Uint8 convertToolToCode;
extern int convertToolHotKey;

string convertUtil(const string& sourceString);

#endif /* ConvertTool_h */
