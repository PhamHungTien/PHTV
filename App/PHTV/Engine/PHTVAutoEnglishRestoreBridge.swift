//
//  PHTVAutoEnglishRestoreBridge.swift
//  PHTV
//
//  Swift bridge for auto-English restore decision logic.
//

import Foundation

private let detectorMaxWordLength = 30
private let detectorKeyMask: UInt32 = 0x3F
private let detectorInvalidIndex: UInt8 = 255

private enum DetectorKeyCode {
    static let a: UInt8 = 0
    static let b: UInt8 = 11
    static let c: UInt8 = 8
    static let d: UInt8 = 2
    static let e: UInt8 = 14
    static let f: UInt8 = 3
    static let g: UInt8 = 5
    static let h: UInt8 = 4
    static let i: UInt8 = 34
    static let j: UInt8 = 38
    static let k: UInt8 = 40
    static let l: UInt8 = 37
    static let m: UInt8 = 46
    static let n: UInt8 = 45
    static let o: UInt8 = 31
    static let p: UInt8 = 35
    static let q: UInt8 = 12
    static let r: UInt8 = 15
    static let s: UInt8 = 1
    static let t: UInt8 = 17
    static let u: UInt8 = 32
    static let v: UInt8 = 9
    static let w: UInt8 = 13
    static let x: UInt8 = 7
    static let y: UInt8 = 16
    static let z: UInt8 = 6

    static let leftBracket: UInt8 = 33
    static let rightBracket: UInt8 = 30
}

private enum DetectorIndex {
    static let a: UInt8 = 0
    static let b: UInt8 = 1
    static let c: UInt8 = 2
    static let d: UInt8 = 3
    static let e: UInt8 = 4
    static let f: UInt8 = 5
    static let g: UInt8 = 6
    static let h: UInt8 = 7
    static let i: UInt8 = 8
    static let j: UInt8 = 9
    static let k: UInt8 = 10
    static let l: UInt8 = 11
    static let m: UInt8 = 12
    static let n: UInt8 = 13
    static let o: UInt8 = 14
    static let p: UInt8 = 15
    static let q: UInt8 = 16
    static let r: UInt8 = 17
    static let s: UInt8 = 18
    static let t: UInt8 = 19
    static let u: UInt8 = 20
    static let v: UInt8 = 21
    static let w: UInt8 = 22
    static let x: UInt8 = 23
    static let y: UInt8 = 24
    static let z: UInt8 = 25
}

private let detectorKeyCodeToIndex: [UInt8] = {
    var mapping = [UInt8](repeating: detectorInvalidIndex, count: 64)
    mapping[Int(DetectorKeyCode.a)] = DetectorIndex.a
    mapping[Int(DetectorKeyCode.b)] = DetectorIndex.b
    mapping[Int(DetectorKeyCode.c)] = DetectorIndex.c
    mapping[Int(DetectorKeyCode.d)] = DetectorIndex.d
    mapping[Int(DetectorKeyCode.e)] = DetectorIndex.e
    mapping[Int(DetectorKeyCode.f)] = DetectorIndex.f
    mapping[Int(DetectorKeyCode.g)] = DetectorIndex.g
    mapping[Int(DetectorKeyCode.h)] = DetectorIndex.h
    mapping[Int(DetectorKeyCode.i)] = DetectorIndex.i
    mapping[Int(DetectorKeyCode.j)] = DetectorIndex.j
    mapping[Int(DetectorKeyCode.k)] = DetectorIndex.k
    mapping[Int(DetectorKeyCode.l)] = DetectorIndex.l
    mapping[Int(DetectorKeyCode.m)] = DetectorIndex.m
    mapping[Int(DetectorKeyCode.n)] = DetectorIndex.n
    mapping[Int(DetectorKeyCode.o)] = DetectorIndex.o
    mapping[Int(DetectorKeyCode.p)] = DetectorIndex.p
    mapping[Int(DetectorKeyCode.q)] = DetectorIndex.q
    mapping[Int(DetectorKeyCode.r)] = DetectorIndex.r
    mapping[Int(DetectorKeyCode.s)] = DetectorIndex.s
    mapping[Int(DetectorKeyCode.t)] = DetectorIndex.t
    mapping[Int(DetectorKeyCode.u)] = DetectorIndex.u
    mapping[Int(DetectorKeyCode.v)] = DetectorIndex.v
    mapping[Int(DetectorKeyCode.w)] = DetectorIndex.w
    mapping[Int(DetectorKeyCode.x)] = DetectorIndex.x
    mapping[Int(DetectorKeyCode.y)] = DetectorIndex.y
    mapping[Int(DetectorKeyCode.z)] = DetectorIndex.z
    return mapping
}()

