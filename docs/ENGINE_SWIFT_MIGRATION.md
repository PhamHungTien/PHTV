# Engine Swift Migration Plan

## Muc tieu

Chuyen toan bo engine hien tai (C/C++) sang Swift de codebase macOS dat muc "100% Swift" cho logic ung dung.

## Trang thai hien tai

- Swift files: 140
- C/C++ headers/sources: 3
- Cac file C/C++ con lai tap trung o:
  - `macOS/PHTV/Core/Engine/*`
  - `tests/engine/EnglishWordDetectorFallback.cpp`
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
  - `macroKeyCodeToCharacter` hien dung bang map Swift (mirror `VietnameseData.inc`)
  - `hotkeyDisplayCharacter` hien tai suy ra truc tiep tu mapping Swift
  - da xoa wrapper `phtvEngineMacroKeyCodeToCharacter` trong `PHTVEngineCxxInterop.hpp`
- Da bo wrapper `phtvEngineSetCheckSpellingValue`:
  - bootstrap dictionary goi truc tiep `PHTVEngineRuntimeFacade.setCheckSpelling(...)`
- Da bo wrappers custom dictionary count/init:
  - Swift facade goi truc tiep `initCustomDictionary`, `getCustomEnglishWordCount`, `getCustomVietnameseWordCount`
- Da bo wrappers dictionary size:
  - Swift facade goi truc tiep `getEnglishDictionarySize`, `getVietnameseDictionarySize`
- Da bo wrapper macro map init:
  - Swift facade goi truc tiep `phtvLoadMacroMapFromBinary(...)`
- Da bo wrappers session/custom-dictionary clear:
  - `PHTVEngineDataBridge` goi truc tiep `startNewSession`, `clearCustomDictionary`
  - Bo pass-through `startNewSession` khoi `PHTVEngineRuntimeFacade`
- Da bo wrappers dictionary init:
  - Swift facade tao `std.string` truc tiep va goi `initEnglishDictionary`, `initVietnameseDictionary`
- Da bo phu thuoc `EnglishWordDetector.h` trong Swift data bridge:
  - `PHTVEngineDataBridge` goi truc tiep C bridge `phtvDictionary*` va `phtvCustomDictionary*`
  - `PHTVBridgingHeader.h` khong con import `Core/Engine/EnglishWordDetector.h`
- Da don gian hoa `PHTVEngineRuntimeFacade`:
  - Bo cac pass-through methods dictionary/custom-dictionary (`initialize*Dictionary`, `*DictionarySize`, `initCustomDictionary`, `getCustom*WordCount`, `clearCustomDictionary`)
  - `PHTVEngineDataBridge` goi truc tiep C++ API thay vi qua them 1 lop wrapper
  - Bo wrappers keycode constants (`space/delete/slash/enter/return`), call site dung truc tiep `KeyCode`
  - Bo wrapper `hotkeyDisplayCharacter`, call site goi truc tiep `macroKeyCodeToCharacter(...)`
  - Bo wrappers default setting (`defaultSwitchHotkeyStatus`, `defaultPauseKey`), call site dung truc tiep `Defaults`/`KeyCode`
  - Bo wrappers pass-through `applyCheckSpelling`, `tempOffSpellChecking`, `tempOffEngineNow`; call site goi truc tiep C API
  - Bo wrappers key-event/session forwarding (`handleMouseDown`, `handleKeyboardKeyDown`, `handleEnglishModeKeyDown`, `primeUpperCaseFirstChar`, `restoreToRawKeys`, `barrier`); call site goi truc tiep C API/`OSMemoryBarrier`
  - Bo wrapper `notifyTableCodeChanged`; call site tu tai nap macro binary qua `PHTVEngineDataBridge`
  - Bo wrapper `eventMarkerValue`; call site dung chung hang `EventSourceMarker.phtv`
  - Bo wrappers mask constants (`capsMask`, `charCodeMask`, `pureCharacterMask`); call site dung hang `EngineBitMask`
  - Bo wrappers packed-data helpers (`lowByte`, `hiByte`, `unicodeCompoundMarkAt`); call site dung utility `EnginePackedData`
  - Bo wrappers engine signal constants (`engineDoNothingCode`, `engineWillProcessCode`, `engineRestoreCode`, `engineReplaceMacroCode`, `engineRestoreAndStartNewSessionCode`, `engineMaxBuffer`); call site dung hang `EngineSignalCode`
  - Bo wrappers input classification (`isDoubleCode`, `isNavigationKey`); call site dung utility `EngineInputClassification`
  - Bo wrapper `macroKeyCodeToCharacter`; call site dung utility `EngineMacroKeyMap`
  - Bo wrappers code-table lookup (`findCodeTableSourceKey`, `codeTableVariantCount`, `codeTableCharacterForKey`); call site dung utility `EngineCodeTableLookup`
  - Tach snippet runtime (`date/time/random/counter`) sang utility `EngineMacroSnippetRuntime`
