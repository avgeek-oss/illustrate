// MARK: - BackdropDownloadStateTests.swift

// Tests for BackdropDownloadState enum from PodiumBackdropsManager.
// Covers all 5 cases, computed properties (isLoading, statusMessage, isFailure),
// and Equatable conformance including the .failed associated value.

import XCTest
@testable import Illustrate

final class BackdropDownloadStateTests: XCTestCase {
    // MARK: - isLoading

    func testIsLoading_Downloading_ReturnsTrue() {
        XCTAssertTrue(BackdropDownloadState.downloading.isLoading)
    }

    func testIsLoading_Extracting_ReturnsTrue() {
        XCTAssertTrue(BackdropDownloadState.extracting.isLoading)
    }

    func testIsLoading_NotDownloaded_ReturnsFalse() {
        XCTAssertFalse(BackdropDownloadState.notDownloaded.isLoading)
    }

    func testIsLoading_Ready_ReturnsFalse() {
        XCTAssertFalse(BackdropDownloadState.ready.isLoading)
    }

    func testIsLoading_Failed_ReturnsFalse() {
        XCTAssertFalse(BackdropDownloadState.failed("error").isLoading)
    }

    // MARK: - statusMessage

    func testStatusMessage_NotDownloaded() {
        XCTAssertEqual(BackdropDownloadState.notDownloaded.statusMessage, "Not downloaded")
    }

    func testStatusMessage_Downloading() {
        XCTAssertEqual(BackdropDownloadState.downloading.statusMessage, "Downloading backdrop templates...")
    }

    func testStatusMessage_Extracting() {
        XCTAssertEqual(BackdropDownloadState.extracting.statusMessage, "Extracting...")
    }

    func testStatusMessage_Ready() {
        XCTAssertEqual(BackdropDownloadState.ready.statusMessage, "Ready")
    }

    func testStatusMessage_Failed_IncludesErrorMessage() {
        XCTAssertEqual(BackdropDownloadState.failed("timeout").statusMessage, "Failed: timeout")
    }

    func testStatusMessage_Failed_EmptyString() {
        XCTAssertEqual(BackdropDownloadState.failed("").statusMessage, "Failed: ")
    }

    func testStatusMessage_Failed_DetailedError() {
        let error = "Network connection lost"
        XCTAssertEqual(BackdropDownloadState.failed(error).statusMessage, "Failed: Network connection lost")
    }

    // MARK: - isFailure

    func testIsFailure_Failed_ReturnsTrue() {
        XCTAssertTrue(BackdropDownloadState.failed("error").isFailure)
    }

    func testIsFailure_NotDownloaded_ReturnsFalse() {
        XCTAssertFalse(BackdropDownloadState.notDownloaded.isFailure)
    }

    func testIsFailure_Downloading_ReturnsFalse() {
        XCTAssertFalse(BackdropDownloadState.downloading.isFailure)
    }

    func testIsFailure_Extracting_ReturnsFalse() {
        XCTAssertFalse(BackdropDownloadState.extracting.isFailure)
    }

    func testIsFailure_Ready_ReturnsFalse() {
        XCTAssertFalse(BackdropDownloadState.ready.isFailure)
    }

    // MARK: - Equatable

    func testEquatable_SameCase_Ready() {
        XCTAssertEqual(BackdropDownloadState.ready, BackdropDownloadState.ready)
    }

    func testEquatable_SameCase_NotDownloaded() {
        XCTAssertEqual(BackdropDownloadState.notDownloaded, BackdropDownloadState.notDownloaded)
    }

    func testEquatable_SameCase_Downloading() {
        XCTAssertEqual(BackdropDownloadState.downloading, BackdropDownloadState.downloading)
    }

    func testEquatable_SameCase_Extracting() {
        XCTAssertEqual(BackdropDownloadState.extracting, BackdropDownloadState.extracting)
    }

    func testEquatable_DifferentCases_NotEqual() {
        XCTAssertNotEqual(BackdropDownloadState.notDownloaded, BackdropDownloadState.downloading)
        XCTAssertNotEqual(BackdropDownloadState.downloading, BackdropDownloadState.extracting)
        XCTAssertNotEqual(BackdropDownloadState.extracting, BackdropDownloadState.ready)
    }

    func testEquatable_FailedSameError_Equal() {
        XCTAssertEqual(BackdropDownloadState.failed("err"), BackdropDownloadState.failed("err"))
    }

    func testEquatable_FailedDifferentError_NotEqual() {
        XCTAssertNotEqual(BackdropDownloadState.failed("a"), BackdropDownloadState.failed("b"))
    }

    func testEquatable_FailedVsReady_NotEqual() {
        XCTAssertNotEqual(BackdropDownloadState.failed("error"), BackdropDownloadState.ready)
    }

    func testEquatable_FailedVsNotDownloaded_NotEqual() {
        XCTAssertNotEqual(BackdropDownloadState.failed("error"), BackdropDownloadState.notDownloaded)
    }

    // MARK: - All Cases Distinguishable

    func testAllCases_Distinguishable() {
        let states: [BackdropDownloadState] = [
            .notDownloaded, .downloading, .extracting, .ready, .failed("error"),
        ]

        for i in 0 ..< states.count {
            for j in (i + 1) ..< states.count {
                XCTAssertNotEqual(states[i], states[j], "\(states[i]) should not equal \(states[j])")
            }
        }
    }
}
