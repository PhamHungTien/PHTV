# Engine Swift Migration Plan

## Muc tieu

Chuyen toan bo engine hien tai (C/C++) sang Swift de codebase macOS dat muc "100% Swift" cho logic ung dung.

## Trang thai hien tai

- Swift files: 132
- C/C++ headers/sources: 20
- Cac file C/C++ con lai tap trung o:
  - `macOS/PHTV/Core/Engine/*`
  - `macOS/PHTV/Bridge/Engine/PHTVEngineCxxInterop.hpp`
  - `macOS/PHTV/PHTVBridgingHeader.h`
  - `macOS/PHTV/Core/*.h`
  - `tests/engine/EngineRegressionTests.cpp`

## Da hoan thanh (pha don dep)

- Da xoa module C++ `SmartSwitchKey`:
  - `macOS/PHTV/Core/Engine/SmartSwitchKey.h`
  - `macOS/PHTV/Core/Engine/SmartSwitchKey.cpp`
- Da bo include `SmartSwitchKey.h` khoi:
  - `macOS/PHTV/Core/Engine/Engine.h`
- Smart Switch runtime hien da duoc thay the bang Swift:
  - `macOS/PHTV/Bridge/SmartSwitch/PHTVSmartSwitchRuntimeService.swift`
- Da xoa module C++ `ConvertTool`:
  - `macOS/PHTV/Core/Engine/ConvertTool.h`
  - `macOS/PHTV/Core/Engine/ConvertTool.cpp`
- Da bo C++ debug interop cho convert tool:
  - `macOS/PHTV/Bridge/Engine/PHTVEngineDebugInteropFacade.swift`
  - wrappers `phtvEngineConvertUtf8`, `phtvConvertTool*` trong `PHTVEngineCxxInterop.hpp`
- Convert tool runtime va self-check hien chay bang Swift:
  - `macOS/PHTV/Bridge/System/PHTVConvertToolTextConversionService.swift`
- Da dua cac engine constant wrappers sang Swift facade:
  - key code constants (`space/delete/slash/enter/return`)
  - mask constants (`CAPS_MASK`, `CHAR_CODE_MASK`, `PURE_CHARACTER_MASK`)
  - action/result constants (`vDoNothing`, `vWillProcess`, `vRestore`, `vReplaceMaro`, `vRestoreAndStartNewSession`)
  - max buffer constant (`MAX_BUFF`) va navigation-key check
  - da xoa wrappers tuong ung trong `PHTVEngineCxxInterop.hpp`
- Da bo cac wrapper pass-through cho engine function:
  - `vSetCheckSpelling`, `vPrimeUpperCaseFirstChar`, `vRestoreToRawKeys`, `vTempOffSpellChecking`, `vTempOffEngine`
  - Swift facade goi truc tiep `v*` function va da xoa wrappers tuong ung trong `PHTVEngineCxxInterop.hpp`
- Da port keycode->character macro map sang Swift facade:
  - `macroKeyCodeToCharacter` hien dung bang map Swift (mirror `Vietnamese.cpp`)
  - `hotkeyDisplayCharacter` hien tai suy ra truc tiep tu mapping Swift
  - da xoa wrapper `phtvEngineMacroKeyCodeToCharacter` trong `PHTVEngineCxxInterop.hpp`
- Da bo wrapper `phtvEngineSetCheckSpellingValue`:
  - bootstrap dictionary goi truc tiep `PHTVEngineRuntimeFacade.setCheckSpelling(...)`
- Da bo wrappers custom dictionary count/init:
  - Swift facade goi truc tiep `initCustomDictionary`, `getCustomEnglishWordCount`, `getCustomVietnameseWordCount`
- Da bo wrappers dictionary size:
  - Swift facade goi truc tiep `getEnglishDictionarySize`, `getVietnameseDictionarySize`
- Da bo wrapper macro map init:
  - Swift facade goi truc tiep `initMacroMap(...)`
- Da bo wrappers session/custom-dictionary clear:
  - Swift facade goi truc tiep `startNewSession`, `clearCustomDictionary`
- Da bo wrappers dictionary init:
  - Swift facade tao `std.string` truc tiep va goi `initEnglishDictionary`, `initVietnameseDictionary`
- Da bo wrappers key-event forwarding:
  - Swift facade goi truc tiep `vKeyHandleEvent` va `vEnglishMode`
- Da bo wrappers code-table lookup:
  - Swift facade mang `_codeTable` data sang Swift de tra `findCodeTableSourceKey` / `variantCount` / `characterForKey`
