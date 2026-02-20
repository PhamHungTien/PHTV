//
//  PHTVAccessibilityService.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

@objcMembers
final class PHTVAccessibilityService: NSObject {
    @objc(stringEqualCanonicalForAX:rhs:)
    class func stringEqualCanonicalForAX(_ lhs: String?, rhs: String?) -> Bool {
        if lhs == rhs {
            return true
        }
        guard let lhs, let rhs else {
            return false
        }
        if lhs == rhs {
            return true
        }
        if lhs.precomposedStringWithCanonicalMapping == rhs.precomposedStringWithCanonicalMapping {
            return true
        }
        return lhs.decomposedStringWithCanonicalMapping == rhs.decomposedStringWithCanonicalMapping
    }

    @objc(stringHasCanonicalPrefixForAX:prefix:)
    class func stringHasCanonicalPrefixForAX(_ value: String?, prefix: String?) -> Bool {
        guard let value, let prefix else {
            return false
        }
        if value.hasPrefix(prefix) {
            return true
        }
        if value.precomposedStringWithCanonicalMapping.hasPrefix(prefix.precomposedStringWithCanonicalMapping) {
            return true
        }
        return value.decomposedStringWithCanonicalMapping.hasPrefix(prefix.decomposedStringWithCanonicalMapping)
    }

    @objc(calculateDeleteStartForAX:caretLocation:backspaceCount:)
    class func calculateDeleteStartForAX(_ value: String?, caretLocation: Int, backspaceCount: Int) -> Int {
        guard let value else {
            return max(0, caretLocation)
        }
        if backspaceCount <= 0 {
            return caretLocation
        }

        let valueNSString = value as NSString
        var start = caretLocation - backspaceCount
        if start < 0 {
            start = 0
        }

        if start < caretLocation && caretLocation <= valueNSString.length {
            let textToDelete = valueNSString.substring(with: NSRange(location: start, length: caretLocation - start))
            let composedLen = (textToDelete.precomposedStringWithCanonicalMapping as NSString).length
            if composedLen != backspaceCount && composedLen > 0 {
                var actualStart = caretLocation
                var composedCount = 0
                while actualStart > 0 && composedCount < backspaceCount {
                    actualStart -= 1
                    let c = valueNSString.character(at: actualStart)
                    if !isCombiningMark(c) {
                        composedCount += 1
                    }
                }
                start = actualStart
            }
        }

        return start
    }

    private class func isCombiningMark(_ scalar: unichar) -> Bool {
        (scalar >= 0x0300 && scalar <= 0x036F) ||
        (scalar >= 0x1DC0 && scalar <= 0x1DFF) ||
        (scalar >= 0x20D0 && scalar <= 0x20FF) ||
        (scalar >= 0xFE20 && scalar <= 0xFE2F)
    }
}
