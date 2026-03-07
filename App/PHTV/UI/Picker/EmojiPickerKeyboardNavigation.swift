//
//  EmojiPickerKeyboardNavigation.swift
//  PHTV
//
//  Created by Codex on 2026.
//

import Foundation

enum EmojiPickerKeyboardFocus: Equatable {
    case search
    case grid(index: Int)
}

enum EmojiPickerKeyboardCommand {
    case enterGrid
    case moveNext
    case movePrevious
    case moveLeft
    case moveRight
    case moveUp
    case moveDown
    case activateSelection
}

enum EmojiPickerKeyboardAction: Equatable {
    case focus(EmojiPickerKeyboardFocus)
    case activate(index: Int)
    case noop
}

struct EmojiPickerKeyboardNavigator {
    let itemCount: Int
    let columnCount: Int

    func action(
        for command: EmojiPickerKeyboardCommand,
        from focus: EmojiPickerKeyboardFocus
    ) -> EmojiPickerKeyboardAction {
        guard itemCount > 0 else {
            if case .grid = focus {
                return .focus(.search)
            }
            return .noop
        }

        switch focus {
        case .search:
            switch command {
            case .enterGrid:
                return .focus(.grid(index: 0))
            default:
                return .noop
            }

        case .grid(let index):
            switch command {
            case .enterGrid:
                return .noop

            case .moveNext:
                return focusGrid(at: index + 1)

            case .movePrevious:
                if index == 0 {
                    return .focus(.search)
                }
                return focusGrid(at: index - 1)

            case .moveLeft:
                guard index > 0 else { return .noop }
                return focusGrid(at: index - 1)

            case .moveRight:
                return focusGrid(at: index + 1)

            case .moveUp:
                if index < columnCount {
                    return .focus(.search)
                }
                return focusGrid(at: index - columnCount)

            case .moveDown:
                let nextIndex = index + columnCount
                guard nextIndex < itemCount else { return .noop }
                return focusGrid(at: nextIndex)

            case .activateSelection:
                return .activate(index: index)
            }
        }
    }

    private func focusGrid(at index: Int) -> EmojiPickerKeyboardAction {
        guard (0..<itemCount).contains(index) else { return .noop }
        return .focus(.grid(index: index))
    }
}
