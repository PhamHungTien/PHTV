//
//  PHTVDictionaryTrieBridge.swift
//  PHTV
//
//  Swift runtime storage for built-in English/Vietnamese binary trie dictionaries.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

private let dictionaryTrieLock = NSLock()

private let trieHeaderSize = 12

// PHT4 (legacy): fixed 79-byte nodes — 26 three-byte child pointers + isEnd.
private let trieNodeSize = 79
private let trieChildStride = 3
private let trieNodeIsEndOffset = 78
private let trieNoChild: UInt32 = 0xFFFFFF

// PHT5 (sparse): per node a 32-bit header (bits 0-25 child-presence bitmap,
// bit 26 = end-of-word) followed by one 32-bit section-relative byte offset
// per present child in ascending letter order. ~10x smaller on disk.
private let trieIsEndBit: UInt32 = 1 << 26

private enum BinaryTrieFormat {
    case pht4
    case pht5
}

private struct BinaryTrieRuntimeState {
    let data: Data
    let format: BinaryTrieFormat
    let nodeCount: Int
    let wordCount: Int32
}

private final class DictionaryTrieStateBox: @unchecked Sendable {
    var englishTrieState: BinaryTrieRuntimeState?
    var vietnameseTrieState: BinaryTrieRuntimeState?
}

private let dictionaryTrieState = DictionaryTrieStateBox()

private func readUInt32LittleEndian(
    _ bytes: UnsafePointer<UInt8>,
    offset: Int
) -> UInt32 {
    let b0 = UInt32(bytes[offset])
    let b1 = UInt32(bytes[offset + 1]) << 8
    let b2 = UInt32(bytes[offset + 2]) << 16
    let b3 = UInt32(bytes[offset + 3]) << 24
    return b0 | b1 | b2 | b3
}

private func readUInt24LittleEndian(
    _ bytes: UnsafePointer<UInt8>,
    offset: Int
) -> UInt32 {
    let b0 = UInt32(bytes[offset])
    let b1 = UInt32(bytes[offset + 1]) << 8
    let b2 = UInt32(bytes[offset + 2]) << 16
    return b0 | b1 | b2
}

private func dictionaryCandidatePaths(for sourcePath: String) -> [String] {
    let sourceURL = URL(fileURLWithPath: sourcePath)
    let ext = sourceURL.pathExtension

    var candidates: [String] = []
    if ext.isEmpty {
        candidates.append(sourcePath + ".bin")
    } else {
        let basePath = sourceURL.deletingPathExtension().path
        candidates.append(basePath + ".bin")

        if basePath.hasSuffix("_words") {
            let prefix = String(basePath.dropLast(6))
            candidates.append(prefix + "_dict.bin")
        }
    }

    var seen: Set<String> = []
    var uniqueCandidates: [String] = []
    uniqueCandidates.reserveCapacity(candidates.count)
    for path in candidates {
        guard !seen.contains(path) else {
            continue
        }
        seen.insert(path)
        uniqueCandidates.append(path)
    }
    return uniqueCandidates
}

private func loadTrieRuntimeState(fromPath path: String) -> BinaryTrieRuntimeState? {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedIfSafe]) else {
        return nil
    }
    guard data.count >= trieHeaderSize else {
        return nil
    }

    return data.withUnsafeBytes { rawBuffer in
        guard let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
            return nil
        }

        guard baseAddress[0] == 0x50,   // P
              baseAddress[1] == 0x48,   // H
              baseAddress[2] == 0x54 else { // T
            return nil
        }

        let format: BinaryTrieFormat
        switch baseAddress[3] {
        case 0x34: format = .pht4
        case 0x35: format = .pht5
        default: return nil
        }

        let nodeCountRaw = readUInt32LittleEndian(baseAddress, offset: 4)
        let wordCountRaw = readUInt32LittleEndian(baseAddress, offset: 8)

        let nodeCount = Int(nodeCountRaw)
        guard nodeCount > 0 else {
            return nil
        }

        switch format {
        case .pht4:
            guard nodeCount <= (Int.max - trieHeaderSize) / trieNodeSize else {
                return nil
            }
            let expectedSize = trieHeaderSize + nodeCount * trieNodeSize
            guard data.count >= expectedSize else {
                return nil
            }
        case .pht5:
            // Nodes are variable-size; the minimum is one header word each.
            guard data.count >= trieHeaderSize + nodeCount * 4 else {
                return nil
            }
        }

        return BinaryTrieRuntimeState(
            data: data,
            format: format,
            nodeCount: nodeCount,
            wordCount: Int32(clamping: Int(wordCountRaw))
        )
    }
}

private func loadTrieRuntimeState(fromSourcePath sourcePath: String) -> BinaryTrieRuntimeState? {
    for candidatePath in dictionaryCandidatePaths(for: sourcePath) {
        if let state = loadTrieRuntimeState(fromPath: candidatePath) {
            return state
        }
    }
    return nil
}

private func trieContains(
    _ state: BinaryTrieRuntimeState?,
    indices: UnsafePointer<UInt8>?,
    length: Int32
) -> Bool {
    guard let state,
          let indices,
          length > 0,
          length <= 30 else {
        return false
    }

    return state.data.withUnsafeBytes { rawBuffer in
        guard let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
            return false
        }

        switch state.format {
        case .pht4:
            return pht4Contains(state: state, baseAddress: baseAddress, indices: indices, length: Int(length))
        case .pht5:
            return pht5Contains(state: state, baseAddress: baseAddress, indices: indices, length: Int(length))
        }
    }
}

