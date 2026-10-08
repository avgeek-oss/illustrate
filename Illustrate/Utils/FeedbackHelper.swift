// MARK: - FeedbackHelper.swift

import Foundation
import OSLog

/// Constructs a mailto URL for user feedback with pre-filled subject and body.
///
/// Opens the user's default email client with a template for submitting feedback.
/// Falls back to the help website URL if mailto URL creation fails.
///
/// - Returns: URL for feedback email or fallback website
func getFeedbackLink() -> URL {
    let subject = "Illustrate application feedback"
    let body =
        "Hey team,\n\nI have some feedback about the application.\n\n[Add your feedback and relevant information that could help]\n\nThanks,\n[Your name]"

    let urlString =
        "mailto:\(SUPPORT_EMAIL)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

    guard let url = URL(string: urlString) else {
        AppLogger.app.error("Failed to create URL from string")
        return URL(string: HELP_WEBSITE_URL)!
    }

    return url
}
