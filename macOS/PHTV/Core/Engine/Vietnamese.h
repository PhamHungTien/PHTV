//
//  Vietnamese.h
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#ifndef Vietnamese_h
#define Vietnamese_h
#include "DataType.h"
#include <vector>
#include <map>

extern Uint16 douKey[2][2];

extern std::map<Uint16, std::vector<std::vector<Uint16>>> _vowel;
extern std::map<Uint16, std::vector<std::vector<Uint32>>> _vowelCombine;
extern std::map<Uint16, std::vector<std::vector<Uint16>>> _vowelForMark;
extern std::vector<std::vector<Uint16>> _consonantD;
extern std::vector<std::vector<Uint16>> _consonantTable;
extern std::vector<std::vector<Uint16>> _endConsonantTable;
extern std::vector<Uint16> _standaloneWbad;
extern std::vector<std::vector<Uint16>> _doubleWAllowed;

extern std::map<Uint32, std::vector<Uint16>> _codeTable[];
extern Uint16 _unicodeCompoundMark[];

extern std::map<Uint32, std::vector<Uint16>> _quickTelex;
extern std::map<Uint16, std::vector<Uint16>> _quickStartConsonant;
extern std::map<Uint16, std::vector<Uint16>> _quickEndConsonant;
extern std::map<Uint32, Uint32> _characterMap;

extern Uint16 keyCodeToCharacter(const Uint32& keyCode);
#endif /* Vietnamese_h */