- Da dua built-in dictionary runtime (English/Vietnamese binary trie) sang Swift bridge:
  - Them `Bridge/Engine/PHTVDictionaryTrieBridge.swift` cho load/search/count/clear trie
  - `EnglishWordDetector.cpp` hien route built-in dictionary qua C bridge
  - Giu weak C++ fallback de regression test standalone (khong link Swift) van chay
- Da dua auto-English restore detector runtime sang Swift bridge:
  - Them `Bridge/Engine/PHTVAutoEnglishRestoreBridge.swift` cho logic `checkIfEnglishWord(...)`
  - `EnglishWordDetector.cpp` route qua `phtvDetectorShouldRestoreEnglishWord(...)`
  - Giu weak C++ fallback de regression test standalone tiep tuc pass
  - Route them cac API detector con lai qua Swift bridge:
    - `isEnglishWord(...)`
    - `isEnglishWordFromKeyStates(...)`
    - `isVietnameseWordFromKeyStates(...)`
    - `keyStatesToString(...)`
- Da xoa C++ global runtime pointer bridge file:
  - Xoa `Bridge/Engine/PHTVEngineGlobals.cpp`
  - Runtime pointer `vKeyHookState*` duoc quan ly trong `PHTVEngineRuntimeFacade.swift`
  - Bo `extern pData` khoi `PHTVEngineCxxInterop.hpp`
- Da dua mot nhom runtime settings phu tro (khong can cho core C++) sang Swift storage:
  - `vSendKeyStepByStep`
  - `vEnableEmojiHotkey`, `vEmojiHotkeyModifiers`, `vEmojiHotkeyKeyCode`
  - `vShowIconOnDock`
  - `vPerformLayoutCompat`
  - `vSafeMode`
  - Da bo cac extern tuong ung khoi `PHTVEngineCxxInterop.hpp` va xoa dinh nghia khoi `Core/Engine/PHTVRuntimeState.cpp`
- Da dua them nhom runtime state khong duoc core C++ su dung truc tiep sang Swift storage:
  - `vLanguage`, `vSwitchKeyStatus`, `vFixRecommendBrowser`
  - `vUseMacroInEnglishMode`, `vUseSmartSwitchKey`
  - `vRememberCode`, `vOtherLanguage`
  - `vTempOffSpelling`, `vTempOffPHTV`
  - `vCustomEscapeKey`, `vPauseKeyEnabled`, `vPauseKey`
  - Da bo cac extern tuong ung khoi `PHTVEngineCxxInterop.hpp` va `Core/Engine/Engine.h`, dong thoi xoa dinh nghia khoi `Core/Engine/PHTVRuntimeState.cpp`
- Da dua `vRestoreOnEscape` sang Swift storage:
  - Them C bridge `phtvRuntimeRestoreOnEscapeEnabled()` do `PHTVEngineRuntimeFacade.swift` cung cap
  - `Engine.cpp` doc runtime setting qua bridge thay vi global C++
  - Giu weak fallback trong `Engine.cpp` de regression binary standalone (khong link Swift) van chay
- Da dua `vAutoCapsMacro` sang Swift storage:
  - Them C bridge `phtvRuntimeAutoCapsMacroValue()` do `PHTVEngineRuntimeFacade.swift` cung cap
  - `Macro.cpp` doc runtime setting qua bridge thay vi global C++
  - Giu weak fallback trong `Macro.cpp` de regression binary standalone van giu behavior mac dinh
- Da dua `vAutoRestoreEnglishWord` sang Swift storage:
  - Them C bridge `phtvRuntimeAutoRestoreEnglishWordEnabled()` do `PHTVEngineRuntimeFacade.swift` cung cap
  - `Engine.cpp` doc runtime setting qua bridge thay vi global C++
  - Giu weak fallback trong `Engine.cpp` de regression binary standalone van giu behavior mac dinh
- Da dua cap state auto-uppercase sang Swift storage:
  - `vUpperCaseFirstChar`
  - `vUpperCaseExcludedForCurrentApp`
  - `Engine.cpp` doc qua `phtvRuntimeUpperCaseFirstCharEnabled()` va `phtvRuntimeUpperCaseExcludedForCurrentApp()`
  - Giu weak fallback trong `Engine.cpp` cho regression binary standalone
- Da dua `vUseMacro` sang Swift storage:
  - Them C bridge `phtvRuntimeUseMacroEnabled()` do `PHTVEngineRuntimeFacade.swift` cung cap
  - `Engine.cpp` doc runtime setting qua bridge thay vi global C++
  - Giu weak fallback trong `Engine.cpp` de regression binary standalone van giu behavior mac dinh
