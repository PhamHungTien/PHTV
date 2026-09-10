//
//  PHTVTextOutputEncoder.swift
//  PHTV
//
//  Pure packed-character decoding and bounded Unicode output planning.
//

import Foundation

enum PHTVTextOutputEncoder {
    /// One engine item can emit two UTF-16 units. Keep its source position and
    /// sync-key length separate from its encoded size (notably for VNI/NFD).
    struct Item {
        let first: UInt16
        let second: UInt16?
        let syncKeyLength: Int32?

        var count: Int { second == nil ? 1 : 2 }

        func append(to units: inout [UInt16]) {
            units.append(first)
            if let second { units.append(second) }
        }
    }

    struct Chunk {
        let units: [UInt16]
        let syncKeyLengths: [Int32]
        let nextSourceOffset: Int
    }

    static func scalar(_ value: UInt32, syncKeyLength: Int32? = nil) -> Item? {
        guard UnicodeScalar(value) != nil else { return nil }
        if value <= UInt32(UInt16.max) {
            return Item(first: UInt16(value), second: nil, syncKeyLength: syncKeyLength)
        }
        let supplementary = value - 0x10000
        return Item(
            first: UInt16(0xD800 + (supplementary >> 10)),
            second: UInt16(0xDC00 + (supplementary & 0x3FF)),
            syncKeyLength: syncKeyLength
        )
    }

    static func item(_ data: UInt32, codeTable: Int32) -> Item? {
        let tracksSyncKeys = EngineInputClassification.isDoubleCodeTable(codeTable)
        if (data & EngineBitMask.pureCharacter) != 0 {
            // The engine stores a full Unicode scalar, not a truncated UInt16.
            // It is still one logical key for backspace accounting.
            return scalar(data & ~EngineBitMask.pureCharacter, syncKeyLength: tracksSyncKeys ? 1 : nil)
        }
        if (data & EngineBitMask.charCode) == 0 {
            return Item(
                first: EngineMacroKeyMap.character(for: data),
                second: nil,
                syncKeyLength: tracksSyncKeys ? 1 : nil
            )
        }
        switch codeTable {
        case 0:
            return Item(first: UInt16(truncatingIfNeeded: data), second: nil, syncKeyLength: nil)
        case 1, 2, 4:
            let high = EnginePackedData.highByte(data)
            let second = high > 32 ? high : nil
            return Item(
                first: EnginePackedData.lowByte(data),
                second: second,
                syncKeyLength: codeTable == 2 ? (second == nil ? 1 : 2) : nil
            )
        case 3:
            let packed = UInt16(truncatingIfNeeded: data)
            let markIndex = packed >> 13
            return Item(
                first: packed & 0x1FFF,
                second: markIndex > 0 ? EnginePackedData.unicodeCompoundMark(at: Int32(markIndex) - 1) : nil,
                syncKeyLength: markIndex > 0 ? 2 : 1
            )
        default:
            return nil
        }
    }

    static func nextChunk(
        from items: [UInt32],
        sourceCount: Int,
        sourceOffset: Int,
        reversed: Bool,
        codeTable: Int32,
        maximumUTF16Count: Int = 16
    ) -> Chunk {
        let count = max(0, min(sourceCount, items.count))
        var cursor = max(0, min(sourceOffset, count))
        let limit = max(1, maximumUTF16Count)
        var units: [UInt16] = []
        var syncKeyLengths: [Int32] = []
        units.reserveCapacity(min(limit, 32))
        if EngineInputClassification.isDoubleCodeTable(codeTable) {
            syncKeyLengths.reserveCapacity(min(limit, 32))
        }

        while cursor < count {
            let sourceIndex = reversed ? count - 1 - cursor : cursor
            guard let encoded = item(items[sourceIndex], codeTable: codeTable) else {
                cursor += 1
                continue
            }
            // Do not consume an item until all its units fit. If a caller asks
            // for a one-unit chunk, emit a two-unit item whole to make progress.
            if !units.isEmpty && encoded.count > limit - units.count { break }
            encoded.append(to: &units)
            if let length = encoded.syncKeyLength { syncKeyLengths.append(length) }
            cursor += 1
            if units.count >= limit { break }
        }
        return Chunk(units: units, syncKeyLengths: syncKeyLengths, nextSourceOffset: cursor)
    }

    /// The transport may impose a smaller chunk size (e.g. CLI pacing) after
    /// decoding. Extend a boundary by one unit rather than split a surrogate.
    static func unicodeChunkLength(
        in units: UnsafeBufferPointer<UInt16>,
        offset: Int,
        maximumCount: Int
    ) -> Int {
        guard offset >= 0, offset < units.count else { return 0 }
        var count = min(max(1, maximumCount), units.count - offset)
        let end = offset + count
        if end < units.count,
           (0xD800...0xDBFF).contains(units[end - 1]),
           (0xDC00...0xDFFF).contains(units[end]) {
            count += 1
        }
        return count
    }
}
