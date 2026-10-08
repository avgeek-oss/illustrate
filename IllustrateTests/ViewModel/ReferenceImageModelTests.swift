// MARK: - ReferenceImageModelTests.swift

// Extended tests for ReferenceImage and VideoTransferable structs.
//
// BaseViewModelTests covers: ReferenceImage init (1), customId (1),
// identifiable (1), mutableReferenceType (1).
//
// This file adds: VideoTransferable struct (completely untested),
// ReferenceImage reference type variations, image preservation,
// id mutability, and struct value semantics.

import XCTest
@testable import Illustrate

final class ReferenceImageModelTests: XCTestCase {
    // MARK: - Helpers

    private func makePlatformImage() -> PlatformImage {
        #if os(macOS)
        return NSImage(size: NSSize(width: 100, height: 100))
        #else
        return UIImage()
        #endif
    }

    // MARK: - ReferenceImage Reference Type Variations

    func testReferenceImage_styleType() {
        let ref = ReferenceImage(image: makePlatformImage(), referenceType: "style")
        XCTAssertEqual(ref.referenceType, "style")
    }

    func testReferenceImage_subjectType() {
        let ref = ReferenceImage(image: makePlatformImage(), referenceType: "subject")
        XCTAssertEqual(ref.referenceType, "subject")
    }

    func testReferenceImage_emptyReferenceType() {
        let ref = ReferenceImage(image: makePlatformImage(), referenceType: "")
        XCTAssertEqual(ref.referenceType, "")
    }

    func testReferenceImage_customReferenceType() {
        let ref = ReferenceImage(image: makePlatformImage(), referenceType: "face_swap")
        XCTAssertEqual(ref.referenceType, "face_swap")
    }

    // MARK: - ReferenceImage Image Preservation

    func testReferenceImage_imageIsStored() {
        let image = makePlatformImage()
        let ref = ReferenceImage(image: image, referenceType: "style")
        XCTAssertNotNil(ref.image)
    }

    // MARK: - ReferenceImage ID Behavior

    func testReferenceImage_defaultIdIsUUID() {
        let ref = ReferenceImage(image: makePlatformImage(), referenceType: "style")
        XCTAssertFalse(ref.id.uuidString.isEmpty)
    }

    func testReferenceImage_customIdPreserved() {
        let customId = UUID()
        let ref = ReferenceImage(id: customId, image: makePlatformImage(), referenceType: "style")
        XCTAssertEqual(ref.id, customId)
    }

    func testReferenceImage_twoInstancesHaveDifferentIds() {
        let image = makePlatformImage()
        let ref1 = ReferenceImage(image: image, referenceType: "style")
        let ref2 = ReferenceImage(image: image, referenceType: "style")
        XCTAssertNotEqual(ref1.id, ref2.id)
    }

    func testReferenceImage_idIsMutable() {
        var ref = ReferenceImage(image: makePlatformImage(), referenceType: "style")
        let newId = UUID()
        ref.id = newId
        XCTAssertEqual(ref.id, newId)
    }

    // MARK: - ReferenceImage Value Semantics

    func testReferenceImage_copyHasIndependentReferenceType() {
        let original = ReferenceImage(image: makePlatformImage(), referenceType: "style")
        var copy = original
        copy.referenceType = "subject"

        XCTAssertEqual(original.referenceType, "style")
        XCTAssertEqual(copy.referenceType, "subject")
    }

    func testReferenceImage_copyHasIndependentId() {
        let original = ReferenceImage(image: makePlatformImage(), referenceType: "style")
        var copy = original
        let newId = UUID()
        copy.id = newId

        XCTAssertNotEqual(original.id, newId)
        XCTAssertEqual(copy.id, newId)
    }

    // MARK: - VideoTransferable

    func testVideoTransferable_initWithData() {
        let data = Data([0x00, 0x01, 0x02, 0x03])
        let transferable = VideoTransferable(data: data)
        XCTAssertEqual(transferable.data, data)
    }

    func testVideoTransferable_emptyData() {
        let transferable = VideoTransferable(data: Data())
        XCTAssertTrue(transferable.data.isEmpty)
    }

    func testVideoTransferable_largeData() {
        let data = Data(repeating: 0xFF, count: 1024 * 1024)
        let transferable = VideoTransferable(data: data)
        XCTAssertEqual(transferable.data.count, 1024 * 1024)
    }

    func testVideoTransferable_dataPreservesContent() {
        let bytes: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
        let data = Data(bytes)
        let transferable = VideoTransferable(data: data)
        XCTAssertEqual(Array(transferable.data), bytes)
    }

    func testVideoTransferable_differentInstancesIndependent() {
        let data1 = Data([0x01, 0x02])
        let data2 = Data([0x03, 0x04])
        let t1 = VideoTransferable(data: data1)
        let t2 = VideoTransferable(data: data2)

        XCTAssertNotEqual(t1.data, t2.data)
    }
}
