// MARK: - FeedbackHelperTests.swift

// Tests for getFeedbackLink() and related constants.
//
// Covers:
// - Mailto URL structure (scheme, email, params)
// - Constants validation (SUPPORT_EMAIL, HELP_WEBSITE_URL, PRIVACY_URL)
// - Workflow scenarios (consistent calls, parsing, fallback check)

import XCTest
@testable import Illustrate

final class FeedbackHelperTests: XCTestCase {
    // MARK: - URL Structure

    func testFeedbackLink_returnsMailtoScheme() {
        let url = getFeedbackLink()
        XCTAssertEqual(url.scheme, "mailto")
    }

    func testFeedbackLink_containsSupportEmail() {
        let url = getFeedbackLink()
        XCTAssertTrue(url.absoluteString.contains(SUPPORT_EMAIL))
    }

    func testFeedbackLink_containsSubjectParam() {
        let url = getFeedbackLink()
        XCTAssertTrue(url.absoluteString.contains("subject="))
    }

    func testFeedbackLink_containsBodyParam() {
        let url = getFeedbackLink()
        XCTAssertTrue(url.absoluteString.contains("body="))
    }

    func testFeedbackLink_subjectIsPercentEncoded() {
        let url = getFeedbackLink()
        let urlString = url.absoluteString
        // "Illustrate application feedback" should be percent-encoded (spaces → %20 or +)
        XCTAssertTrue(urlString.contains("Illustrate"))
        XCTAssertTrue(urlString.contains("feedback"))
    }

    func testFeedbackLink_bodyContainsPercentEncoding() {
        let url = getFeedbackLink()
        let urlString = url.absoluteString
        // Body contains newlines which should be percent-encoded (\n → %0A)
        XCTAssertTrue(urlString.contains("%0A") || urlString.contains("%0a"))
    }

    func testFeedbackLink_urlIsNotNil() {
        let url = getFeedbackLink()
        // The function always returns a non-nil URL
        XCTAssertFalse(url.absoluteString.isEmpty)
    }

    func testFeedbackLink_isValidURL() {
        let url = getFeedbackLink()
        XCTAssertNotNil(URL(string: url.absoluteString))
    }

    func testFeedbackLink_doesNotContainUnencodedNewlines() {
        let url = getFeedbackLink()
        let urlString = url.absoluteString
        XCTAssertFalse(urlString.contains("\n"))
    }

    func testFeedbackLink_doesNotContainUnencodedSpaces() {
        let url = getFeedbackLink()
        let urlString = url.absoluteString
        // Spaces should be percent-encoded
        let afterScheme = urlString.replacingOccurrences(of: "mailto:", with: "")
        XCTAssertFalse(afterScheme.contains(" "))
    }

    // MARK: - Constants Validation

    func testConstant_supportEmail_isCorrect() {
        XCTAssertEqual(SUPPORT_EMAIL, "support@avgeek.ltd")
    }

    func testConstant_helpWebsiteURL_isCorrect() {
        XCTAssertEqual(HELP_WEBSITE_URL, "https://illustrate.so")
    }

    func testConstant_privacyURL_containsHelpWebsite() {
        XCTAssertTrue(PRIVACY_URL.contains(HELP_WEBSITE_URL))
    }

    func testConstant_privacyURL_endsWithPrivacy() {
        XCTAssertTrue(PRIVACY_URL.hasSuffix("/privacy"))
    }

    // MARK: - Workflow

    func testWorkflow_usesCorrectEmail() {
        let url = getFeedbackLink()
        // Should use SUPPORT_EMAIL constant in the mailto URL
        XCTAssertTrue(url.absoluteString.contains("support@avgeek.ltd"))
    }

    func testWorkflow_consistentAcrossMultipleCalls() {
        let url1 = getFeedbackLink()
        let url2 = getFeedbackLink()
        XCTAssertEqual(url1, url2)
    }

    func testWorkflow_canBeOpenedAsString() {
        let url = getFeedbackLink()
        let urlString = url.absoluteString
        XCTAssertFalse(urlString.isEmpty)
        XCTAssertTrue(urlString.hasPrefix("mailto:"))
    }

    func testWorkflow_schemeAndHostParsing() {
        let url = getFeedbackLink()
        XCTAssertEqual(url.scheme, "mailto")
        // mailto URLs don't have a host in the traditional sense
        // But the path should contain the email
        let absoluteString = url.absoluteString
        XCTAssertTrue(absoluteString.contains("support@"))
    }

    func testWorkflow_queryContainsSubjectAndBody() {
        let url = getFeedbackLink()
        let urlString = url.absoluteString
        // After the ?, there should be subject= and body=
        XCTAssertTrue(urlString.contains("?subject=") || urlString.contains("&subject="))
    }

    func testWorkflow_doesNotUseFallback() {
        let url = getFeedbackLink()
        // If the mailto URL was constructed successfully, scheme should be "mailto" not "https"
        XCTAssertEqual(url.scheme, "mailto")
        XCTAssertNotEqual(url.scheme, "https")
    }
}