private let derivationAbilitySuffix = detectorIndices(from: "ability")
private let derivationAbilitiesSuffix = detectorIndices(from: "abilities")
private let derivationIbilitySuffix = detectorIndices(from: "ibility")
private let derivationIbilitiesSuffix = detectorIndices(from: "ibilities")
private let derivationAbleSuffix = detectorIndices(from: "able")
private let derivationIbleSuffix = detectorIndices(from: "ible")
private let englishSuffixFallbacks: [[UInt8]] = [
    detectorIndices(from: "ing"),
    detectorIndices(from: "ers"),
    detectorIndices(from: "er"),
    detectorIndices(from: "ed"),
    detectorIndices(from: "es"),
    detectorIndices(from: "s")
]

private struct DetectorDecodedWord {
    let indices: [UInt8]
    let keyCodes: [UInt8]
    let cString: [CChar]
}

private func detectorIndices(from text: String) -> [UInt8] {
    var output: [UInt8] = []
    output.reserveCapacity(text.count)
    for scalar in text.unicodeScalars {
        let value = scalar.value
        guard value >= 97, value <= 122 else {
            return []
        }
        output.append(UInt8(value - 97))
    }
    return output
}

private func decodeDetectorWord(
    keyStates: UnsafePointer<UInt32>,
    length: Int
) -> DetectorDecodedWord? {
    guard length > 0, length <= detectorMaxWordLength else {
        return nil
    }

    var indices: [UInt8] = []
    indices.reserveCapacity(length)

    var keyCodes: [UInt8] = []
    keyCodes.reserveCapacity(length)

    var cString = [CChar](repeating: 0, count: length + 1)

    for i in 0..<length {
        let keyCode = UInt8(keyStates[i] & detectorKeyMask)
        let keyCodeInt = Int(keyCode)
        guard keyCodeInt < detectorKeyCodeToIndex.count else {
            return nil
        }

        let letterIndex = detectorKeyCodeToIndex[keyCodeInt]
        guard letterIndex < 26 else {
            return nil
        }

        keyCodes.append(keyCode)
        indices.append(letterIndex)
        cString[i] = Int8(bitPattern: letterIndex &+ 97)
    }

    return DetectorDecodedWord(indices: indices, keyCodes: keyCodes, cString: cString)
}

private func decodeDetectorAsciiWord(_ wordCString: UnsafePointer<CChar>) -> [UInt8]? {
    var output: [UInt8] = []
    output.reserveCapacity(detectorMaxWordLength)

    var cursor = wordCString
    while cursor.pointee != 0 && output.count < detectorMaxWordLength {
        let raw = UInt8(bitPattern: cursor.pointee)

        if raw >= 97 && raw <= 122 {
            output.append(raw - 97)
        } else if raw >= 65 && raw <= 90 {
            output.append(raw - 65)
        } else {
            return nil
        }

        cursor = cursor.advanced(by: 1)
    }

    return output.isEmpty ? nil : output
}

