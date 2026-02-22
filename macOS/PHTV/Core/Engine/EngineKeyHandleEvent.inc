void vKeyHandleEvent(const vKeyEvent& event,
                     const vKeyEventState& state,
                     const Uint16& data,
                     const Uint8& capsStatus,
                     const bool& otherControlKey) {
    refreshRuntimeLayoutSnapshot();

    // PERFORMANCE: Debug logging only in debug builds (hot path - called on every keystroke)
    #ifdef DEBUG
    static int lastInputType = -1;
    if (runtimeInputTypeSnapshot != lastInputType) {
        printf("[Engine] vInputType CHANGED TO %d (was %d)\n", runtimeInputTypeSnapshot, lastInputType);
        fflush(stdout);
        lastInputType = runtimeInputTypeSnapshot;
    }
    #endif

    // NEW FEATURE: Restore key - ESC only
    // Note: Modifier keys (Option, Control) are handled in PHTV.mm via kCGEventFlagsChanged
    // We ONLY handle ESC key here to avoid conflicts with typing (e.g. VNI number keys)
    if (phtvRuntimeRestoreOnEscapeEnabled() && _index > 0 && data == KEY_ESC) {
        if (restoreToRawKeys()) {
            // Successfully restored - let the engine handle vRestore code
            // Don't call startNewSession() here as it will clear hCode
            // The vRestore code will be processed and session will be cleared later
            return;
        }
    }

    _isCaps = (capsStatus == 1 || //shift
               capsStatus == 2); //caps lock
    const bool isAutoRestoreBreakKey = isAutoRestoreWordBreak(event, state, data, capsStatus);
    if ((IS_NUMBER_KEY(data) && capsStatus == 1)
#include "EngineKeyHandleEventWordBreak.inc"
    } else if (data == KEY_SPACE) {
#include "EngineKeyHandleEventSpace.inc"
    } else if (data == KEY_DELETE) {
#include "EngineKeyHandleEventDelete.inc"
    } else { //START AND CHECK KEY
#include "EngineKeyHandleEventMainFlow.inc"
    }
    
    //Debug
    //cout<<"index "<<(int)_index<< ", stateIndex "<<(int)_stateIndex<<", word "<<_typingStates.size()<<", long word "<<_longWordHelper.size()<< endl;
    //cout<<"backspace "<<(int)hBPC<<endl;
    //cout<<"new char "<<(int)hNCC<<endl<<endl;
}
