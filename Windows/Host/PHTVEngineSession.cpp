#include "PHTVEngineSession.h"

namespace phtv::windows_host {

PHTVEngineSession::PHTVEngineSession()
    : state_(static_cast<vKeyHookState*>(vKeyInit())) {}

void PHTVEngineSession::startSession() {
    state_ = static_cast<vKeyHookState*>(vKeyInit());
}

EngineOutput PHTVEngineSession::processKeyDown(Uint16 engineKeyCode,
                                               Uint8 capsStatus,
                                               bool hasOtherControlKey) {
    if (!state_) {
        startSession();
    }

    if (vLanguage == 0) { // English mode
        vEnglishMode(vKeyEventState::KeyDown,
                     engineKeyCode,
                     (capsStatus != 0),
                     hasOtherControlKey);
    } else { // Vietnamese mode
        vKeyHandleEvent(vKeyEvent::Keyboard,
                        vKeyEventState::KeyDown,
                        engineKeyCode,
                        capsStatus,
                        hasOtherControlKey);
    }

    EngineOutput out;
    out.code = state_->code;
    out.extCode = state_->extCode;
    out.backspaceCount = state_->backspaceCount;
    out.committedChars.assign(state_->charData, state_->charData + state_->newCharCount);
    out.macroChars = state_->macroData;
    return out;
}

void PHTVEngineSession::notifyMouseDown() {
    if (!state_) {
        startSession();
    }
    
    if (vLanguage == 0) { // English mode
        vEnglishMode(vKeyEventState::MouseDown, 0, false, false);
    } else { // Vietnamese mode
        vKeyHandleEvent(vKeyEvent::Mouse,
                        vKeyEventState::MouseDown,
                        0,
                        0,
                        false);
    }
}

} // namespace phtv::windows_host