private func detectorContainsCustomEnglish(_ cString: [CChar]) -> Bool {
    guard phtvCustomDictionaryEnglishCount() > 0 else {
        return false
    }
    return cString.withUnsafeBufferPointer { buffer in
        phtvCustomDictionaryContainsEnglishWord(buffer.baseAddress) != 0
    }
}

private func detectorContainsCustomVietnamese(_ cString: [CChar]) -> Bool {
    guard phtvCustomDictionaryVietnameseCount() > 0 else {
        return false
    }
    return cString.withUnsafeBufferPointer { buffer in
        phtvCustomDictionaryContainsVietnameseWord(buffer.baseAddress) != 0
    }
}

private func detectorContainsEnglish(
    _ indices: [UInt8],
    length: Int
) -> Bool {
    guard !indices.isEmpty,
          length > 0,
          length <= indices.count,
          length <= detectorMaxWordLength else {
        return false
    }

    return indices.withUnsafeBufferPointer { buffer in
        phtvDictionaryContainsEnglishIndices(buffer.baseAddress, Int32(length)) != 0
    }
}

private func detectorContainsVietnamese(
    _ indices: [UInt8],
    length: Int
) -> Bool {
    guard !indices.isEmpty,
          length > 0,
          length <= indices.count,
          length <= detectorMaxWordLength else {
        return false
    }

    return indices.withUnsafeBufferPointer { buffer in
        phtvDictionaryContainsVietnameseIndices(buffer.baseAddress, Int32(length)) != 0
    }
}

private func isDetectorVowel(_ index: UInt8) -> Bool {
    index == DetectorIndex.a ||
    index == DetectorIndex.e ||
    index == DetectorIndex.i ||
    index == DetectorIndex.o ||
    index == DetectorIndex.u
}

private func isDetectorToneMarkIndex(_ index: UInt8) -> Bool {
    index == DetectorIndex.s ||
    index == DetectorIndex.f ||
    index == DetectorIndex.r ||
    index == DetectorIndex.x ||
    index == DetectorIndex.j ||
    index == DetectorIndex.w
}

private func isDetectorTelexConflictToneMark(_ index: UInt8) -> Bool {
    index == DetectorIndex.s ||
    index == DetectorIndex.f ||
    index == DetectorIndex.r ||
    index == DetectorIndex.x ||
    index == DetectorIndex.j
}

private func startsWithNonVietnameseCluster(
    _ indices: [UInt8],
    length: Int
) -> Bool {
    guard length > 0 else {
        return false
    }

    let first = indices[0]
    let second = length > 1 ? indices[1] : detectorInvalidIndex
    let third = length > 2 ? indices[2] : detectorInvalidIndex

    if first == DetectorIndex.f || first == DetectorIndex.j || first == DetectorIndex.w || first == DetectorIndex.z {
        return true
    }

    if second != detectorInvalidIndex {
        if (first == DetectorIndex.b && (second == DetectorIndex.l || second == DetectorIndex.r)) ||
            (first == DetectorIndex.c && (second == DetectorIndex.l || second == DetectorIndex.r)) ||
            (first == DetectorIndex.d && second == DetectorIndex.r) ||
            (first == DetectorIndex.f && (second == DetectorIndex.l || second == DetectorIndex.r)) ||
            (first == DetectorIndex.g && (second == DetectorIndex.l || second == DetectorIndex.r)) ||
            (first == DetectorIndex.p && (second == DetectorIndex.l || second == DetectorIndex.r)) ||
            (first == DetectorIndex.s && (
                second == DetectorIndex.c || second == DetectorIndex.k ||
                second == DetectorIndex.l || second == DetectorIndex.m ||
                second == DetectorIndex.n || second == DetectorIndex.p ||
                second == DetectorIndex.t || second == DetectorIndex.w ||
                second == DetectorIndex.q
            )) ||
            (first == DetectorIndex.t && second == DetectorIndex.w) ||
            (first == DetectorIndex.w && second == DetectorIndex.r) {
            return true
        }
    }

    if third != detectorInvalidIndex {
        if (first == DetectorIndex.s && second == DetectorIndex.h && third == DetectorIndex.r) ||
            (first == DetectorIndex.s && second == DetectorIndex.t && third == DetectorIndex.r) ||
            (first == DetectorIndex.s && second == DetectorIndex.p && third == DetectorIndex.r) ||
            (first == DetectorIndex.s && second == DetectorIndex.c && third == DetectorIndex.r) {
            return true
        }
    }

    return false
}

