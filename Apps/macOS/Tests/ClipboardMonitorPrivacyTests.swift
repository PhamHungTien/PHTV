//
//  ClipboardMonitorPrivacyTests.swift
//  PHTV
//
//  Clipboard fixtures use private named pasteboards and injected workers only.
//  No test accesses the general pasteboard, preferences, or history cache.
//

import AppKit
import XCTest
@testable import PHTV

final class ClipboardMonitorPrivacyTests: XCTestCase {
    @MainActor
    func testConfidentialAndTransientMarkersRejectBeforeReadingPromisedText() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }

        // NSPasteboardItem accepts UTIs only. The legacy Typinator marker is
        // tested below through the older declareTypes API used by its producer.
        for marker in ClipboardHistoryPrivacyPolicy.excludedPasteboardTypes.sorted()
            where marker != "Pasteboard generator type" {
            let provider = ClipboardTestTextProvider()
            let item = NSPasteboardItem()
            item.setDataProvider(provider, forTypes: [.string])
            item.setData(Data(), forType: NSPasteboard.PasteboardType(marker))
            pasteboard.clearContents()
            XCTAssertTrue(pasteboard.writeObjects([item]))

            XCTAssertNil(read(pasteboard), marker)
            XCTAssertEqual(provider.readCount, 0, marker)
        }
    }

    @MainActor
    func testLegacyTransientMarkerUsesTheLegacyPasteboardAPI() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let marker = NSPasteboard.PasteboardType("Pasteboard generator type")
        pasteboard.declareTypes([marker, .string], owner: nil)
        XCTAssertTrue(pasteboard.setData(Data(), forType: marker))
        XCTAssertTrue(pasteboard.setString("legacy fixture", forType: .string))
        XCTAssertNil(read(pasteboard))
    }

    @MainActor
    func testMarkerOnAnotherPasteboardItemStillPreventsCapture() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let provider = ClipboardTestTextProvider()
        let textItem = NSPasteboardItem()
        textItem.setDataProvider(provider, forTypes: [.string])
        let markedItem = NSPasteboardItem()
        markedItem.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        XCTAssertTrue(pasteboard.writeObjects([textItem, markedItem]))

        XCTAssertNil(read(pasteboard))
        XCTAssertEqual(provider.readCount, 0)
    }

    @MainActor
    func testDeclaredPasswordManagerSourceIsExcludedWhileBrowserIsFrontmost() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let provider = ClipboardTestTextProvider()
        let item = NSPasteboardItem()
        item.setDataProvider(provider, forTypes: [.string])
        item.setString("org.keepassxc.keepassxc", forType: ClipboardHistoryPrivacyPolicy.sourceType)
        XCTAssertTrue(pasteboard.writeObjects([item]))

        XCTAssertNil(read(pasteboard, sourceApp: "com.google.Chrome"))
        XCTAssertEqual(provider.readCount, 0)
    }

    @MainActor
    func testOrdinaryClipboardContentAndDeclaredSourceArePreserved() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let item = NSPasteboardItem()
        item.setString("Nội dung bình thường", forType: .string)
        item.setString("com.example.source", forType: ClipboardHistoryPrivacyPolicy.sourceType)
        XCTAssertTrue(pasteboard.writeObjects([item]))

        let snapshot = read(pasteboard)
        XCTAssertEqual(snapshot?.payload.textContent, "Nội dung bình thường")
        XCTAssertEqual(snapshot?.sourceApp, "com.example.source")
    }

    @MainActor
    func testSensitiveForegroundAppIsExcludedEvenWithOrdinarySourceMarker() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let provider = ClipboardTestTextProvider()
        let item = NSPasteboardItem()
        item.setDataProvider(provider, forTypes: [.string])
        item.setString("com.example.source", forType: ClipboardHistoryPrivacyPolicy.sourceType)
        XCTAssertTrue(pasteboard.writeObjects([item]))

        XCTAssertNil(read(pasteboard, sourceApp: "com.apple.Passwords"))
        XCTAssertEqual(provider.readCount, 0)
    }

    @MainActor
    func testChangedGenerationIsRejectedBeforeReadingContent() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let request = ClipboardHistoryCaptureRequest(
            itemID: UUID(), changeCount: pasteboard.changeCount, sourceApp: nil
        )
        pasteboard.clearContents()
        pasteboard.setString("New generation", forType: .string)

        XCTAssertNil(ClipboardHistoryPasteboardReader.read(pasteboard, request: request))
    }

    @MainActor
    func testGenerationChangedByPromisedContentIsRejectedAfterReading() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let pasteboardName = pasteboard.name.rawValue
        let provider = ClipboardTestTextProvider {
            let changedPasteboard = NSPasteboard(name: NSPasteboard.Name(pasteboardName))
            changedPasteboard.clearContents()
            changedPasteboard.setString("New generation", forType: .string)
        }
        let item = NSPasteboardItem()
        item.setDataProvider(provider, forTypes: [.string])
        XCTAssertTrue(pasteboard.writeObjects([item]))

        XCTAssertNil(read(pasteboard))
        XCTAssertEqual(provider.readCount, 1)
    }

    @MainActor
    func testValidCaptureIsStoredExactlyOnceWithoutDiscardingItsCache() async {
        let fixture = ClipboardMonitorFixture()
        defer { fixture.close() }
        fixture.monitor.startMonitoring()
        fixture.copy("ordinary text")
        fixture.monitor.checkForChanges()
        await fulfillment(of: [fixture.started], timeout: 2)
        await fixture.worker.finishNext()
        await waitForIdle(fixture.monitor)

        XCTAssertEqual(fixture.stored.map(\.textContent), ["captured fixture"])
        XCTAssertTrue(fixture.discarded.ids.isEmpty)
        fixture.monitor.checkForChanges()
        XCTAssertFalse(fixture.monitor.isCapturing)
    }

    @MainActor
    func testTimeoutRetainsWorkerUntilLateResultAndCleansItsStagedCache() async {
        let fixture = ClipboardMonitorFixture()
        defer { fixture.close() }
        fixture.monitor.startMonitoring()
        fixture.copy("first generation")
        fixture.monitor.checkForChanges()
        await fulfillment(of: [fixture.started], timeout: 2)

        fixture.time = 2
        fixture.monitor.checkForChanges()
        XCTAssertEqual(fixture.timeoutCount, 1)
        XCTAssertTrue(fixture.monitor.isCapturing)
        fixture.copy("newer generation")
        fixture.time = 10
        fixture.monitor.checkForChanges()
        let countBeforeCompletion = await fixture.worker.startedCount
        XCTAssertEqual(countBeforeCompletion, 1)

        let discardedID = await fixture.worker.finishNext()
        await waitForIdle(fixture.monitor)
        XCTAssertTrue(fixture.stored.isEmpty)
        XCTAssertEqual(fixture.discarded.ids, [discardedID])

        fixture.monitor.checkForChanges()
        XCTAssertTrue(fixture.monitor.isCapturing)
        await finishCapture(fixture)
        XCTAssertEqual(fixture.stored.count, 1)
    }

    @MainActor
    func testTimedOutUnchangedClipboardCanRetryAfterWorkerFinishesAndBackoff() async {
        let fixture = ClipboardMonitorFixture()
        defer { fixture.close() }
        fixture.monitor.startMonitoring()
        fixture.copy("same generation")
        fixture.monitor.checkForChanges()
        await fulfillment(of: [fixture.started], timeout: 2)
        fixture.time = 3
        // Completion after the deadline must also time out if no poll ran.
        await fixture.worker.finishNext()
        await waitForIdle(fixture.monitor)
        XCTAssertTrue(fixture.stored.isEmpty)
        XCTAssertEqual(fixture.timeoutCount, 1)

        fixture.time = 7
        fixture.monitor.checkForChanges()
        XCTAssertFalse(fixture.monitor.isCapturing)
        fixture.time = 8
        fixture.monitor.checkForChanges()
        XCTAssertTrue(fixture.monitor.isCapturing)
        await finishCapture(fixture)
        XCTAssertEqual(fixture.stored.count, 1)
    }

    @MainActor
    func testStopRestartCannotOverlapOrAcceptThePreviousWorker() async {
        let fixture = ClipboardMonitorFixture()
        defer { fixture.close() }
        fixture.monitor.startMonitoring()
        fixture.copy("old capture")
        fixture.monitor.checkForChanges()
        await fulfillment(of: [fixture.started], timeout: 2)
        fixture.monitor.stopMonitoring()
        XCTAssertTrue(fixture.monitor.isCapturing)
        fixture.monitor.startMonitoring()
        fixture.copy("after restart")
        fixture.monitor.checkForChanges()
        let countBeforeCompletion = await fixture.worker.startedCount
        XCTAssertEqual(countBeforeCompletion, 1)

        let discardedID = await fixture.worker.finishNext()
        await waitForIdle(fixture.monitor)
        XCTAssertTrue(fixture.stored.isEmpty)
        XCTAssertEqual(fixture.discarded.ids, [discardedID])
        fixture.monitor.checkForChanges()
        await finishCapture(fixture)
        XCTAssertEqual(fixture.stored.count, 1)
    }

    @MainActor
    func testChangedPasteboardGenerationBeforePersistenceDiscardsResult() async {
        let fixture = ClipboardMonitorFixture()
        defer { fixture.close() }
        fixture.monitor.startMonitoring()
        fixture.copy("capturing")
        fixture.monitor.checkForChanges()
        await fulfillment(of: [fixture.started], timeout: 2)
        fixture.copy("replaced before persistence")
        let discardedID = await fixture.worker.finishNext()
        await waitForIdle(fixture.monitor)

        XCTAssertTrue(fixture.stored.isEmpty)
        XCTAssertEqual(fixture.discarded.ids, [discardedID])
    }

    @MainActor
    func testFailedCaptureStillDiscardsItsStagedFiles() async {
        let fixture = ClipboardMonitorFixture()
        defer { fixture.close() }
        fixture.monitor.startMonitoring()
        fixture.copy("failed capture")
        fixture.monitor.checkForChanges()
        await fulfillment(of: [fixture.started], timeout: 2)
        let discardedID = await fixture.worker.finishNext(success: false)
        await waitForIdle(fixture.monitor)

        XCTAssertTrue(fixture.stored.isEmpty)
        XCTAssertEqual(fixture.discarded.ids, [discardedID])
    }

    @MainActor
    func testPasteMutationBeginningDuringCapturePreventsPersistence() async {
        let fixture = ClipboardMonitorFixture()
        defer { fixture.close() }
        fixture.monitor.startMonitoring()
        fixture.copy("capturing")
        fixture.monitor.checkForChanges()
        await fulfillment(of: [fixture.started], timeout: 2)
        fixture.isSuppressed = true
        await fixture.worker.finishNext()
        await waitForIdle(fixture.monitor)

        XCTAssertTrue(fixture.stored.isEmpty)
        XCTAssertEqual(fixture.discarded.ids.count, 1)
    }

    @MainActor
    func testPrivacyRevalidationBeforeCommitDiscardsPreviouslyEligiblePayload() async {
        let fixture = ClipboardMonitorFixture()
        defer { fixture.close() }
        fixture.monitor.startMonitoring()
        fixture.copy("capturing")
        fixture.monitor.checkForChanges()
        await fulfillment(of: [fixture.started], timeout: 2)
        fixture.allowsCommit = false
        await fixture.worker.finishNext()
        await waitForIdle(fixture.monitor)

        XCTAssertTrue(fixture.stored.isEmpty)
        XCTAssertEqual(fixture.discarded.ids.count, 1)
    }

    @MainActor
    private func read(
        _ pasteboard: NSPasteboard,
        sourceApp: String? = "com.example.editor"
    ) -> ClipboardHistoryPasteboardSnapshot? {
        ClipboardHistoryPasteboardReader.read(pasteboard, request: ClipboardHistoryCaptureRequest(
            itemID: UUID(), changeCount: pasteboard.changeCount, sourceApp: sourceApp
        ))
    }

    @MainActor
    private func waitForIdle(_ monitor: ClipboardMonitor) async {
        let deadline = ContinuousClock.now + .seconds(2)
        while monitor.isCapturing, ContinuousClock.now < deadline {
            await Task.yield()
        }
        XCTAssertFalse(monitor.isCapturing, "Capture worker did not finish")
    }

    @MainActor
    private func finishCapture(_ fixture: ClipboardMonitorFixture) async {
        let deadline = ContinuousClock.now + .seconds(2)
        while await fixture.worker.pendingCount == 0, ContinuousClock.now < deadline {
            await Task.yield()
        }
        await fixture.worker.finishNext()
        await waitForIdle(fixture.monitor)
    }
}

