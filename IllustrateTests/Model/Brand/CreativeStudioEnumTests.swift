// MARK: - CreativeStudioEnumTests.swift

// Tests for CreativeStudio enums and model configuration.
//
// Tests cover:
// - CreativeAssetType: 7 cases — displayName, promptDescription, icon, Codable
// - CreativeStudio model: savedConfiguration round-trip, Codable encode/decode

import XCTest
@testable import Illustrate

// MARK: - CreativeAssetType Tests

final class CreativeAssetTypeTests: XCTestCase {
    // MARK: - Display Names

    func testDisplayName_GeneralPurpose() {
        XCTAssertEqual(CreativeAssetType.generalPurpose.displayName, "General Purpose")
    }

    func testDisplayName_Poster() {
        XCTAssertEqual(CreativeAssetType.poster.displayName, "Poster")
    }

    func testDisplayName_SocialMediaPost() {
        XCTAssertEqual(CreativeAssetType.socialMediaPost.displayName, "Social Media Post")
    }

    func testDisplayName_BusinessCard() {
        XCTAssertEqual(CreativeAssetType.businessCard.displayName, "Business Card")
    }

    func testAllCases_HaveNonEmptyDisplayName() {
        for assetType in CreativeAssetType.allCases {
            XCTAssertFalse(assetType.displayName.isEmpty, "\(assetType) should have a non-empty display name")
        }
    }

    // MARK: - Prompt Descriptions

    func testPromptDescription_GeneralPurpose_ReturnsBrandAsset() {
        XCTAssertEqual(CreativeAssetType.generalPurpose.promptDescription, "brand asset")
    }

    func testPromptDescription_SocialMediaPost_ReturnsSocialMediaPost() {
        XCTAssertEqual(CreativeAssetType.socialMediaPost.promptDescription, "social media post")
    }

    func testPromptDescription_BusinessCard_ReturnsBusinessCardDesign() {
        XCTAssertEqual(CreativeAssetType.businessCard.promptDescription, "business card design")
    }

    func testPromptDescription_Poster_ReturnsPromotionalPoster() {
        XCTAssertEqual(CreativeAssetType.poster.promptDescription, "promotional poster")
    }

    func testPromptDescription_AllCases_AreNonEmpty() {
        for assetType in CreativeAssetType.allCases {
            XCTAssertFalse(
                assetType.promptDescription.isEmpty,
                "\(assetType) should have a non-empty prompt description"
            )
        }
    }

    func testPromptDescription_AllCases_AreLowercase() {
        for assetType in CreativeAssetType.allCases {
            let desc = assetType.promptDescription
            XCTAssertEqual(
                desc,
                desc.lowercased(),
                "\(assetType) prompt description should be lowercase for prompt injection"
            )
        }
    }

    // MARK: - Icons

    func testIcon_GeneralPurpose_ReturnsSparkles() {
        XCTAssertEqual(CreativeAssetType.generalPurpose.icon, "sparkles")
    }

    func testIcon_BusinessCard_ReturnsRectangleOnRectangle() {
        XCTAssertEqual(CreativeAssetType.businessCard.icon, "rectangle.on.rectangle")
    }

    func testIcon_Poster_ReturnsRectanglePortrait() {
        XCTAssertEqual(CreativeAssetType.poster.icon, "rectangle.portrait")
    }

    func testIcon_Invitation_ReturnsEnvelope() {
        XCTAssertEqual(CreativeAssetType.invitation.icon, "envelope")
    }

    func testAllCases_HaveNonEmptyIcon() {
        for assetType in CreativeAssetType.allCases {
            XCTAssertFalse(assetType.icon.isEmpty, "\(assetType) should have a non-empty icon")
        }
    }

    func testAllIcons_AreDistinct() {
        let icons = CreativeAssetType.allCases.map(\.icon)
        XCTAssertEqual(Set(icons).count, icons.count, "All asset type icons should be unique")
    }

    // MARK: - RawValue & Identity

    func testRawValue_GeneralPurpose_EqualsGeneralPurposeString() {
        XCTAssertEqual(CreativeAssetType.generalPurpose.rawValue, "general_purpose")
    }

    func testRawValue_SocialMediaPost_EqualsSocialMediaPostString() {
        XCTAssertEqual(CreativeAssetType.socialMediaPost.rawValue, "social_media_post")
    }

