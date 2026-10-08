// MARK: - DateAdapterTests.swift

import XCTest
@testable import Illustrate

final class DateAdapterTests: XCTestCase {
    // MARK: - getDateFromString Tests

    func testValidDateString() {
        let date = getDateFromString("2024-06-15")
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.day, 15)
    }

    func testFirstDayOfYear() {
        let date = getDateFromString("2024-01-01")
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 1)
    }

    func testLastDayOfYear() {
        let date = getDateFromString("2024-12-31")
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 31)
    }

    func testLeapYearDate() {
        let date = getDateFromString("2024-02-29")
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 2)
        XCTAssertEqual(components.day, 29)
    }

    func testInvalidDateStringReturnsCurrentDate() {
        let beforeCall = Date()
        let date = getDateFromString("invalid")
        let afterCall = Date()

        // Invalid date should return current date (Date())
        XCTAssertGreaterThanOrEqual(date, beforeCall)
        XCTAssertLessThanOrEqual(date, afterCall)
    }

    func testEmptyStringReturnsCurrentDate() {
        let beforeCall = Date()
        let date = getDateFromString("")
        let afterCall = Date()

        XCTAssertGreaterThanOrEqual(date, beforeCall)
        XCTAssertLessThanOrEqual(date, afterCall)
    }

    func testWrongFormatReturnsCurrentDate() {
        let beforeCall = Date()
        let date = getDateFromString("15/06/2024") // Wrong format (DD/MM/YYYY)
        let afterCall = Date()

        XCTAssertGreaterThanOrEqual(date, beforeCall)
        XCTAssertLessThanOrEqual(date, afterCall)
    }

    // MARK: - DateFormatters Tests

    func testYearMonthDayFormatterFormat() {
        let date = Date(timeIntervalSince1970: 1_718_409_600) // 2024-06-15 00:00:00 UTC
        let formatted = DateFormatters.yearMonthDay.string(from: date)

        // The exact output depends on timezone, but should match yyyy-MM-dd format
        XCTAssertTrue(formatted.contains("-"))
        XCTAssertEqual(formatted.count, 10) // "yyyy-MM-dd" is always 10 characters
    }

    func testISO8601FormatterExists() {
        let formatter = DateFormatters.iso8601
        XCTAssertNotNil(formatter)
    }

    func testISO8601FormatterProducesValidOutput() {
        let date = Date(timeIntervalSince1970: 0) // 1970-01-01T00:00:00Z
        let formatted = DateFormatters.iso8601.string(from: date)

        XCTAssertEqual(formatted, "1970-01-01T00:00:00Z")
    }
}
