//
//  PHTVSmartSwitchRuntimeService.swift
//  PHTV
//
//  Runtime helpers for Smart Switch state transitions and persistence.
//  Swift-native replacement for the old C++ SmartSwitch bridge.
//

import Foundation

@objcMembers
final class PHTVSmartSwitchRuntimeService: NSObject {
    private static let notFound = Int32(-1)
    private static let languageMask: Int32 = 0x01
    private static let codeTableShift: Int32 = 1
    private static let maxEntryCount = Int(UInt16.max)
    private static let maxBundleIdBytes = Int(UInt8.max)

    private static let queue = DispatchQueue(label: "com.phamhungtien.phtv.smartswitch.runtime")

    nonisolated(unsafe) private static var isLoaded = false
    nonisolated(unsafe) private static var stateByBundleId: [String: Int8] = [:]
    nonisolated(unsafe) private static var cacheBundleId = ""
    nonisolated(unsafe) private static var cacheState: Int8 = 0

    @objc class func appState(
        forBundleId bundleId: String,
        defaultLanguage: Int32,
        defaultCodeTable: Int32
    ) -> Int32 {
        guard !bundleId.isEmpty else {
            return notFound
        }

        let defaultState = encodeState(inputMethod: defaultLanguage, codeTable: defaultCodeTable)
        return queue.sync {
            ensureLoadedLocked()

            if cacheBundleId == bundleId {
                return Int32(cacheState)
            }

            if let existing = stateByBundleId[bundleId] {
                cacheBundleId = bundleId
                cacheState = existing
                return Int32(existing)
            }

            let clampedDefault = clampToInt8(defaultState)
            stateByBundleId[bundleId] = clampedDefault
            cacheBundleId = bundleId
            cacheState = clampedDefault
            return notFound
        }
    }

    @objc class func isNotFoundState(_ state: Int32) -> Bool {
        state == notFound
    }

    @objc class func decodedLanguage(fromState state: Int32) -> Int32 {
        decodeInputMethod(from: state)
    }

    @objc class func decodedCodeTable(fromState state: Int32) -> Int32 {
        decodeCodeTable(from: state)
    }

    @objc class func updateAppState(
        forBundleId bundleId: String,
        language: Int32,
        codeTable: Int32
    ) {
        guard !bundleId.isEmpty else {
            return
        }

        let encodedState = clampToInt8(encodeState(inputMethod: language, codeTable: codeTable))
        queue.sync {
            ensureLoadedLocked()
            stateByBundleId[bundleId] = encodedState
            cacheBundleId = bundleId
            cacheState = encodedState
        }
    }

    @objc class func persistSnapshot() {
        let data = queue.sync {
            ensureLoadedLocked()
            return serializedDataLocked()
        }
        PHTVSmartSwitchPersistenceService.saveSmartSwitchData(data)
    }

    @objc class func loadFromPersistedData() {
        queue.sync {
            loadFromUserDefaultsLocked(force: true)
        }
    }
}

private extension PHTVSmartSwitchRuntimeService {
    static func encodeState(inputMethod: Int32, codeTable: Int32) -> Int32 {
        (inputMethod & languageMask) | (codeTable << codeTableShift)
    }

    static func decodeInputMethod(from state: Int32) -> Int32 {
        state & languageMask
    }

    static func decodeCodeTable(from state: Int32) -> Int32 {
        state >> codeTableShift
    }

    static func clampToInt8(_ value: Int32) -> Int8 {
        if value < Int32(Int8.min) {
            return Int8.min
        }
        if value > Int32(Int8.max) {
            return Int8.max
        }
        return Int8(value)
    }

    static func ensureLoadedLocked() {
        if isLoaded {
            return
        }
        loadFromUserDefaultsLocked(force: false)
    }

    static func loadFromUserDefaultsLocked(force: Bool) {
        if isLoaded && !force {
            return
        }

        isLoaded = true
        stateByBundleId.removeAll(keepingCapacity: false)
        cacheBundleId.removeAll(keepingCapacity: false)
        cacheState = 0

        guard let data = UserDefaults.standard.data(forKey: "smartSwitchKey"), data.count >= 2 else {
            return
        }

        let bytes = Array(data)
        let entryCount = Int(UInt16(bytes[0]) | (UInt16(bytes[1]) << 8))
        var cursor = 2

        for _ in 0..<entryCount {
            if cursor >= bytes.count {
                break
            }

            let bundleLength = Int(bytes[cursor])
            cursor += 1

            if cursor + bundleLength + 1 > bytes.count {
                break
            }

            let bundleSlice = bytes[cursor..<(cursor + bundleLength)]
            let bundleId = String(decoding: bundleSlice, as: UTF8.self)
            cursor += bundleLength

            let state = Int8(bitPattern: bytes[cursor])
            cursor += 1

            if !bundleId.isEmpty {
                stateByBundleId[bundleId] = state
            }
        }
    }

    static func serializedDataLocked() -> Data {
        let sortedEntries = stateByBundleId
            .filter { !$0.key.isEmpty && $0.key.utf8.count <= maxBundleIdBytes }
            .sorted { $0.key < $1.key }
            .prefix(maxEntryCount)

        let count = UInt16(sortedEntries.count)
        var output = Data()
        output.reserveCapacity(2 + sortedEntries.reduce(0) { $0 + 1 + $1.key.utf8.count + 1 })

        output.append(UInt8(count & 0x00FF))
        output.append(UInt8((count >> 8) & 0x00FF))

        for (bundleId, state) in sortedEntries {
            let utf8 = Array(bundleId.utf8)
            output.append(UInt8(utf8.count))
            output.append(contentsOf: utf8)
            output.append(UInt8(bitPattern: state))
        }

        return output
    }
}