private func hasDetectorTelexConflict(
    _ indices: [UInt8],
    length: Int
) -> Bool {
    guard length >= 2 else {
        return false
    }

    for i in 0..<(length - 1) {
        let c1 = indices[i]
        let c2 = indices[i + 1]

        if (c1 == DetectorIndex.a && c2 == DetectorIndex.a) ||
            (c1 == DetectorIndex.e && c2 == DetectorIndex.e) ||
            (c1 == DetectorIndex.o && c2 == DetectorIndex.o) {
            return true
        }

        if (c1 == DetectorIndex.a && c2 == DetectorIndex.w) ||
            (c1 == DetectorIndex.o && c2 == DetectorIndex.w) ||
            (c1 == DetectorIndex.u && c2 == DetectorIndex.w) {
            return true
        }

        if c1 == DetectorIndex.d && c2 == DetectorIndex.d {
            return true
        }

        if isDetectorVowel(c1) && isDetectorTelexConflictToneMark(c2) {
            return true
        }
    }

    return false
}

private func detectorEndsWithSuffix(
    _ indices: [UInt8],
    length: Int,
    suffix: [UInt8]
) -> Bool {
    guard !suffix.isEmpty, length >= suffix.count else {
        return false
    }

    let start = length - suffix.count
    for i in 0..<suffix.count where indices[start + i] != suffix[i] {
        return false
    }

    return true
}

private func detectorToneMarkInMiddle(
    _ indices: [UInt8],
    length: Int
) -> Bool {
    guard length >= 3 else {
        return false
    }

    for i in 0..<(length - 1) {
        let id = indices[i]
        let next = indices[i + 1]
        if isDetectorToneMarkIndex(next) && isDetectorVowel(id) {
            return true
        }
    }

    return false
}

private func detectorTonelessIndices(
    _ indices: [UInt8],
    length: Int
) -> [UInt8] {
    var output: [UInt8] = []
    output.reserveCapacity(length)

    var i = 0
    while i < length {
        let current = indices[i]
        let next = i + 1 < length ? indices[i + 1] : detectorInvalidIndex

        output.append(current)

        if isDetectorVowel(current) && isDetectorToneMarkIndex(next) {
            i += 2
        } else {
            i += 1
        }
    }

    return output
}

private func isToneMarkKeyCode(lastKey: UInt8, firstKey: UInt8) -> Bool {
    if lastKey == DetectorKeyCode.s ||
        lastKey == DetectorKeyCode.f ||
        lastKey == DetectorKeyCode.r ||
        lastKey == DetectorKeyCode.x ||
        lastKey == DetectorKeyCode.j ||
        lastKey == DetectorKeyCode.w ||
        lastKey == DetectorKeyCode.a ||
        lastKey == DetectorKeyCode.o ||
        lastKey == DetectorKeyCode.e ||
        lastKey == DetectorKeyCode.leftBracket ||
        lastKey == DetectorKeyCode.rightBracket {
        return true
    }

    return lastKey == DetectorKeyCode.d && firstKey == DetectorKeyCode.d
}

private func isDetectorToneMarkKeyCode(_ keyCode: UInt8) -> Bool {
    keyCode == DetectorKeyCode.s ||
    keyCode == DetectorKeyCode.f ||
    keyCode == DetectorKeyCode.r ||
    keyCode == DetectorKeyCode.x ||
    keyCode == DetectorKeyCode.j
}

