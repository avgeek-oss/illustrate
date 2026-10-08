// MARK: - GenerationSpeedTests.swift

// Tests for GenerationSpeed enum - completely untested before this file.
//
// Tests cover:
// - Case validation (allCases count, raw values)
// - Label strings for each case
// - intervalMs computed property
// - defaultSpeed static property
// - from(ms:) factory method (exact match, unknown, zero, negative)

import Foundation
import XCTest
@testable import Illustrate

final class GenerationSpeedTests: XCTestCase {
    // MARK: - Case Validation

    func testGenerationSpeed_allCases_count() {
        XCTAssertEqual(GenerationSpeed.allCases.count, 5)
    }

    func testGenerationSpeed_rawValue_fivePerSecond() {
        XCTAssertEqual(GenerationSpeed.fivePerSecond.rawValue, 200.0)
    }

    func testGenerationSpeed_rawValue_twoPerSecond() {
        XCTAssertEqual(GenerationSpeed.twoPerSecond.rawValue, 500.0)
    }

    func testGenerationSpeed_rawValue_onePerSecond() {
        XCTAssertEqual(GenerationSpeed.onePerSecond.rawValue, 1000.0)
    }

    func testGenerationSpeed_rawValue_onePerTwoSeconds() {
        XCTAssertEqual(GenerationSpeed.onePerTwoSeconds.rawValue, 2000.0)
    }

    func testGenerationSpeed_rawValue_onePerFiveSeconds() {
        XCTAssertEqual(GenerationSpeed.onePerFiveSeconds.rawValue, 5000.0)
    }

    // MARK: - Labels

    func testGenerationSpeed_label_fivePerSecond() {
        XCTAssertEqual(GenerationSpeed.fivePerSecond.label, "5 per second")
    }

    func testGenerationSpeed_label_twoPerSecond() {
        XCTAssertEqual(GenerationSpeed.twoPerSecond.label, "2 per second")
    }

    func testGenerationSpeed_label_onePerSecond() {
        XCTAssertEqual(GenerationSpeed.onePerSecond.label, "1 per second")
    }

    func testGenerationSpeed_label_onePerTwoSeconds() {
        XCTAssertEqual(GenerationSpeed.onePerTwoSeconds.label, "1 per 2 seconds")
    }

    func testGenerationSpeed_label_onePerFiveSeconds() {
        XCTAssertEqual(GenerationSpeed.onePerFiveSeconds.label, "1 per 5 seconds")
    }

    // MARK: - intervalMs

    func testGenerationSpeed_intervalMs_matchesRawValue() {
        for speed in GenerationSpeed.allCases {
            XCTAssertEqual(speed.intervalMs, speed.rawValue)
        }
    }

    func testGenerationSpeed_intervalMs_fivePerSecond() {
        XCTAssertEqual(GenerationSpeed.fivePerSecond.intervalMs, 200.0)
    }

    // MARK: - defaultSpeed

    func testGenerationSpeed_defaultSpeed_isTwoPerSecond() {
        XCTAssertEqual(GenerationSpeed.defaultSpeed, .twoPerSecond)
    }

    func testGenerationSpeed_defaultSpeed_rawValueIs500() {
        XCTAssertEqual(GenerationSpeed.defaultSpeed.rawValue, 500.0)
    }

    // MARK: - from(ms:) Factory

    func testGenerationSpeed_fromMs_200_returnsFivePerSecond() {
        XCTAssertEqual(GenerationSpeed.from(ms: 200.0), .fivePerSecond)
    }

    func testGenerationSpeed_fromMs_500_returnsTwoPerSecond() {
        XCTAssertEqual(GenerationSpeed.from(ms: 500.0), .twoPerSecond)
    }

    func testGenerationSpeed_fromMs_1000_returnsOnePerSecond() {
        XCTAssertEqual(GenerationSpeed.from(ms: 1000.0), .onePerSecond)
    }

    func testGenerationSpeed_fromMs_2000_returnsOnePerTwoSeconds() {
        XCTAssertEqual(GenerationSpeed.from(ms: 2000.0), .onePerTwoSeconds)
    }

    func testGenerationSpeed_fromMs_5000_returnsOnePerFiveSeconds() {
        XCTAssertEqual(GenerationSpeed.from(ms: 5000.0), .onePerFiveSeconds)
    }

    func testGenerationSpeed_fromMs_unknownValue_returnsDefault() {
        XCTAssertEqual(GenerationSpeed.from(ms: 750.0), .defaultSpeed)
    }

    func testGenerationSpeed_fromMs_zero_returnsDefault() {
        XCTAssertEqual(GenerationSpeed.from(ms: 0.0), .defaultSpeed)
    }

    func testGenerationSpeed_fromMs_negative_returnsDefault() {
        XCTAssertEqual(GenerationSpeed.from(ms: -100.0), .defaultSpeed)
    }

    // MARK: - Identifiable

    func testGenerationSpeed_id_matchesRawValue() {
        for speed in GenerationSpeed.allCases {
            XCTAssertEqual(speed.id, speed.rawValue)
        }
    }
}
