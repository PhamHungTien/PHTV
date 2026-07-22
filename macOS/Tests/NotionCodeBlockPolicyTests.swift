//
//  NotionCodeBlockPolicyTests.swift
//  PHTV
//
//  The Notion code-block fix swaps in a different output strategy (AX select +
//  type-over instead of backspaces). A stale "true" leaking into another app
//  applied that strategy inside Outlook, which swallowed the replacement text
//  and stripped the diacritics off every word after the first.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
@testable import PHTV

final class NotionCodeBlockPolicyTests: XCTestCase {

    // MARK: - The regression: a cached verdict must never cross apps

    func testCachedTrueNeverLeaksOutsideNotion() {
        // Typing in Outlook right after a Notion code block: the cache still
        // holds `true` and is only milliseconds old.
        let result = PHTVNotionCodeBlockPolicy.resolve(
            inNotionContext: false,
            axDetected: nil,
            cachedResult: true,
            cacheAgeMs: 10
        )
        XCTAssertFalse(result, "A code-block verdict must not survive leaving Notion")
    }

    func testOutsideNotionIsAlwaysFalseEvenWhenAXSaysOtherwise() {
        let result = PHTVNotionCodeBlockPolicy.resolve(
            inNotionContext: false,
            axDetected: true,
            cachedResult: true,
            cacheAgeMs: 0
        )
        XCTAssertFalse(result)
    }

    // MARK: - Inside Notion

    func testAXVerdictWinsInsideNotion() {
        XCTAssertTrue(
            PHTVNotionCodeBlockPolicy.resolve(
                inNotionContext: true, axDetected: true, cachedResult: false, cacheAgeMs: nil
            )
        )
        XCTAssertFalse(
            PHTVNotionCodeBlockPolicy.resolve(
                inNotionContext: true, axDetected: false, cachedResult: true, cacheAgeMs: 10
            ),
            "A fresh AX verdict must override the cache"
        )
    }

    func testTransientAXFailureInsideNotionKeepsRecentVerdict() {
        // Accessibility momentarily fails mid-word while still in the code block.
        let result = PHTVNotionCodeBlockPolicy.resolve(
            inNotionContext: true,
            axDetected: nil,
            cachedResult: true,
            cacheAgeMs: 100
        )
        XCTAssertTrue(result, "Must not flip-flop mid-word on a transient AX failure")
    }

    func testStaleCacheInsideNotionExpires() {
        let result = PHTVNotionCodeBlockPolicy.resolve(
            inNotionContext: true,
            axDetected: nil,
            cachedResult: true,
            cacheAgeMs: PHTVNotionCodeBlockPolicy.staleFallbackMs + 1
        )
        XCTAssertFalse(result)
    }

    func testNoCacheAndNoAXAnswerIsFalse() {
        let result = PHTVNotionCodeBlockPolicy.resolve(
            inNotionContext: true,
            axDetected: nil,
            cachedResult: false,
            cacheAgeMs: nil
        )
        XCTAssertFalse(result)
    }

    // MARK: - Non-Notion apps never even ask accessibility

    func testOutlookIsNotTreatedAsNotionCapable() {
        // Guards the cheap bundle-id gate that keeps the AX tree walk (and the
        // whole code-block strategy) away from ordinary editors.
        XCTAssertFalse(PHTVAppDetectionService.isNotionApp("com.microsoft.Outlook"))
        XCTAssertFalse(PHTVAppDetectionService.isBrowserApp("com.microsoft.Outlook"))
    }

    // MARK: - Firefox accessibility evidence

    func testNotionWorkspaceURLRecognizesFullAndSchemelessURLs() {
        for value in [
            "https://www.notion.so/workspace/page-id",
            "https://team.notion.site/public-page",
            "notion.so/workspace/page-id"
        ] {
            XCTAssertTrue(
                PHTVNotionCodeBlockEvidence.isNotionWorkspaceURL(value),
                value
            )
        }
    }

    func testNotionWorkspaceURLRejectsLookalikes() {
        for value in [
            "https://notion.so.evil.example/page",
            "https://example.com/?next=https://notion.so/page",
            "Notion — project notes"
        ] {
            XCTAssertFalse(
                PHTVNotionCodeBlockEvidence.isNotionWorkspaceURL(value),
                value
            )
        }
    }

    func testCodeBlockAttributesRequireSemanticEvidence() {
        for value in ["Code", "notion-code-block-123", "Copy source code", "pre code editor"] {
            XCTAssertTrue(
                PHTVNotionCodeBlockEvidence.attributeIndicatesCodeBlock(value),
                value
            )
        }

        for value in ["Visual Studio Code", "decodeResult", "Project editor"] {
            XCTAssertFalse(
                PHTVNotionCodeBlockEvidence.attributeIndicatesCodeBlock(value),
                value
            )
        }
    }

    func testMonospacedFontIsSecondaryCodeBlockEvidence() {
        XCTAssertTrue(
            PHTVNotionCodeBlockEvidence.fontIndicatesCodeBlock(
                name: "SFMono-Regular",
                family: "SF Mono"
            )
        )
        XCTAssertTrue(
            PHTVNotionCodeBlockEvidence.fontIndicatesCodeBlock(
                name: "iawriter-mono",
                family: nil
            )
        )
        XCTAssertFalse(
            PHTVNotionCodeBlockEvidence.fontIndicatesCodeBlock(
                name: "Inter-Regular",
                family: "Inter"
            )
        )
    }
}