- Da chuyen callsite key-event forwarding sang C bridge:
  - Swift facade goi `phtvEngineHandleEvent` va `phtvEngineHandleEnglishMode` thay vi goi truc tiep C++ API
- Da chuyen nhom control API engine sang C bridge `phtvEngine*`:
  - `primeUpperCaseFirstChar`, `restoreToRawKeys`, `tempOffSpellChecking`, `tempOffEngine`, `setCheckSpelling`, `startNewSession`
- Da chuyen doc HookState sang C bridge:
  - `PHTVEngineRuntimeFacade` doc `code/extCode/backspace/newChar/charData/macroData` qua `phtvEngineHook*`
  - Swift khong con truy cap truc tiep `vKeyHookState` / `vKeyInit`
- Da bo include `Core/Engine/Engine.h` khoi `PHTVBridgingHeader.h`:
  - Bridging header chi con dung `Core/Engine/PHTVEngineCBridge.h`
- Da bo phu thuoc `PHTVCodeTable*` constants trong Swift:
  - Call site dung enum Swift `CodeTable` (khong can import `Core/PHTVConstants.h`)
- Da bo phu thuoc `KEY_*` constants trong Swift key sender:
  - Dung `KeyCode.delete` / `KeyCode.leftArrow`
- Da bo Swift C++ interop compiler flag:
  - `OTHER_SWIFT_FLAGS` khong con `-cxx-interoperability-mode=default` (Debug/Release)
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
- Da route callsite detector trong `Engine.cpp` sang C bridge:
  - `Engine.cpp` goi truc tiep `phtvDetector*` thay vi include `EnglishWordDetector.h`
  - Them helper bridge-string de debug auto-English (`phtvDetectorKeyStatesToAscii`)
  - Mo rong declaration trong `Core/Engine/PHTVEngineCBridge.h` cho nhom runtime/dictionary/detector APIs
  - `EnglishWordDetector.cpp` import chung `PHTVEngineCBridge.h` thay cho block `extern "C"` khai bao thu cong
  - `tests/engine/EngineRegressionTests.cpp` goi `phtvDictionary*`/`phtvCustomDictionary*` thay vi include `EnglishWordDetector.h`
  - `tests/engine/EngineRegressionTests.cpp` tiep tuc bo call truc tiep `vKey*`/`vKeyHookState` tu `Engine.h`, chuyen sang `phtvEngine*` C bridge
  - Dong bo lai cache count custom dictionary trong fallback detector + them case regression `qes` de khoa behavior custom-English restore
  - Da xoa API wrapper C++ legacy trong `EnglishWordDetector.cpp` va xoa file header `Core/Engine/EnglishWordDetector.h`
  - Da dua `EnglishWordDetector.cpp` ra khoi app target: fallback detector runtime nay chay trong `tests/engine/EnglishWordDetectorFallback.cpp` cho regression binary standalone
