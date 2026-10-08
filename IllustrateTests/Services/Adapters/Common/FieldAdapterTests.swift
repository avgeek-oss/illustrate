// MARK: - FieldAdapterTests.swift

import XCTest
@testable import Illustrate

final class FieldAdapterTests: XCTestCase {
    // MARK: - ErrorState Tests

    func testErrorStateInitialization() {
        let errorState = ErrorState(message: "Test error", isShowing: true)

        XCTAssertEqual(errorState.message, "Test error")
        XCTAssertTrue(errorState.isShowing)
    }

    func testErrorStateNotShowing() {
        let errorState = ErrorState(message: "Hidden error", isShowing: false)

        XCTAssertEqual(errorState.message, "Hidden error")
        XCTAssertFalse(errorState.isShowing)
    }

    func testErrorStateEmptyMessage() {
        let errorState = ErrorState(message: "", isShowing: true)

        XCTAssertEqual(errorState.message, "")
        XCTAssertTrue(errorState.isShowing)
    }

    func testErrorStateLongMessage() {
        let longMessage = String(repeating: "Error ", count: 100)
        let errorState = ErrorState(message: longMessage, isShowing: true)

        XCTAssertEqual(errorState.message, longMessage)
        XCTAssertTrue(errorState.isShowing)
    }

    func testErrorStateMessageMutability() {
        var errorState = ErrorState(message: "Initial", isShowing: false)
        errorState.message = "Updated"
        errorState.isShowing = true

        XCTAssertEqual(errorState.message, "Updated")
        XCTAssertTrue(errorState.isShowing)
    }

    func testErrorStateSpecialCharacters() {
        let specialMessage = "Error: <script>alert('xss')</script> & \"quotes\""
        let errorState = ErrorState(message: specialMessage, isShowing: true)

        XCTAssertEqual(errorState.message, specialMessage)
    }

    func testErrorStateUnicodeMessage() {
        let unicodeMessage = "Error: \u{1F4A5} Something went wrong! \u{26A0}\u{FE0F}"
        let errorState = ErrorState(message: unicodeMessage, isShowing: true)

        XCTAssertEqual(errorState.message, unicodeMessage)
    }
}