private func isDetectorVietnameseFinalConsonantKeyCode(_ keyCode: UInt8) -> Bool {
    keyCode == DetectorKeyCode.c ||
    keyCode == DetectorKeyCode.k ||
    keyCode == DetectorKeyCode.m ||
    keyCode == DetectorKeyCode.n ||
    keyCode == DetectorKeyCode.p ||
    keyCode == DetectorKeyCode.t
}

private func hasLikelyVietnameseTelexAWCodaPattern(
    keyCodes: [UInt8],
    length: Int
) -> Bool {
    guard length >= 4 else {
        return false
    }

    let hasToneKey = keyCodes.contains(where: { isDetectorToneMarkKeyCode($0) })
    guard hasToneKey else {
        return false
    }

    var hasAWPattern = false
    if length >= 2 {
        for i in 0..<(length - 1) {
            if keyCodes[i] != DetectorKeyCode.a {
                continue
            }
            if keyCodes[i + 1] == DetectorKeyCode.w {
                hasAWPattern = true
                break
            }
            if i + 2 < length &&
                isDetectorToneMarkKeyCode(keyCodes[i + 1]) &&
                keyCodes[i + 2] == DetectorKeyCode.w {
                hasAWPattern = true
                break
            }
        }
    }

    guard hasAWPattern else {
        return false
    }

    let last = keyCodes[length - 1]
    if isDetectorVietnameseFinalConsonantKeyCode(last) {
        return true
    }
    if isDetectorToneMarkKeyCode(last) &&
        length >= 2 &&
        isDetectorVietnameseFinalConsonantKeyCode(keyCodes[length - 2]) {
        return true
    }

    return false
}

private func startsWithNonVietnameseKeyCluster(
    keyCodes: [UInt8],
    length: Int
) -> Bool {
    guard length >= 3 else {
        return false
    }

    let first = keyCodes[0]
    let second = keyCodes[1]

    if (first == DetectorKeyCode.b && second == DetectorKeyCode.l) ||
        (first == DetectorKeyCode.b && second == DetectorKeyCode.r) ||
        (first == DetectorKeyCode.c && second == DetectorKeyCode.l) ||
        (first == DetectorKeyCode.c && second == DetectorKeyCode.r) ||
        (first == DetectorKeyCode.d && second == DetectorKeyCode.r) ||
        (first == DetectorKeyCode.f && second == DetectorKeyCode.l) ||
        (first == DetectorKeyCode.f && second == DetectorKeyCode.r) ||
        (first == DetectorKeyCode.g && second == DetectorKeyCode.l) ||
        (first == DetectorKeyCode.g && second == DetectorKeyCode.r) ||
        (first == DetectorKeyCode.p && second == DetectorKeyCode.l) ||
        (first == DetectorKeyCode.p && second == DetectorKeyCode.r) ||
        (first == DetectorKeyCode.s && second == DetectorKeyCode.c) ||
        (first == DetectorKeyCode.s && second == DetectorKeyCode.k) ||
        (first == DetectorKeyCode.s && second == DetectorKeyCode.l) ||
        (first == DetectorKeyCode.s && second == DetectorKeyCode.m) ||
        (first == DetectorKeyCode.s && second == DetectorKeyCode.n) ||
        (first == DetectorKeyCode.s && second == DetectorKeyCode.p) ||
        (first == DetectorKeyCode.s && second == DetectorKeyCode.t) ||
        (first == DetectorKeyCode.s && second == DetectorKeyCode.w) ||
        (first == DetectorKeyCode.t && second == DetectorKeyCode.w) ||
        (first == DetectorKeyCode.w && second == DetectorKeyCode.r) {
        return true
    }

    if length >= 4 {
        let third = keyCodes[2]
        if first == DetectorKeyCode.t && second == DetectorKeyCode.h && third == DetectorKeyCode.r {
            return true
        }
    }

    return false
}

