//
//  Macro.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#ifndef Macro_h
#define Macro_h

#include <vector>
#include "DataType.h"

/**
 * Call when you need to load macro data from disk
 */
extern "C" {
    void initMacroMap(const Byte* pData, const int& size);
}

/**
 * Use to find full text by macro
 */
bool findMacro(std::vector<Uint32>& key, std::vector<Uint32>& macroContentCode);

#endif /* Macro_h */
