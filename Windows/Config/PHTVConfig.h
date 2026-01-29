//
//  PHTVConfig.h
//  PHTV - Windows Configuration Manager
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

#ifndef PHTVCONFIG_H
#define PHTVCONFIG_H

#include <string>

// Global Configuration Variables (matches Engine.h externs)
// These define the configuration state of the application

// Input Settings
extern volatile int vInputType;       // 0: Telex, 1: VNI
extern volatile int vLanguage;        // 0: English, 1: Vietnamese
extern volatile int vCodeTable;       // 0: Unicode, 1: TCVN3, ...

// Feature Flags
extern int vFreeMark;                 // Free marking allows tone placement anywhere
extern volatile int vCheckSpelling;   // Enable spell check
extern volatile int vUseModernOrthography; // Modern tone placement (òa vs oà)
extern volatile int vQuickTelex;      // Quick typing features (cc=ch, etc)
extern volatile int vRestoreIfWrongSpelling; // Restore word if spelling is invalid
extern volatile int vUseMacro;        // Enable macro expansion
extern volatile int vRememberCode;    // Remember code table per app
extern volatile int vSendKeyStepByStep; // Compatibility: send key step by step
extern volatile int vPerformLayoutCompat; // Compatibility: layout mapping

// Configuration Manager Class
class PHTVConfig {
public:
    static PHTVConfig& Shared();

    void Load();
    void Save();
    void ResetDefaults();

    // Helper to get executable path
    std::wstring GetConfigPath();

private:
    PHTVConfig();
    std::wstring configFilePath;
};

#endif // PHTVCONFIG_H