private func startsWithVietnameseConsonantOrVowel(
    keyCodes: [UInt8],
    length: Int
) -> Bool {
    guard length > 0 else {
        return false
    }

    let first = keyCodes[0]
    let second = length >= 3 ? keyCodes[1] : detectorInvalidIndex

    var isVietnameseConsonant = false

    if first == DetectorKeyCode.b || first == DetectorKeyCode.c || first == DetectorKeyCode.d ||
        first == DetectorKeyCode.g || first == DetectorKeyCode.h || first == DetectorKeyCode.k ||
        first == DetectorKeyCode.l || first == DetectorKeyCode.m || first == DetectorKeyCode.n ||
        first == DetectorKeyCode.p || first == DetectorKeyCode.r || first == DetectorKeyCode.s ||
        first == DetectorKeyCode.t || first == DetectorKeyCode.v || first == DetectorKeyCode.x {
        isVietnameseConsonant = true
    }

    if length >= 3 {
        if (first == DetectorKeyCode.c && second == DetectorKeyCode.h) ||
            (first == DetectorKeyCode.g && second == DetectorKeyCode.h) ||
            (first == DetectorKeyCode.g && second == DetectorKeyCode.i) ||
            (first == DetectorKeyCode.k && second == DetectorKeyCode.h) ||
            (first == DetectorKeyCode.n && second == DetectorKeyCode.g) ||
            (first == DetectorKeyCode.n && second == DetectorKeyCode.h) ||
            (first == DetectorKeyCode.p && second == DetectorKeyCode.h) ||
            (first == DetectorKeyCode.q && second == DetectorKeyCode.u) ||
            (first == DetectorKeyCode.t && second == DetectorKeyCode.h) ||
            (first == DetectorKeyCode.t && second == DetectorKeyCode.r) {
            isVietnameseConsonant = true
        }

        if length >= 4 {
            let third = keyCodes[2]
            if first == DetectorKeyCode.n && second == DetectorKeyCode.g && third == DetectorKeyCode.h {
                isVietnameseConsonant = true
            }
        }
    }

    let isVietnameseVowel = first == DetectorKeyCode.a || first == DetectorKeyCode.e ||
        first == DetectorKeyCode.i || first == DetectorKeyCode.o ||
        first == DetectorKeyCode.u || first == DetectorKeyCode.y ||
        first == DetectorKeyCode.w

    return isVietnameseConsonant || isVietnameseVowel
}

