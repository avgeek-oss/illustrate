// MARK: - CostFormatterWorkflowTests.swift

// Workflow tests for the formatEstimatedCost() function in both
// the app target and IllustrateProviders package.
//
// Tests cover:
// - Zero cost → "Free"
// - Sub-cent amounts → 4 decimal precision
// - Normal amounts → 2 decimal precision
// - Trailing zero trimming
// - Package and app implementations produce identical results

import XCTest
@testable import Illustrate
@testable import IllustrateProviders

/// Disambiguate the two identically-named free functions from each module
private let appFormatCost = Illustrate.formatEstimatedCost
private let pkgFormatCost = IllustrateProviders.formatEstimatedCost

final class CostFormatterWorkflowTests: XCTestCase {
    // MARK: - App-Level formatEstimatedCost() Tests

    func testAppFormatCost_Zero_ReturnsFree() {
        XCTAssertEqual(appFormatCost(0), "Free")
    }

    func testAppFormatCost_SubCent_FourDecimals() {
        XCTAssertEqual(appFormatCost(0.001), "$0.001")
    }

    func testAppFormatCost_SubCent_0_0099() {
        XCTAssertEqual(appFormatCost(0.0099), "$0.0099")
    }

    func testAppFormatCost_SubCent_0_005() {
        XCTAssertEqual(appFormatCost(0.005), "$0.005")
    }

    func testAppFormatCost_SubCent_0_0025() {
        XCTAssertEqual(appFormatCost(0.0025), "$0.0025")
    }

    func testAppFormatCost_ExactlyCent_TwoDecimals() {
        XCTAssertEqual(appFormatCost(0.01), "$0.01")
    }

    func testAppFormatCost_NormalAmount_TrailingZeroTrimmed() {
        // 0.10 formatted as %.2f = "0.10", trim trailing 0 → "0.1"
        XCTAssertEqual(appFormatCost(0.10), "$0.1")
    }

    func testAppFormatCost_NormalAmount_1_50_TrimsTrailingZero() {
        XCTAssertEqual(appFormatCost(1.50), "$1.5")
    }

    func testAppFormatCost_WholeNumber_TrimsDecimalPoint() {
        // 5.0 formatted as %.2f = "5.00", trim → "5"
        XCTAssertEqual(appFormatCost(5.0), "$5")
    }

    func testAppFormatCost_0_04_PreservesSignificantDecimals() {
        XCTAssertEqual(appFormatCost(0.04), "$0.04")
    }

    func testAppFormatCost_NegativeValue_FormatsWithDollarSign() {
        let result = appFormatCost(-0.05)
        XCTAssertTrue(result.hasPrefix("$"))
    }

    func testAppFormatCost_LargeAmount() {
        XCTAssertEqual(appFormatCost(10.0), "$10")
    }

    // MARK: - Package-Level formatEstimatedCost() Tests

    func testPkgFormatCost_Zero_ReturnsFree() {
        XCTAssertEqual(pkgFormatCost(0), "Free")
    }

    func testPkgFormatCost_SubCent() {
        XCTAssertEqual(pkgFormatCost(0.001), "$0.001")
    }

    func testPkgFormatCost_ExactlyCent() {
        XCTAssertEqual(pkgFormatCost(0.01), "$0.01")
    }

    func testPkgFormatCost_NormalAmount_TrailingZeroTrimmed() {
        XCTAssertEqual(pkgFormatCost(0.10), "$0.1")
    }

    func testPkgFormatCost_WholeNumber() {
        XCTAssertEqual(pkgFormatCost(5.0), "$5")
    }

    // MARK: - App and Package Parity Tests

    func testFormatCost_Parity_Zero() {
        XCTAssertEqual(appFormatCost(0), pkgFormatCost(0))
    }

    func testFormatCost_Parity_SubCent() {
        XCTAssertEqual(appFormatCost(0.0025), pkgFormatCost(0.0025))
    }

    func testFormatCost_Parity_NormalAmount() {
        XCTAssertEqual(appFormatCost(0.04), pkgFormatCost(0.04))
    }

    func testFormatCost_Parity_WholeNumber() {
        XCTAssertEqual(appFormatCost(10.0), pkgFormatCost(10.0))
    }
}