/// The pasteboard may call its provider on another thread; its counter is
/// protected by the same lock for every access.
private final class ClipboardTestTextProvider: NSObject, NSPasteboardItemDataProvider {
    private let lock = NSLock()
    private var reads = 0
    private let onRead: @Sendable () -> Void

    init(onRead: @escaping @Sendable () -> Void = {}) {
        self.onRead = onRead
    }

    var readCount: Int { lock.withLock { reads } }

    func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
        lock.withLock { reads += 1 }
        item.setString("private fixture text", forType: type)
        onRead()
    }
}

private final class ClipboardDiscardedIDs: @unchecked Sendable {
    // Discard runs on the capture worker; tests inspect it on MainActor.
    // Every read/write is protected by this lock.
    private let lock = NSLock()
    private var values: [UUID] = []
    var ids: [UUID] { lock.withLock { values } }
    func append(_ id: UUID) { lock.withLock { values.append(id) } }
}

private actor ClipboardControlledWorker {
    private var pending: [(ClipboardHistoryCaptureRequest, CheckedContinuation<ClipboardHistoryItem?, Never>)] = []
    private(set) var startedCount = 0
    private let started: XCTestExpectation

    init(started: XCTestExpectation) { self.started = started }
    var pendingCount: Int { pending.count }

    func capture(_ request: ClipboardHistoryCaptureRequest) async -> ClipboardHistoryItem? {
        await withCheckedContinuation { continuation in
            pending.append((request, continuation))
            startedCount += 1
            if startedCount == 1 { started.fulfill() }
        }
    }

    @discardableResult
    func finishNext(success: Bool = true) -> UUID {
        guard !pending.isEmpty else {
            XCTFail("No capture waiting for completion")
            return UUID()
        }
        let (request, continuation) = pending.removeFirst()
        continuation.resume(returning: success ? ClipboardHistoryItem(
            id: request.itemID,
            timestamp: Date(),
            textContent: "captured fixture",
            imageData: nil,
            filePaths: nil,
            sourceApp: request.sourceApp
        ) : nil)
        return request.itemID
    }
}