private func detectorShouldRestoreEnglish(
    keyStates: UnsafePointer<UInt32>,
    stateIndex: Int
) -> Bool {
    guard phtvDictionaryIsEnglishInitialized() != 0 else {
        return false
    }
    guard stateIndex >= 2, stateIndex <= detectorMaxWordLength else {
        return false
    }
    guard let decoded = decodeDetectorWord(keyStates: keyStates, length: stateIndex) else {
        return false
    }

    let idx = decoded.indices
    let keyCodes = decoded.keyCodes
    let cString = decoded.cString

    if detectorContainsCustomVietnamese(cString) {
        return false
    }

    if detectorContainsCustomEnglish(cString) {
        return true
    }

    if detectorContainsVietnamese(idx, length: stateIndex) {
        return false
    }

    if stateIndex >= 2 {
        let firstKey = keyCodes[0]
        let lastKey = keyCodes[stateIndex - 1]

        if isToneMarkKeyCode(lastKey: lastKey, firstKey: firstKey) {
            if !startsWithNonVietnameseKeyCluster(keyCodes: keyCodes, length: stateIndex) {
                if startsWithVietnameseConsonantOrVowel(keyCodes: keyCodes, length: stateIndex) &&
                    detectorContainsVietnamese(idx, length: stateIndex - 1) {
                    if stateIndex >= 4 && detectorContainsEnglish(idx, length: stateIndex) &&
                        startsWithNonVietnameseCluster(idx, length: stateIndex) {
                        return true
                    }
                    return false
                }
            }
        }
    }

    if hasLikelyVietnameseTelexAWCodaPattern(keyCodes: keyCodes, length: stateIndex) &&
        !startsWithNonVietnameseKeyCluster(keyCodes: keyCodes, length: stateIndex) &&
        startsWithVietnameseConsonantOrVowel(keyCodes: keyCodes, length: stateIndex) {
        return false
    }

    let isEnglish = detectorContainsEnglish(idx, length: stateIndex)

    if !isEnglish && detectorToneMarkInMiddle(idx, length: stateIndex) {
        let toneless = detectorTonelessIndices(idx, length: stateIndex)
        if toneless.count >= 2,
           toneless.count < 32,
           detectorContainsEnglish(toneless, length: toneless.count),
           !detectorContainsVietnamese(toneless, length: toneless.count) {
            return true
        }
    }

    if !isEnglish && hasDetectorTelexConflict(idx, length: stateIndex) {
        func tryDerivedReplacement(_ suffixFrom: [UInt8], _ suffixTo: [UInt8]) -> Bool {
            guard stateIndex > suffixFrom.count + 1 else {
                return false
            }
            guard detectorEndsWithSuffix(idx, length: stateIndex, suffix: suffixFrom) else {
                return false
            }

            let stemLength = stateIndex - suffixFrom.count
            let derivedLength = stemLength + suffixTo.count
            guard derivedLength >= 2, derivedLength < 32 else {
                return false
            }

            var derived: [UInt8] = [UInt8](repeating: 0, count: derivedLength)
            for i in 0..<stemLength {
                derived[i] = idx[i]
            }
            for i in 0..<suffixTo.count {
                derived[stemLength + i] = suffixTo[i]
            }

            guard detectorContainsEnglish(derived, length: derivedLength) else {
                return false
            }

            let derivedNonVietnameseStart = startsWithNonVietnameseCluster(derived, length: derivedLength)
            if !derivedNonVietnameseStart && detectorContainsVietnamese(derived, length: derivedLength) {
                return false
            }

            return true
        }

        if tryDerivedReplacement(derivationAbilitiesSuffix, derivationAbleSuffix) ||
            tryDerivedReplacement(derivationIbilitiesSuffix, derivationIbleSuffix) ||
            tryDerivedReplacement(derivationAbilitySuffix, derivationAbleSuffix) ||
            tryDerivedReplacement(derivationIbilitySuffix, derivationIbleSuffix) {
            return true
        }

        for suffix in englishSuffixFallbacks {
            guard stateIndex > suffix.count + 2 else {
                continue
            }
            guard detectorEndsWithSuffix(idx, length: stateIndex, suffix: suffix) else {
                continue
            }

            let baseLength = stateIndex - suffix.count
            let baseFoundInEnglish = detectorContainsEnglish(idx, length: baseLength)

            if baseFoundInEnglish {
                let baseNonVietnameseStart = startsWithNonVietnameseCluster(idx, length: baseLength)
                if baseNonVietnameseStart || !detectorContainsVietnamese(idx, length: baseLength) {
                    return true
                }
            } else if baseLength >= 2 {
                let tonelessBase = detectorTonelessIndices(idx, length: baseLength)
                if tonelessBase.count >= 2,
                   tonelessBase.count < 32,
                   detectorContainsEnglish(tonelessBase, length: tonelessBase.count) {
                    let baseNonVietnameseStart = startsWithNonVietnameseCluster(tonelessBase, length: tonelessBase.count)
                    if baseNonVietnameseStart ||
                        !detectorContainsVietnamese(tonelessBase, length: tonelessBase.count) {
                        return true
                    }
                }
            }
        }
    }

    return isEnglish
}

