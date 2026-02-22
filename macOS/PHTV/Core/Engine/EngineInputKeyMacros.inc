static Uint16 ProcessingChar[][11] = {
    {KEY_S, KEY_F, KEY_R, KEY_X, KEY_J, KEY_A, KEY_O, KEY_E, KEY_W, KEY_D, KEY_Z}, //Telex
    {KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0}, //VNI
    {KEY_S, KEY_F, KEY_R, KEY_X, KEY_J, KEY_A, KEY_O, KEY_E, KEY_W, KEY_D, KEY_Z}, //Simple Telex 1
    {KEY_S, KEY_F, KEY_R, KEY_X, KEY_J, KEY_A, KEY_O, KEY_E, KEY_W, KEY_D, KEY_Z} //Simple Telex 2
};

#define IS_KEY_Z(key) (ProcessingChar[runtimeInputTypeSnapshot][10] == key)
#define IS_KEY_D(key) (ProcessingChar[runtimeInputTypeSnapshot][9] == key)
#define IS_KEY_W(key) ((runtimeInputTypeSnapshot != vVNI) ? ProcessingChar[runtimeInputTypeSnapshot][8] == key : \
                                    (runtimeInputTypeSnapshot == vVNI ? (ProcessingChar[runtimeInputTypeSnapshot][8] == key || ProcessingChar[runtimeInputTypeSnapshot][7] == key) : false))
#define IS_KEY_DOUBLE(key) ((runtimeInputTypeSnapshot != vVNI) ? (ProcessingChar[runtimeInputTypeSnapshot][5] == key || ProcessingChar[runtimeInputTypeSnapshot][6] == key || ProcessingChar[runtimeInputTypeSnapshot][7] == key) :\
                                        (runtimeInputTypeSnapshot == vVNI ? ProcessingChar[runtimeInputTypeSnapshot][6] == key : false))
#define IS_KEY_S(key) (ProcessingChar[runtimeInputTypeSnapshot][0] == key)
#define IS_KEY_F(key) (ProcessingChar[runtimeInputTypeSnapshot][1] == key)
#define IS_KEY_R(key) (ProcessingChar[runtimeInputTypeSnapshot][2] == key)
#define IS_KEY_X(key) (ProcessingChar[runtimeInputTypeSnapshot][3] == key)
#define IS_KEY_J(key) (ProcessingChar[runtimeInputTypeSnapshot][4] == key)

#define IS_MARK_KEY(keyCode) (((runtimeInputTypeSnapshot != vVNI) && (keyCode == KEY_S || keyCode == KEY_F || keyCode == KEY_R || keyCode == KEY_J || keyCode == KEY_X)) || \
                                        (runtimeInputTypeSnapshot == vVNI && (keyCode == KEY_1 || keyCode == KEY_2 || keyCode == KEY_3 || keyCode == KEY_5 || keyCode == KEY_4)))
#define IS_BRACKET_KEY(key) (key == KEY_LEFT_BRACKET || key == KEY_RIGHT_BRACKET)

static inline bool isSpecialKeyForCurrentInputType(const Uint16 keyCode) {
    switch (runtimeInputTypeSnapshot) {
    case vTelex:
        return keyCode == KEY_W || keyCode == KEY_E || keyCode == KEY_R || keyCode == KEY_O ||
               keyCode == KEY_LEFT_BRACKET || keyCode == KEY_RIGHT_BRACKET || keyCode == KEY_A ||
               keyCode == KEY_S || keyCode == KEY_D || keyCode == KEY_F || keyCode == KEY_J ||
               keyCode == KEY_Z || keyCode == KEY_X;
    case vVNI:
        return keyCode == KEY_1 || keyCode == KEY_2 || keyCode == KEY_3 || keyCode == KEY_4 ||
               keyCode == KEY_5 || keyCode == KEY_6 || keyCode == KEY_7 || keyCode == KEY_8 ||
               keyCode == KEY_9 || keyCode == KEY_0;
    case vSimpleTelex1:
    case vSimpleTelex2:
        return keyCode == KEY_W || keyCode == KEY_E || keyCode == KEY_R || keyCode == KEY_O ||
               keyCode == KEY_A || keyCode == KEY_S || keyCode == KEY_D || keyCode == KEY_F ||
               keyCode == KEY_J || keyCode == KEY_Z || keyCode == KEY_X;
    default:
        return false;
    }
}

#undef IS_SPECIALKEY
#define IS_SPECIALKEY(keyCode) isSpecialKeyForCurrentInputType(keyCode)
