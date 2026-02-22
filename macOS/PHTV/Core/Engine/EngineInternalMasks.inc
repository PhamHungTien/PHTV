#ifndef ENGINE_INTERNAL_MASKS_INC
#define ENGINE_INTERNAL_MASKS_INC

//internal engine data
//internal engine data
#define CAPS_MASK                               0x10000
#define TONE_MASK                               0x20000
#define TONEW_MASK                              0x40000

/*
 * MARK MASK
 * 1: Dấu Sắc - á
 * 2: Dấu Huyền - à
 * 3: Dấu Hỏi - ả
 * 4: Dấu Ngã - ã
 * 5: dấu Nặng - ạ
 */
#define MARK1_MASK                              0x80000
#define MARK2_MASK                              0x100000
#define MARK3_MASK                              0x200000
#define MARK4_MASK                              0x400000
#define MARK5_MASK                              0x800000

//for checking has mark or not
#define MARK_MASK                               0xF80000

//mark and get first 16 bytes character
#define CHAR_MASK                               0xFFFF

//Check whether the data is create by standalone key or not (W)
#define STANDALONE_MASK                         0x1000000

//Chec whether the data is keyboard code or character code
#define CHAR_CODE_MASK                          0x2000000

#define PURE_CHARACTER_MASK                     0x80000000

//for special feature
#define END_CONSONANT_MASK                      0x4000
#define CONSONANT_ALLOW_MASK                    0x8000


//Utilities macro
#define IS_CONSONANT(keyCode) !(keyCode == KEY_A || keyCode == KEY_E || keyCode == KEY_U || keyCode == KEY_Y || keyCode == KEY_I || keyCode == KEY_O)
//#define IS_MARK_KEY(keyCode) (keyCode == KEY_S || keyCode == KEY_F || keyCode == KEY_R || keyCode == KEY_J || keyCode == KEY_X)
#define CHR(index) (Uint16)TypingWord[index]

//is VNI or Unicode compound...
#define IS_DOUBLE_CODE(code) (code == 2 || code == 3)
#define IS_VNI_CODE(code) (code == 2)
#define IS_QUICK_TELEX_KEY(code) (_index > 0 && (code == KEY_C || code == KEY_G || code == KEY_K || code == KEY_N || code == KEY_Q || code == KEY_P || code == KEY_T) && \
                                    (Uint16)TypingWord[_index-1] == code)

#define IS_NUMBER_KEY(code) (code == KEY_1 || code == KEY_2 || code == KEY_3 || code == KEY_4 || code == KEY_5 || code == KEY_6 || code == KEY_7 || code == KEY_8 || code == KEY_9 || code == KEY_0)

#endif /* ENGINE_INTERNAL_MASKS_INC */
