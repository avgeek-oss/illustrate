// MARK: - PreviousCardInputTests.swift

// Tests for PreviousCardInput struct - upstream card data in agent workflows.
//
// Tests cover:
// - Default state (all fields nil/false)
// - hasText computed property (nil, empty, non-empty)
// - hasVideo computed property (nil vs present URL)
// - hasAnyInput computed property (combinations)
// - canProvideImage computed property (image + placeholder logic)
// - Combined input state scenarios

import Foundation
import XCTest
@testable import Illustrate

final class PreviousCardInputExtendedTests: XCTestCase {
    // MARK: - Default State

    func testPreviousCardInput_default_textIsNil() {
        let input = PreviousCardInput()
        XCTAssertNil(input.text)
    }

    func testPreviousCardInput_default_imageIsNil() {
        let input = PreviousCardInput()
        XCTAssertNil(input.image)
    }

    func testPreviousCardInput_default_videoIsNil() {
        let input = PreviousCardInput()
        XCTAssertNil(input.video)
    }

    func testPreviousCardInput_default_isImagePlaceholderFalse() {
        let input = PreviousCardInput()
        XCTAssertFalse(input.isImagePlaceholder)
    }

    // MARK: - hasText

    func testPreviousCardInput_hasText_nil_returnsFalse() {
        let input = PreviousCardInput(text: nil)
        XCTAssertFalse(input.hasText)
    }

    func testPreviousCardInput_hasText_empty_returnsFalse() {
        let input = PreviousCardInput(text: "")
        XCTAssertFalse(input.hasText)
    }

    func testPreviousCardInput_hasText_nonEmpty_returnsTrue() {
        let input = PreviousCardInput(text: "A sunset over the ocean")
        XCTAssertTrue(input.hasText)
    }

    // MARK: - hasVideo

    func testPreviousCardInput_hasVideo_nil_returnsFalse() {
        let input = PreviousCardInput(video: nil)
        XCTAssertFalse(input.hasVideo)
    }

    func testPreviousCardInput_hasVideo_withURL_returnsTrue() throws {
        let input = try PreviousCardInput(video: XCTUnwrap(URL(string: "file:///tmp/video.mp4")))
        XCTAssertTrue(input.hasVideo)
    }

    // MARK: - hasAnyInput

    func testPreviousCardInput_hasAnyInput_allNil_returnsFalse() {
        let input = PreviousCardInput()
        XCTAssertFalse(input.hasAnyInput)
    }

    func testPreviousCardInput_hasAnyInput_textOnly_returnsTrue() {
        let input = PreviousCardInput(text: "Some text")
        XCTAssertTrue(input.hasAnyInput)
    }

    func testPreviousCardInput_hasAnyInput_videoOnly_returnsTrue() throws {
        let input = try PreviousCardInput(video: XCTUnwrap(URL(string: "file:///tmp/v.mp4")))
        XCTAssertTrue(input.hasAnyInput)
    }

    func testPreviousCardInput_hasAnyInput_emptyText_returnsFalse() {
        let input = PreviousCardInput(text: "")
        XCTAssertFalse(input.hasAnyInput)
    }

    // MARK: - canProvideImage

    func testPreviousCardInput_canProvideImage_noImageNoPlaceholder_returnsFalse() {
        let input = PreviousCardInput()
        XCTAssertFalse(input.canProvideImage)
    }

    func testPreviousCardInput_canProvideImage_placeholderTrue_returnsTrue() {
        let input = PreviousCardInput(isImagePlaceholder: true)
        XCTAssertTrue(input.canProvideImage)
    }

    // MARK: - Combined States

    func testPreviousCardInput_textAndVideo_hasAnyInputTrue() throws {
        let input = try PreviousCardInput(
            text: "Prompt",
            video: XCTUnwrap(URL(string: "file:///tmp/v.mp4"))
        )
        XCTAssertTrue(input.hasAnyInput)
        XCTAssertTrue(input.hasText)
        XCTAssertTrue(input.hasVideo)
    }

    func testPreviousCardInput_emptyTextNilImage_hasAnyInputFalse() {
        let input = PreviousCardInput(text: "", image: nil)
        XCTAssertFalse(input.hasAnyInput)
    }

    func testPreviousCardInput_placeholderWithText_canProvideImageAndHasText() {
        let input = PreviousCardInput(text: "Generate from this", isImagePlaceholder: true)
        XCTAssertTrue(input.canProvideImage)
        XCTAssertTrue(input.hasText)
    }

    func testPreviousCardInput_hasImage_nil_returnsFalse() {
        let input = PreviousCardInput(image: nil)
        XCTAssertFalse(input.hasImage)
    }
}