@_cdecl("phtvDetectorIsEnglishWordUtf8")
func phtvDetectorIsEnglishWordUtf8(_ wordCString: UnsafePointer<CChar>?) -> Int32 {
    guard phtvDictionaryIsEnglishInitialized() != 0,
          let wordCString,
          let indices = decodeDetectorAsciiWord(wordCString) else {
        return 0
    }

    return detectorContainsEnglish(indices, length: indices.count) ? 1 : 0
}

@_cdecl("phtvDetectorIsEnglishWordFromKeyStates")
func phtvDetectorIsEnglishWordFromKeyStates(
    _ keyStates: UnsafePointer<UInt32>?,
    _ stateIndex: Int32
) -> Int32 {
    let length = Int(stateIndex)
    guard let keyStates,
          length > 0,
          length <= detectorMaxWordLength else {
        return 0
    }

    guard phtvDictionaryIsEnglishInitialized() != 0 || phtvCustomDictionaryEnglishCount() > 0 else {
        return 0
    }

    guard let decoded = decodeDetectorWord(keyStates: keyStates, length: length) else {
        return 0
    }

    if detectorContainsCustomEnglish(decoded.cString) {
        return 1
    }

    return detectorContainsEnglish(decoded.indices, length: length) ? 1 : 0
}

@_cdecl("phtvDetectorIsVietnameseWordFromKeyStates")
func phtvDetectorIsVietnameseWordFromKeyStates(
    _ keyStates: UnsafePointer<UInt32>?,
    _ stateIndex: Int32
) -> Int32 {
    let length = Int(stateIndex)
    guard let keyStates,
          length > 0,
          length <= detectorMaxWordLength else {
        return 0
    }

    guard phtvDictionaryVietnameseWordCount() > 0 || phtvCustomDictionaryVietnameseCount() > 0 else {
        return 0
    }

    guard let decoded = decodeDetectorWord(keyStates: keyStates, length: length) else {
        return 0
    }

    if detectorContainsCustomVietnamese(decoded.cString) {
        return 1
    }

    return detectorContainsVietnamese(decoded.indices, length: length) ? 1 : 0
}

@_cdecl("phtvDetectorKeyStatesToAscii")
func phtvDetectorKeyStatesToAscii(
    _ keyStates: UnsafePointer<UInt32>?,
    _ count: Int32,
    _ outputBuffer: UnsafeMutablePointer<CChar>?,
    _ outputBufferSize: Int32
) -> Int32 {
    guard let keyStates else {
        if let outputBuffer, outputBufferSize > 0 {
            outputBuffer[0] = 0
        }
        return 0
    }

    let length = max(0, Int(count))
    var asciiChars: [CChar] = []
    asciiChars.reserveCapacity(length)

    for i in 0..<length {
        let keyCode = UInt8(keyStates[i] & detectorKeyMask)
        let keyCodeInt = Int(keyCode)
        guard keyCodeInt < detectorKeyCodeToIndex.count else {
            continue
        }

        let letterIndex = detectorKeyCodeToIndex[keyCodeInt]
        guard letterIndex < 26 else {
            continue
        }

        asciiChars.append(Int8(bitPattern: letterIndex &+ 97))
    }

    guard let outputBuffer, outputBufferSize > 0 else {
        return Int32(asciiChars.count)
    }

    let writableLength = max(0, Int(outputBufferSize) - 1)
    let copiedLength = min(writableLength, asciiChars.count)
    if copiedLength > 0 {
        for i in 0..<copiedLength {
            outputBuffer[i] = asciiChars[i]
        }
    }
    outputBuffer[copiedLength] = 0

    return Int32(copiedLength)
}

@_cdecl("phtvDetectorShouldRestoreEnglishWord")
func phtvDetectorShouldRestoreEnglishWord(
    _ keyStates: UnsafePointer<UInt32>?,
    _ stateIndex: Int32
) -> Int32 {
    guard let keyStates else {
        return 0
    }

    return detectorShouldRestoreEnglish(
        keyStates: keyStates,
        stateIndex: Int(stateIndex)
    ) ? 1 : 0
}