private func pht4Contains(
    state: BinaryTrieRuntimeState,
    baseAddress: UnsafePointer<UInt8>,
    indices: UnsafePointer<UInt8>,
    length: Int
) -> Bool {
    var nodeIndex: UInt32 = 0
    for i in 0..<length {
        let letter = indices[i]
        guard letter < 26 else {
            return false
        }

        let nodeOffset = trieHeaderSize + Int(nodeIndex) * trieNodeSize
        let childOffset = nodeOffset + Int(letter) * trieChildStride
        guard childOffset + trieChildStride <= state.data.count else {
            return false
        }

        let child = readUInt24LittleEndian(baseAddress, offset: childOffset)
        if child == trieNoChild {
            return false
        }
        guard Int(child) < state.nodeCount else {
            return false
        }

        nodeIndex = child
    }

    let isEndOffset = trieHeaderSize + Int(nodeIndex) * trieNodeSize + trieNodeIsEndOffset
    guard isEndOffset < state.data.count else {
        return false
    }

    return baseAddress[isEndOffset] != 0
}

private func pht5Contains(
    state: BinaryTrieRuntimeState,
    baseAddress: UnsafePointer<UInt8>,
    indices: UnsafePointer<UInt8>,
    length: Int
) -> Bool {
    let sectionSize = state.data.count - trieHeaderSize
    var nodeOffset = 0
    var header: UInt32 = 0

    for i in 0...length {
        guard nodeOffset >= 0, nodeOffset + 4 <= sectionSize else {
            return false
        }
        header = readUInt32LittleEndian(baseAddress, offset: trieHeaderSize + nodeOffset)

        guard i < length else { break }

        let letter = indices[i]
        guard letter < 26 else {
            return false
        }

        let letterBit = UInt32(1) << UInt32(letter)
        guard header & letterBit != 0 else {
            return false
        }

        // Child slot = number of present children for letters below this one.
        let slot = (header & (letterBit - 1)).nonzeroBitCount
        let childFieldOffset = nodeOffset + 4 + slot * 4
        guard childFieldOffset + 4 <= sectionSize else {
            return false
        }

        nodeOffset = Int(readUInt32LittleEndian(baseAddress, offset: trieHeaderSize + childFieldOffset))
    }

    return header & trieIsEndBit != 0
}

@_cdecl("phtvDictionaryInitEnglish")
func phtvDictionaryInitEnglish(_ filePath: UnsafePointer<CChar>?) -> Int32 {
    guard let filePath else {
        return 0
    }

    dictionaryTrieLock.lock()
    let alreadyLoaded = dictionaryTrieState.englishTrieState != nil
    dictionaryTrieLock.unlock()
    if alreadyLoaded {
        return 1
    }

    guard let loadedState = loadTrieRuntimeState(fromSourcePath: String(cString: filePath)) else {
        return 0
    }

    dictionaryTrieLock.lock()
    if dictionaryTrieState.englishTrieState == nil {
        dictionaryTrieState.englishTrieState = loadedState
    }
    dictionaryTrieLock.unlock()

    return 1
}

@_cdecl("phtvDictionaryInitVietnamese")
func phtvDictionaryInitVietnamese(_ filePath: UnsafePointer<CChar>?) -> Int32 {
    guard let filePath else {
        return 0
    }

    dictionaryTrieLock.lock()
    let alreadyLoaded = dictionaryTrieState.vietnameseTrieState != nil
    dictionaryTrieLock.unlock()
    if alreadyLoaded {
        return 1
    }

    guard let loadedState = loadTrieRuntimeState(fromSourcePath: String(cString: filePath)) else {
        return 0
    }

    dictionaryTrieLock.lock()
    if dictionaryTrieState.vietnameseTrieState == nil {
        dictionaryTrieState.vietnameseTrieState = loadedState
    }
    dictionaryTrieLock.unlock()

    return 1
}

@_cdecl("phtvDictionaryIsEnglishInitialized")
func phtvDictionaryIsEnglishInitialized() -> Int32 {
    dictionaryTrieLock.lock()
    let initialized = dictionaryTrieState.englishTrieState != nil
    dictionaryTrieLock.unlock()
    return initialized ? 1 : 0
}

@_cdecl("phtvDictionaryEnglishWordCount")
func phtvDictionaryEnglishWordCount() -> Int32 {
    dictionaryTrieLock.lock()
    let count = dictionaryTrieState.englishTrieState?.wordCount ?? 0
    dictionaryTrieLock.unlock()
    return count
}

@_cdecl("phtvDictionaryVietnameseWordCount")
func phtvDictionaryVietnameseWordCount() -> Int32 {
    dictionaryTrieLock.lock()
    let count = dictionaryTrieState.vietnameseTrieState?.wordCount ?? 0
    dictionaryTrieLock.unlock()
    return count
}

@_cdecl("phtvDictionaryContainsEnglishIndices")
func phtvDictionaryContainsEnglishIndices(
    _ indices: UnsafePointer<UInt8>?,
    _ length: Int32
) -> Int32 {
    dictionaryTrieLock.lock()
    let state = dictionaryTrieState.englishTrieState
    dictionaryTrieLock.unlock()
    return trieContains(state, indices: indices, length: length) ? 1 : 0
}

@_cdecl("phtvDictionaryContainsVietnameseIndices")
func phtvDictionaryContainsVietnameseIndices(
    _ indices: UnsafePointer<UInt8>?,
    _ length: Int32
) -> Int32 {
    dictionaryTrieLock.lock()
    let state = dictionaryTrieState.vietnameseTrieState
    dictionaryTrieLock.unlock()
    return trieContains(state, indices: indices, length: length) ? 1 : 0
}

@_cdecl("phtvDictionaryClear")
func phtvDictionaryClear() {
    dictionaryTrieLock.lock()
    dictionaryTrieState.englishTrieState = nil
    dictionaryTrieState.vietnameseTrieState = nil
    dictionaryTrieLock.unlock()
}
