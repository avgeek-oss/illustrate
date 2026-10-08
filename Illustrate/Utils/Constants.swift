// MARK: - Constants.swift

// Application-wide constants and configuration values.
//
// This file contains constants used throughout the application,
// particularly for Keychain access and team identification.
//
// ## Keychain Access
// The app uses a shared keychain access group to securely store
// API keys across the app and any related extensions. The access
// group format follows Apple's requirements: {TeamID}.{BundleID}.{GroupName}

import Foundation
import SwiftUI

extension UUID: @retroactive Identifiable {
    public var id: UUID {
        self
    }
}

struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: PlatformImage
}

struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String
}

/// Apple Developer Team ID for keychain access group configuration.
/// This must match the team ID in your Apple Developer account.
let TEAM_ID = Bundle.main.object(forInfoDictionaryKey: "IllustrateDevelopmentTeam") as? String ?? "6JTT6685LT"

/// Keychain access group identifier for shared item storage.
/// Uses the format: {TeamID}.{BundleIdentifier}.SharedItems
/// This allows API keys to be securely stored and accessed across
/// the main app and any extensions sharing this access group.
var TEAM_KEYCHAIN_AG = "\(TEAM_ID).\(Bundle.main.bundleIdentifier ?? "so.illustrate").SharedItems"

/// Support email address for user feedback and inquiries.
let SUPPORT_EMAIL = "support@avgeek.ltd"

/// Base URL for the Illustrate help website.
let HELP_WEBSITE_URL = "https://illustrate.so"

/// URL for the privacy policy page.
let PRIVACY_URL = "\(HELP_WEBSITE_URL)/docs/privacy"