- Da xoa C++ global runtime pointer bridge file:
  - Xoa `Bridge/Engine/PHTVEngineGlobals.cpp`
  - HookState duoc truy cap qua C bridge `phtvEngineHook*` (khong con pointer C++ trong Swift)
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
  - Logic macro trong `Engine.cpp` doc runtime setting qua bridge thay vi global C++
  - Giu weak fallback trong `Engine.cpp` de regression binary standalone van giu behavior mac dinh
- Da don dep module macro C++ tach rieng:
  - Gop `initMacroMap(...)` va `findMacro(...)` vao `Engine.cpp`
  - Xoa `Core/Engine/Macro.cpp`
- Da bo API C++ `initMacroMap(...)`:
  - Swift (`PHTVEngineDataBridge`) goi truc tiep C bridge `phtvLoadMacroMapFromBinary(...)`
  - Bo declaration/definition `initMacroMap(...)` khoi `Engine.h` va `Engine.cpp`
- Da bo utility C++ khong con su dung:
  - Xoa `utf8ToWideString(...)` va `wideStringToUtf8(...)` khoi `Engine.h`/`Engine.cpp`
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
  - Don dep macro runtime cu trong `DataType.h` (`PHTV_CURRENT_INPUT_TYPE` / `IS_SPECIALKEY`) vi `Engine.cpp` da tu quan ly snapshot input type
- Da bo file interop wrapper C++:
  - Xoa `Bridge/Engine/PHTVEngineCxxInterop.hpp`
  - `PHTVBridgingHeader.h` hien import `Core/Engine/PHTVEngineCBridge.h`
- Da xoa cac legacy headers khong con su dung:
  - `macOS/PHTV/Core/PHTVConstants.h`
  - `macOS/PHTV/Core/PHTVHotkey.h`
  - `macOS/PHTV/Core/mac.h`
- Da loai bo `Core/Engine/Engine.h`:
  - Header nay khong con call site ben ngoai; declaration duoc internal hoa trong `Engine.cpp`
- Da loai bo `Core/Engine/Vietnamese.h`:
  - Declaration cho bang du lieu tieng Viet duoc internal hoa trong `Engine.cpp`
- Da loai bo `Core/phtv_mac_keys.h`:
  - Keycode constants duoc gom vao `Core/Engine/DataType.h`
- Da xoa wrapper `PHTVBridgingHeader.h`:
  - Build setting `SWIFT_OBJC_BRIDGING_HEADER` hien tro truc tiep `PHTV/Core/Engine/PHTVEngineCBridge.h`
- Da internalize `Vietnamese.cpp` vao `Engine.cpp`:
  - Bang du lieu keycode/vowel/consonant duoc include noi bo qua `Core/Engine/VietnameseData.inc`

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
- Bao dam behavior giong logic macro hien tai trong `Engine.cpp`.

### Pha 4: Port English/Vietnamese detector sang Swift

- Port dictionary loader/lookup (co the giu binary format `*.bin`).
- Da thay `EnglishWordDetector.cpp` trong app target bang Swift implementation; fallback C++ chi con o regression tests.
- Dam bao khong tang latency keydown.

### Pha 5: Port core key processor sang Swift

- Port `Engine.cpp` (bao gom phan du lieu/trien khai tieng Viet dang internalized qua `VietnameseData.inc`) cho xu ly key event, tone/mark/session, restore.
- Tao golden parity test theo chuoi key event.
- Kiem tra cac case: telex, vni, quick telex, macro, auto restore, restore key.

### Pha 6: Bo C++ interop

- Xoa `PHTVEngineCxxInterop.hpp`.
- Da xoa wrapper `PHTVBridgingHeader.h`; `SWIFT_OBJC_BRIDGING_HEADER` tro truc tiep `PHTVEngineCBridge.h`.
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
