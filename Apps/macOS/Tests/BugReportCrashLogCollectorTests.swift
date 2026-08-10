//
//  BugReportCrashLogCollectorTests.swift
//  PHTV
//

import XCTest
@testable import PHTV

final class BugReportCrashLogCollectorTests: XCTestCase {
    func testModernIPSIncludesDiagnosisAndSymbolicatedFramesWithoutPrivateIdentifiers() {
        let header = #"""
        {"app_name":"PHTV","timestamp":"2026-08-09 09:26:38 +0700","app_version":"3.4.7","build_version":"314","bug_type":"309","os_version":"macOS 27.0 (26A5388g)","incident_id":"PRIVATE-INCIDENT"}
        """#
        let report = #"""
        {
          "modelCode":"Mac16,1",
          "cpuType":"ARM-64",
          "exception":{"type":"EXC_CRASH","signal":"SIGABRT"},
          "termination":{"namespace":"SIGNAL","code":6,"indicator":"Abort trap: 6"},
          "faultingThread":0,
          "threads":[{"queue":"com.apple.main-thread","frames":[
            {"imageIndex":0,"symbol":"abort"},
            {"imageIndex":1,"symbol":"-[NSRemoteView containingWindowWillOrderOnScreen:]","sourceFile":"/Users/alice/private/PHTVApp.swift","sourceLine":42}
          ]}],
          "lastExceptionBacktrace":[
            {"imageIndex":1,"symbol":"-[NSRemoteView containingWindowWillOrderOnScreen:]"}
          ],
          "usedImages":[{"name":"PHTV"},{"name":"ViewBridge"}],
          "crashReporterKey":"PRIVATE-KEY",
          "storeInfo":{"deviceIdentifierForVendor":"PRIVATE-DEVICE"}
        }
        """#

        let output = BugReportCrashLogCollector.formattedCrashReport(
            content: header + "\n" + report,
            filename: "PHTV-2026-08-09.ips",
            detail: .full
        )

        XCTAssertTrue(output.contains("PHTV: 3.4.7, build 314"))
        XCTAssertTrue(output.contains("macOS 27.0 (26A5388g)"))
        XCTAssertTrue(output.contains("EXC_CRASH / SIGABRT"))
        XCTAssertTrue(output.contains("SIGNAL, code 6, Abort trap: 6"))
        XCTAssertTrue(output.contains("com.apple.main-thread"))
        XCTAssertTrue(output.contains("ViewBridge — -[NSRemoteView containingWindowWillOrderOnScreen:]"))
        XCTAssertTrue(output.contains("~/private/PHTVApp.swift: line 42"))
        XCTAssertFalse(output.contains("alice"))
        XCTAssertFalse(output.contains("PRIVATE-INCIDENT"))
        XCTAssertFalse(output.contains("PRIVATE-KEY"))
        XCTAssertFalse(output.contains("PRIVATE-DEVICE"))
    }

    func testCompactIPSStillKeepsTheActionableExceptionStack() {
        let header = #"{"app_name":"PHTV","app_version":"3.4.7","build_version":"314","bug_type":"309"}"#
        let report = #"""
        {"exception":{"type":"EXC_CRASH","signal":"SIGABRT"},
         "lastExceptionBacktrace":[{"imageIndex":0,"symbol":"frame-0"},{"imageIndex":0,"symbol":"frame-1"}],
         "usedImages":[{"name":"PHTV"}]}
        """#

        let output = BugReportCrashLogCollector.formattedCrashReport(
            content: header + "\n" + report,
            filename: "PHTV.ips",
            detail: .compact
        )

        XCTAssertTrue(output.contains("Last exception backtrace"))
        XCTAssertTrue(output.contains("PHTV — frame-0"))
        XCTAssertTrue(output.contains("PHTV — frame-1"))
    }

    func testLegacyCrashReportKeepsReasonAndBacktrace() {
        let content = """
        Process: PHTV
        Version: 3.4.7 (314)
        OS Version: macOS 27.0 (26A5388g)
        Exception Type: EXC_CRASH (SIGABRT)
        Termination Reason: Namespace SIGNAL, Code 6

        Last Exception Backtrace:
        0 CoreFoundation __exceptionPreprocess
        1 ViewBridge -[NSRemoteView containingWindowWillOrderOnScreen:]

        Thread 0:
        """

        let output = BugReportCrashLogCollector.formattedCrashReport(
            content: content,
            filename: "PHTV.crash",
            detail: .full
        )

        XCTAssertTrue(output.contains("Exception Type: EXC_CRASH (SIGABRT)"))
        XCTAssertTrue(output.contains("Termination Reason: Namespace SIGNAL, Code 6"))
        XCTAssertTrue(output.contains("ViewBridge -[NSRemoteView containingWindowWillOrderOnScreen:]"))
    }
}
