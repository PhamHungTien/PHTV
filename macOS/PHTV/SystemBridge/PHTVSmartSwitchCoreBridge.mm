//
//  PHTVSmartSwitchCoreBridge.mm
//  PHTV
//
//  C bridge helpers for Smart Switch runtime state.
//

#import "PHTVCoreBridge.h"

#include <vector>
#include <string>

#include "../Core/Engine/DataType.h"
#include "../Core/Engine/SmartSwitchKey.h"

extern "C" {

NSData *PHTVSmartSwitchSerializedData(void) {
    std::vector<Byte> data;
    getSmartSwitchKeySaveData(data);
    return [NSData dataWithBytes:data.data() length:data.size()];
}

int PHTVSmartSwitchNotFound(void) {
    return SMART_SWITCH_NOT_FOUND;
}

int PHTVSmartSwitchEncodeState(int inputMethod, int codeTable) {
    return encodeSmartSwitchInputState(inputMethod, codeTable);
}

int PHTVSmartSwitchDecodeInputMethod(int state) {
    return decodeSmartSwitchInputMethod(state);
}

int PHTVSmartSwitchDecodeCodeTable(int state) {
    return decodeSmartSwitchCodeTable(state);
}

int PHTVSmartSwitchGetAppState(NSString *bundleId, int defaultInputState) {
    if (!bundleId || bundleId.length == 0) {
        return SMART_SWITCH_NOT_FOUND;
    }
    return getAppInputMethodStatus(std::string(bundleId.UTF8String), defaultInputState);
}

void PHTVSmartSwitchSetAppState(NSString *bundleId, int inputState) {
    if (!bundleId || bundleId.length == 0) {
        return;
    }
    setAppInputMethodStatus(std::string(bundleId.UTF8String), inputState);
}

} // extern "C"