- Da dua nhom Quick Consonant flags sang Swift storage:
  - `vAllowConsonantZFWJ`
  - `vQuickStartConsonant`
  - `vQuickEndConsonant`
  - `Engine.cpp` doc qua cac bridge `phtvRuntimeAllowConsonantZFWJEnabled()`, `phtvRuntimeQuickStartConsonantEnabled()`, `phtvRuntimeQuickEndConsonantEnabled()`
  - Giu weak fallback trong `Engine.cpp` de regression binary standalone van giu default cu
- Da dua nhom typing behavior flags sang Swift storage:
  - `vUseModernOrthography`
  - `vQuickTelex`
  - `vFreeMark`
  - `Engine.cpp` doc qua cac bridge `phtvRuntimeUseModernOrthographyEnabled()`, `phtvRuntimeQuickTelexEnabled()`, `phtvRuntimeFreeMarkEnabled()`
  - Giu weak fallback trong `Engine.cpp` de regression binary standalone van giu default cu
- Da dua `vCheckSpelling` sang Swift storage:
  - Them bridge `phtvRuntimeCheckSpellingValue()` va `phtvRuntimeSetCheckSpellingValue(...)` trong `PHTVEngineRuntimeFacade.swift`
  - `Engine.cpp` doc/ghi spell-check runtime qua bridge thay vi global C++
  - Giu weak fallback trong `Engine.cpp` cho regression binary standalone
- Da dua `vInputType` va `vCodeTable` sang Swift storage:
  - Them bridge `phtvRuntimeInputTypeValue()` va `phtvRuntimeCodeTableValue()` trong `PHTVEngineRuntimeFacade.swift`
  - `Engine.cpp` lay snapshot runtime dau moi key event de dung trong xu ly Telex/VNI va code table conversion
  - Bo extern/definition tuong ung khoi `PHTVEngineCxxInterop.hpp`, `Engine.h`, `PHTVRuntimeState.cpp`
  - Giu weak fallback trong `Engine.cpp` cho regression binary standalone

## Lo trinh migrate

### Pha 1: Dung "Swift facade" cho engine runtime

- Tao mot facade Swift cho toan bo runtime API hien dang goi truc tiep (`phtvRuntime*`, `phtvEngine*`).
- Muc tieu: gom diem tiep xuc C++ vao it file nhat, chuan bi cho thay backend.
- Dau ra:
  - Engine API map tu 1 noi.
  - Khong con call interop C++ truc tiep rai rac o `EventTap`, `Manager`, `System`.

### Pha 2: Port Convert Tool sang Swift

- Port logic tu `ConvertTool.cpp` sang Swift.
- Tach du lieu bang ma + mark table sang Swift resources/struct.
- Thay `phtvEngineConvertUtf8` bang Swift converter.

### Pha 3: Port Macro engine sang Swift

- Port parser/serializer macro binary.
- Port snippet runtime (date/time/random/counter).
- Bao dam behavior giong module `Macro.cpp`.

### Pha 4: Port English/Vietnamese detector sang Swift

- Port dictionary loader/lookup (co the giu binary format `*.bin`).
- Thay `EnglishWordDetector.cpp` bang Swift implementation.
- Dam bao khong tang latency keydown.

### Pha 5: Port core key processor sang Swift

- Port `Engine.cpp` + `Vietnamese.cpp` (xu ly key event, tone/mark/session, restore).
- Tao golden parity test theo chuoi key event.
- Kiem tra cac case: telex, vni, quick telex, macro, auto restore, restore key.

### Pha 6: Bo C++ interop

- Xoa `PHTVEngineCxxInterop.hpp`.
- Xoa `PHTVBridgingHeader.h` + flag `-cxx-interoperability-mode=default`.
- Xoa toan bo C/C++ source/header con lai trong `macOS/PHTV/Core/Engine`.
- Chuyen regression tests C++ sang Swift tests.

## Tieu chi "100% Swift"

- Khong con file `.c/.cc/.cpp/.h/.hpp/.m/.mm` trong logic app macOS.
- Khong con C++ interop flags trong project.
- Build + smoke test pass.
- Regression test pass tren bo test key-event parity.

## Thu tu uu tien de thuc hien tiep

1. Pha 1 (facade API) de giam coupling ngay.
2. Pha 2 (Convert Tool) vi doc lap voi luong go chinh.
3. Pha 4 (detector) truoc Pha 5 de chia nho rui ro.
4. Pha 5 (core processor) la pha lon nhat.