@MainActor
private final class ClipboardMonitorFixture {
    let pasteboard = NSPasteboard.withUniqueName()
    let started = XCTestExpectation(description: "capture started")
    let discarded = ClipboardDiscardedIDs()
    lazy var worker = ClipboardControlledWorker(started: started)
    var stored: [ClipboardHistoryItem] = []
    var time: TimeInterval = 0
    var timeoutCount = 0
    var isSuppressed = false
    var allowsCommit = true

    lazy var monitor = makeMonitor()

    private func makeMonitor() -> ClipboardMonitor {
        let worker = worker
        let discarded = discarded
        return ClipboardMonitor(
            dependencies: ClipboardMonitor.Dependencies(
                changeCount: { [unowned self] in pasteboard.changeCount },
                sourceApp: { "com.example.editor" },
                isCaptureSuppressed: { [unowned self] in isSuppressed },
                canCommit: { [unowned self] _ in allowsCommit },
                capture: { await worker.capture($0) },
                discard: { discarded.append($0) },
                store: { [unowned self] in stored.append($0) },
                didTimeout: { [unowned self] in timeoutCount += 1 }
            ),
            pollingInterval: nil,
            now: { [unowned self] in time }
        )
    }

    func copy(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func close() {
        monitor.stopMonitoring()
        pasteboard.releaseGlobally()
    }
}
