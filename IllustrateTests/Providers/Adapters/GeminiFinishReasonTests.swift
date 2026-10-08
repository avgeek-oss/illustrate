// MARK: - GeminiFinishReasonTests.swift

// Workflow tests for GeminiFinishReason error classification and user messaging.
//
// Tests cover:
// - isError: only .stop returns false, all others return true
// - isImageError: exactly 5 image-related cases return true
// - Comprehensive classification: exhaustive verification of all 16 cases
// - userDescription: all cases produce non-empty, meaningful strings
// - from() factory: raw string parsing, nil handling, unknown strings

import XCTest
@testable import IllustrateProviders

final class GeminiFinishReasonTests: XCTestCase {
    // MARK: - isError Tests

    func testIsError_Stop_ReturnsFalse() {
        XCTAssertFalse(GeminiFinishReason.stop.isError)
    }

    func testIsError_Safety_ReturnsTrue() {
        XCTAssertTrue(GeminiFinishReason.safety.isError)
    }

    func testIsError_MaxTokens_ReturnsTrue() {
        XCTAssertTrue(GeminiFinishReason.maxTokens.isError)
    }

    func testIsError_ImageSafety_ReturnsTrue() {
        XCTAssertTrue(GeminiFinishReason.imageSafety.isError)
    }

    func testIsError_Unspecified_ReturnsTrue() {
        XCTAssertTrue(GeminiFinishReason.unspecified.isError)
    }

    func testIsError_ExactlyOneNonError() {
        // Across all 16 cases, exactly 1 should have isError == false
        let nonErrors = GeminiFinishReason.allCases.filter { !$0.isError }
        XCTAssertEqual(nonErrors.count, 1)
        XCTAssertEqual(nonErrors.first, .stop)
    }

    // MARK: - isImageError Tests

    func testIsImageError_ImageSafety_ReturnsTrue() {
        XCTAssertTrue(GeminiFinishReason.imageSafety.isImageError)
    }

    func testIsImageError_ImageProhibitedContent_ReturnsTrue() {
        XCTAssertTrue(GeminiFinishReason.imageProhibitedContent.isImageError)
    }

    func testIsImageError_ImageRecitation_ReturnsTrue() {
        XCTAssertTrue(GeminiFinishReason.imageRecitation.isImageError)
    }

    func testIsImageError_ImageOther_ReturnsTrue() {
        XCTAssertTrue(GeminiFinishReason.imageOther.isImageError)
    }

    func testIsImageError_NoImage_ReturnsTrue() {
        XCTAssertTrue(GeminiFinishReason.noImage.isImageError)
    }

    func testIsImageError_Safety_ReturnsFalse() {
        // General safety is NOT an image-specific error
        XCTAssertFalse(GeminiFinishReason.safety.isImageError)
    }

    func testIsImageError_Stop_ReturnsFalse() {
        XCTAssertFalse(GeminiFinishReason.stop.isImageError)
    }

    func testIsImageError_ExactlyFiveImageErrors() {
        let imageErrors = GeminiFinishReason.allCases.filter(\.isImageError)
        XCTAssertEqual(imageErrors.count, 5)
    }

    // MARK: - Classification Invariant Tests

    func testInvariant_ImageErrorImpliesError() {
        // No case should have isImageError == true AND isError == false
        for reason in GeminiFinishReason.allCases {
            if reason.isImageError {
                XCTAssertTrue(
                    reason.isError,
                    "\(reason) has isImageError=true but isError=false — invariant violation"
                )
            }
        }
    }

    func testInvariant_AllCasesCount() {
        // Verify we're testing against all 17 known cases
        XCTAssertEqual(GeminiFinishReason.allCases.count, 17)
    }

    func testInvariant_NonImageErrors_AreStillErrors() {
        // Cases like .safety, .blocklist should be errors but NOT image errors
        let nonImageErrors = GeminiFinishReason.allCases.filter { $0.isError && !$0.isImageError }
        // 17 total - 1 non-error (.stop) - 5 image errors = 11 non-image errors
        XCTAssertEqual(nonImageErrors.count, 11)
    }

    // MARK: - userDescription Tests

    func testUserDescription_Stop_NonEmpty() {
        XCTAssertFalse(GeminiFinishReason.stop.userDescription.isEmpty)
    }

    func testUserDescription_Safety_ContainsSafetyLanguage() {
        let desc = GeminiFinishReason.safety.userDescription
        XCTAssertTrue(
            desc.lowercased().contains("safety"),
            "Safety description should mention safety, got: \(desc)"
        )
    }

    func testUserDescription_NoImage_ContainsHelpfulGuidance() {
        let desc = GeminiFinishReason.noImage.userDescription
        // The noImage description includes guidance to rephrase or use different model
        XCTAssertTrue(desc.contains("prompt") || desc.contains("model"))
    }

    func testUserDescription_AllCases_NonEmpty() {
        for reason in GeminiFinishReason.allCases {
            XCTAssertFalse(
                reason.userDescription.isEmpty,
                "\(reason) should have non-empty userDescription"
            )
        }
    }

    func testUserDescription_AllCases_MinimumLength() {
        // Descriptions should be at least 20 chars (meaningful sentences)
        for reason in GeminiFinishReason.allCases {
            XCTAssertGreaterThan(
                reason.userDescription.count, 20,
                "\(reason) description is too short: \(reason.userDescription)"
            )
        }
    }

    // MARK: - from() Factory Method Tests

    func testFrom_STOP_ReturnsStop() {
        XCTAssertEqual(GeminiFinishReason.from("STOP"), .stop)
    }

    func testFrom_SAFETY_ReturnsSafety() {
        XCTAssertEqual(GeminiFinishReason.from("SAFETY"), .safety)
    }

    func testFrom_MAX_TOKENS_ReturnsMaxTokens() {
        XCTAssertEqual(GeminiFinishReason.from("MAX_TOKENS"), .maxTokens)
    }

    func testFrom_IMAGE_SAFETY_ReturnsImageSafety() {
        XCTAssertEqual(GeminiFinishReason.from("IMAGE_SAFETY"), .imageSafety)
    }

    func testFrom_NO_IMAGE_ReturnsNoImage() {
        XCTAssertEqual(GeminiFinishReason.from("NO_IMAGE"), .noImage)
    }

    func testFrom_Nil_ReturnsNil() {
        XCTAssertNil(GeminiFinishReason.from(nil))
    }

    func testFrom_UnknownString_ReturnsNil() {
        XCTAssertNil(GeminiFinishReason.from("UNKNOWN_VALUE"))
    }

    func testFrom_EmptyString_ReturnsNil() {
        XCTAssertNil(GeminiFinishReason.from(""))
    }

    func testFrom_AllRawValues_RoundTrip() {
        // Every case's rawValue should round-trip through from()
        for reason in GeminiFinishReason.allCases {
            let parsed = GeminiFinishReason.from(reason.rawValue)
            XCTAssertEqual(parsed, reason, "from(\(reason.rawValue)) should return \(reason)")
        }
    }
}
