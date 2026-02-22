//
//  PHTVDictionaryTrieBridge.swift
//  PHTV
//
//  Swift runtime storage for built-in English/Vietnamese binary trie dictionaries.
//

import Foundation

private let dictionaryTrieLock = NSLock()

private let trieHeaderSize = 12
private let trieNodeSize = 105
private let trieChildStride = 4
private let trieNodeIsEndOffset = 104
private let trieNoChild = UInt32.max

private struct BinaryTrieRuntimeState {
    let data: Data
    let nodeCount: Int
    let wordCount: Int32
}

nonisolated(unsafe) private var englishTrieState: BinaryTrieRuntimeState?
nonisolated(unsafe) private var vietnameseTrieState: BinaryTrieRuntimeState?

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

        guard baseAddress[0] == 0x50,
              baseAddress[1] == 0x48,
              baseAddress[2] == 0x54,
              baseAddress[3] == 0x33 else {
            return nil
        }

        let nodeCountRaw = readUInt32LittleEndian(baseAddress, offset: 4)
        let wordCountRaw = readUInt32LittleEndian(baseAddress, offset: 8)

        let nodeCount = Int(nodeCountRaw)
        guard nodeCount > 0 else {
            return nil
        }
        guard nodeCount <= (Int.max - trieHeaderSize) / trieNodeSize else {
            return nil
        }

        let expectedSize = trieHeaderSize + nodeCount * trieNodeSize
        guard data.count >= expectedSize else {
            return nil
        }

        return BinaryTrieRuntimeState(
            data: data,
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

        var nodeIndex: UInt32 = 0
        for i in 0..<Int(length) {
            let letter = indices[i]
            guard letter < 26 else {
                return false
            }

            let nodeOffset = trieHeaderSize + Int(nodeIndex) * trieNodeSize
            let childOffset = nodeOffset + Int(letter) * trieChildStride
            guard childOffset + trieChildStride <= state.data.count else {
                return false
            }

            let child = readUInt32LittleEndian(baseAddress, offset: childOffset)
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
}

@_cdecl("phtvDictionaryInitEnglish")
func phtvDictionaryInitEnglish(_ filePath: UnsafePointer<CChar>?) -> Int32 {
    guard let filePath else {
        return 0
    }

    dictionaryTrieLock.lock()
    let alreadyLoaded = englishTrieState != nil
    dictionaryTrieLock.unlock()
    if alreadyLoaded {
        return 1
    }

    guard let loadedState = loadTrieRuntimeState(fromSourcePath: String(cString: filePath)) else {
        return 0
    }

    dictionaryTrieLock.lock()
    if englishTrieState == nil {
        englishTrieState = loadedState
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
    let alreadyLoaded = vietnameseTrieState != nil
    dictionaryTrieLock.unlock()
    if alreadyLoaded {
        return 1
    }

    guard let loadedState = loadTrieRuntimeState(fromSourcePath: String(cString: filePath)) else {
        return 0
    }

    dictionaryTrieLock.lock()
    if vietnameseTrieState == nil {
        vietnameseTrieState = loadedState
    }
    dictionaryTrieLock.unlock()

    return 1
}

@_cdecl("phtvDictionaryIsEnglishInitialized")
func phtvDictionaryIsEnglishInitialized() -> Int32 {
    dictionaryTrieLock.lock()
    let initialized = englishTrieState != nil
    dictionaryTrieLock.unlock()
    return initialized ? 1 : 0
}

@_cdecl("phtvDictionaryEnglishWordCount")
func phtvDictionaryEnglishWordCount() -> Int32 {
    dictionaryTrieLock.lock()
    let count = englishTrieState?.wordCount ?? 0
    dictionaryTrieLock.unlock()
    return count
}

@_cdecl("phtvDictionaryVietnameseWordCount")
func phtvDictionaryVietnameseWordCount() -> Int32 {
    dictionaryTrieLock.lock()
    let count = vietnameseTrieState?.wordCount ?? 0
    dictionaryTrieLock.unlock()
    return count
}

@_cdecl("phtvDictionaryContainsEnglishIndices")
func phtvDictionaryContainsEnglishIndices(
    _ indices: UnsafePointer<UInt8>?,
    _ length: Int32
) -> Int32 {
    dictionaryTrieLock.lock()
    let state = englishTrieState
    dictionaryTrieLock.unlock()
    return trieContains(state, indices: indices, length: length) ? 1 : 0
}

@_cdecl("phtvDictionaryContainsVietnameseIndices")
func phtvDictionaryContainsVietnameseIndices(
    _ indices: UnsafePointer<UInt8>?,
    _ length: Int32
) -> Int32 {
    dictionaryTrieLock.lock()
    let state = vietnameseTrieState
    dictionaryTrieLock.unlock()
    return trieContains(state, indices: indices, length: length) ? 1 : 0
}

@_cdecl("phtvDictionaryClear")
func phtvDictionaryClear() {
    dictionaryTrieLock.lock()
    englishTrieState = nil
    vietnameseTrieState = nil
    dictionaryTrieLock.unlock()
}
