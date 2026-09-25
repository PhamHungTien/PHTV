//
//  PHTVKeyboardEventTapConfiguration.swift
//  PHTV
//
//  Shared active keyboard event-tap configuration.
//

import CoreGraphics

enum PHTVKeyboardEventTapConfiguration {
    static let location: CGEventTapLocation = .cgSessionEventTap
    static let placement: CGEventTapPlacement = .headInsertEventTap
    static let options: CGEventTapOptions = .defaultTap
    static let eventMask = mask(for: [.keyDown, .keyUp, .flagsChanged])

    private static func mask(for eventTypes: [CGEventType]) -> CGEventMask {
        eventTypes.reduce(CGEventMask(0)) { mask, eventType in
            mask | (CGEventMask(1) << CGEventMask(eventType.rawValue))
        }
    }
}