    func testRawValue_BusinessCard_EqualsBusinessCardString() {
        XCTAssertEqual(CreativeAssetType.businessCard.rawValue, "business_card")
    }

    func testRawValue_RoundTrip_AllCases() {
        for assetType in CreativeAssetType.allCases {
            let restored = CreativeAssetType(rawValue: assetType.rawValue)
            XCTAssertEqual(restored, assetType, "RawValue round-trip failed for \(assetType)")
        }
    }

    func testId_MatchesRawValue_AllCases() {
        for assetType in CreativeAssetType.allCases {
            XCTAssertEqual(assetType.id, assetType.rawValue, "id should match rawValue for \(assetType)")
        }
    }

    func testAllCasesCount_IsSeven() {
        XCTAssertEqual(CreativeAssetType.allCases.count, 7)
    }

    // MARK: - Codable

    func testCodable_RoundTrip_AllCases() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for assetType in CreativeAssetType.allCases {
            let data = try encoder.encode(assetType)
            let restored = try decoder.decode(CreativeAssetType.self, from: data)
            XCTAssertEqual(restored, assetType, "Codable round-trip failed for \(assetType)")
        }
    }

    // MARK: - Display Name Formatting

    func testAllDisplayNames_AreUnique() {
        let names = CreativeAssetType.allCases.map(\.displayName)
        XCTAssertEqual(Set(names).count, names.count, "All display names should be unique")
    }

    func testAllDisplayNames_StartWithUppercase() throws {
        for assetType in CreativeAssetType.allCases {
            let name = assetType.displayName
            let firstChar = try XCTUnwrap(name.first)
            XCTAssertTrue(firstChar.isUppercase, "\(assetType) display name should start with uppercase")
        }
    }
}

// MARK: - CreativeStudio Model Tests

final class CreativeStudioModelTests: XCTestCase {
    // MARK: - Initialization

    func testInit_DefaultValues() {
        let studio = CreativeStudio()
        XCTAssertEqual(studio.selectedProviderId, "")
        XCTAssertEqual(studio.selectedModelId, "")
        XCTAssertNil(studio.configurationData)
    }

    func testInit_CustomProjectId() {
        let projectId = UUID()
        let studio = CreativeStudio(projectId: projectId)
        XCTAssertEqual(studio.projectId, projectId)
    }

    // MARK: - Saved Configuration

    func testSavedConfiguration_NilData_ReturnsDefault() {
        let studio = CreativeStudio()
        let config = studio.savedConfiguration
        // Default ImageGenerationConfiguration should be returned
        XCTAssertNotNil(config)
    }

    func testSavedConfiguration_SetAndGet_RoundTrip() {
        let studio = CreativeStudio()
        var config = ImageGenerationConfiguration()
        config.prompt = "test prompt"
        studio.savedConfiguration = config

        let restored = studio.savedConfiguration
        XCTAssertEqual(restored.prompt, "test prompt")
    }

    func testSavedConfiguration_CorruptedData_ReturnsDefault() {
        let studio = CreativeStudio()
        studio.configurationData = Data([0xFF, 0xFE, 0x00]) // Invalid JSON
        let config = studio.savedConfiguration
        // Should return default instead of crashing
        XCTAssertNotNil(config)
    }

    // MARK: - Codable

    func testCodable_RoundTrip_PreservesAllFields() throws {
        let projectId = UUID()
        let studio = CreativeStudio(projectId: projectId)
        studio.selectedProviderId = "provider-123"
        studio.selectedModelId = "model-456"

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(studio)
        let restored = try decoder.decode(CreativeStudio.self, from: data)

        XCTAssertEqual(restored.id, studio.id)
        XCTAssertEqual(restored.projectId, projectId)
        XCTAssertEqual(restored.selectedProviderId, "provider-123")
        XCTAssertEqual(restored.selectedModelId, "model-456")
    }

    func testCodable_MissingOptionalFields_DefaultsCorrectly() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "createdAt": Date().timeIntervalSinceReferenceDate,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        let restored = try decoder.decode(CreativeStudio.self, from: data)

        XCTAssertEqual(restored.selectedProviderId, "")
        XCTAssertEqual(restored.selectedModelId, "")
        XCTAssertNil(restored.configurationData)
    }
}
