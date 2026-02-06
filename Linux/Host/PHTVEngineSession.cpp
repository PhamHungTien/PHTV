#include "PHTVEngineSession.h"

namespace phtv::linux_host {

PHTVEngineSession::PHTVEngineSession()
    : state_(static_cast<vKeyHookState*>(vKeyInit())) {}

void PHTVEngineSession::startSession() {
    state_ = static_cast<vKeyHookState*>(vKeyInit());
}

EngineOutput PHTVEngineSession::processKeyDown(Uint16 engineKeyCode,
                                               bool isCaps,
                                               bool hasOtherControlKey) {
    if (!state_) {
        startSession();
    }

    vKeyHandleEvent(vKeyEvent::Keyboard,
                    vKeyEventState::KeyDown,
                    engineKeyCode,
                    isCaps ? 1 : 0,
                    hasOtherControlKey);

    EngineOutput out;
    out.code = state_->code;
    out.extCode = state_->extCode;
    out.backspaceCount = state_->backspaceCount;
    out.committedChars.assign(state_->charData, state_->charData + state_->newCharCount);
    return out;
}

} // namespace phtv::linux_host
