// MARK: - PhotoshootDimensionExtensionTests.swift

// Tests for PhotoshootDimension extension in PodiumBackdropsManager.
// Covers podiumFolderName and backdropDownloadDescription for all 6 dimensions.

import XCTest
@testable import Illustrate

final class PhotoshootDimensionExtensionTests: XCTestCase {
    // MARK: - podiumFolderName

    func testPodiumFolderName_Portrait9x16() {
        XCTAssertEqual(PhotoshootDimension.portrait9x16.podiumFolderName, "9_16")
    }

    func testPodiumFolderName_Landscape16x9() {
        XCTAssertEqual(PhotoshootDimension.landscape16x9.podiumFolderName, "16_9")
    }

    func testPodiumFolderName_Portrait3x4() {
        XCTAssertEqual(PhotoshootDimension.portrait3x4.podiumFolderName, "3_4")
    }

    func testPodiumFolderName_Landscape4x3() {
        XCTAssertEqual(PhotoshootDimension.landscape4x3.podiumFolderName, "4_3")
    }

    func testPodiumFolderName_Portrait2x3() {
        XCTAssertEqual(PhotoshootDimension.portrait2x3.podiumFolderName, "2_3")
    }

    func testPodiumFolderName_Landscape3x2() {
        XCTAssertEqual(PhotoshootDimension.landscape3x2.podiumFolderName, "3_2")
    }

    // MARK: - backdropDownloadDescription

    func testBackdropDownloadDescription_ContainsRawValue() {
        for dimension in PhotoshootDimension.allCases {
            XCTAssertTrue(
                dimension.backdropDownloadDescription.contains(dimension.rawValue),
                "\(dimension) description should contain its rawValue '\(dimension.rawValue)'"
            )
        }
    }

    func testBackdropDownloadDescription_NonEmpty() {
        for dimension in PhotoshootDimension.allCases {
            XCTAssertFalse(dimension.backdropDownloadDescription.isEmpty)
        }
    }

    func testBackdropDownloadDescription_ContainsDownload() {
        for dimension in PhotoshootDimension.allCases {
            XCTAssertTrue(
                dimension.backdropDownloadDescription.contains("Download"),
                "\(dimension) description should contain 'Download'"
            )
        }
    }

    func testBackdropDownloadDescription_ContainsAspectRatios() {
        for dimension in PhotoshootDimension.allCases {
            XCTAssertTrue(
                dimension.backdropDownloadDescription.contains("aspect ratios"),
                "\(dimension) description should contain 'aspect ratios'"
            )
        }
    }

    // MARK: - Consistency Checks

    func testPodiumFolderName_AllUnique() {
        let folderNames = PhotoshootDimension.allCases.map(\.podiumFolderName)
        let uniqueNames = Set(folderNames)
        XCTAssertEqual(folderNames.count, uniqueNames.count, "All folder names should be unique")
    }

    func testPodiumFolderName_NoneEmpty() {
        for dimension in PhotoshootDimension.allCases {
            XCTAssertFalse(
                dimension.podiumFolderName.isEmpty,
                "\(dimension) folder name should not be empty"
            )
        }
    }

    func testPodiumFolderName_MatchesDigitUnderscoreDigitPattern() {
        for dimension in PhotoshootDimension.allCases {
            let name = dimension.podiumFolderName
            XCTAssertTrue(
                name.contains("_"),
                "\(dimension) folder name '\(name)' should contain underscore"
            )
            let parts = name.split(separator: "_")
            XCTAssertEqual(parts.count, 2, "\(dimension) folder name '\(name)' should have exactly 2 parts")
            XCTAssertNotNil(Int(parts[0]), "First part of '\(name)' should be numeric")
            XCTAssertNotNil(Int(parts[1]), "Second part of '\(name)' should be numeric")
        }
    }

    func testPodiumFolderName_AllCasesCount() {
        XCTAssertEqual(PhotoshootDimension.allCases.count, 6)
    }
}
