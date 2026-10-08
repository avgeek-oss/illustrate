// MARK: - ImageFileIOTests.swift

// Tests for image file IO: saveImageToDocumentsDirectory,
// loadImageFromDocumentsDirectory, getImageSizeInBytes,
// toPlatformImage(base64:), and round-trip workflows.
//
// Covers:
// - Save and load from Documents directory
// - File size checking
// - Base64 to PlatformImage conversion
// - Full round-trip: save → load → base64 → restore

import AppKit
import CoreGraphics
import XCTest
@testable import Illustrate

final class ImageFileIOTests: XCTestCase {
    // MARK: - Helpers

    private var testFileNames: [String] = []

    override func tearDown() {
        super.tearDown()
        let fm = FileManager.default
        let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        for name in testFileNames {
            let url = docsURL.appendingPathComponent("\(name).png")
            try? fm.removeItem(at: url)
        }
        testFileNames.removeAll()
    }

    private func makeNSImage(width: Int, height: Int, r: UInt8 = 128, g: UInt8 = 128, b: UInt8 = 128) -> NSImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        for i in 0 ..< (width * height) {
            pixelData[i * 4] = r
            pixelData[i * 4 + 1] = g
            pixelData[i * 4 + 2] = b
            pixelData[i * 4 + 3] = 255
        }
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * bytesPerPixel,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImage = context.makeImage() else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    private func uniqueName() -> String {
        let name = "test_io_\(UUID().uuidString)"
        testFileNames.append(name)
        return name
    }

    // MARK: - saveImageToDocumentsDirectory

    func testSave_validData_returnsURL() {
        let name = uniqueName()
        let data = Data(repeating: 0xFF, count: 10)
        let url = saveImageToDocumentsDirectory(imageData: data, withName: name)
        XCTAssertNotNil(url)
    }

    func testSave_returnedURL_hasCorrectFileName() {
        let name = uniqueName()
        let data = Data(repeating: 0xFF, count: 10)
        let url = saveImageToDocumentsDirectory(imageData: data, withName: name)
        XCTAssertTrue(url?.lastPathComponent.hasSuffix(".png") ?? false)
    }

    func testSave_returnedURL_fileExists() {
        let name = uniqueName()
        let data = Data(repeating: 0xFF, count: 10)
        guard let url = saveImageToDocumentsDirectory(imageData: data, withName: name) else {
            return XCTFail("Save returned nil")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testSave_dataAtURL_matchesOriginal() {
        let name = uniqueName()
        let data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        guard let url = saveImageToDocumentsDirectory(imageData: data, withName: name) else {
            return XCTFail("Save returned nil")
        }
        let loadedData = try? Data(contentsOf: url)
        XCTAssertEqual(loadedData, data)
    }

    func testSave_overwrite_existingFile_succeeds() {
        let name = uniqueName()
        let data1 = Data(repeating: 0xAA, count: 10)
        let data2 = Data(repeating: 0xBB, count: 20)
        _ = saveImageToDocumentsDirectory(imageData: data1, withName: name)
        guard let url = saveImageToDocumentsDirectory(imageData: data2, withName: name) else {
            return XCTFail("Overwrite returned nil")
        }
        let loadedData = try? Data(contentsOf: url)
        XCTAssertEqual(loadedData, data2)
    }

    func testSave_uniqueNames_createSeparateFiles() {
        let name1 = uniqueName()
        let name2 = uniqueName()
        let data1 = Data(repeating: 0xAA, count: 5)
        let data2 = Data(repeating: 0xBB, count: 10)
        let url1 = saveImageToDocumentsDirectory(imageData: data1, withName: name1)
        let url2 = saveImageToDocumentsDirectory(imageData: data2, withName: name2)
        XCTAssertNotNil(url1)
        XCTAssertNotNil(url2)
        XCTAssertNotEqual(url1, url2)
    }

    func testSave_emptyData_savesEmptyFile() {
        let name = uniqueName()
        let data = Data()
        guard let url = saveImageToDocumentsDirectory(imageData: data, withName: name) else {
            return XCTFail("Save returned nil")
        }
        let loadedData = try? Data(contentsOf: url)
        XCTAssertEqual(loadedData?.count, 0)
    }

    // MARK: - loadImageFromDocumentsDirectory

    func testLoad_existingFile_returnsImage() {
        let name = uniqueName()
        guard let image = makeNSImage(width: 20, height: 20),
              let pngData = image.toPNGData(),
              saveImageToDocumentsDirectory(imageData: pngData, withName: name) != nil
        else {
            return XCTFail("Could not save test image")
        }
        let loaded = loadImageFromDocumentsDirectory(withName: name)
        XCTAssertNotNil(loaded)
    }

    func testLoad_nonExistentFile_returnsNil() {
        let loaded = loadImageFromDocumentsDirectory(withName: "nonexistent_\(UUID().uuidString)")
        XCTAssertNil(loaded)
    }

    func testLoad_corruptData_returnsNil() {
        let name = uniqueName()
        let corruptData = Data([0x00, 0x01, 0x02, 0x03])
        _ = saveImageToDocumentsDirectory(imageData: corruptData, withName: name)
        let loaded = loadImageFromDocumentsDirectory(withName: name)
        XCTAssertNil(loaded)
    }

    // MARK: - Save + Load Round-Trip

    func testRoundTrip_saveAndLoad_producesImage() {
        let name = uniqueName()
        guard let image = makeNSImage(width: 50, height: 50),
              let pngData = image.toPNGData(),
              saveImageToDocumentsDirectory(imageData: pngData, withName: name) != nil
        else {
            return XCTFail("Could not save test image")
        }
        let loaded = loadImageFromDocumentsDirectory(withName: name)
        XCTAssertNotNil(loaded)
    }

    func testRoundTrip_savedImage_pixelCountMatches() {
        let name = uniqueName()
        guard let image = makeNSImage(width: 30, height: 40),
              let pngData = image.toPNGData(),
              saveImageToDocumentsDirectory(imageData: pngData, withName: name) != nil
        else {
            return XCTFail("Could not save test image")
        }
        guard let loaded = loadImageFromDocumentsDirectory(withName: name) else {
            return XCTFail("Could not load image")
        }
        XCTAssertEqual(loaded.pixelCount, image.pixelCount)
    }

    func testRoundTrip_savedImage_pixelSizeMatches() {
        let name = uniqueName()
        guard let image = makeNSImage(width: 30, height: 40),
              let pngData = image.toPNGData(),
              saveImageToDocumentsDirectory(imageData: pngData, withName: name) != nil
        else {
            return XCTFail("Could not save test image")
        }
        guard let loaded = loadImageFromDocumentsDirectory(withName: name) else {
            return XCTFail("Could not load image")
        }
        XCTAssertEqual(loaded.pixelSize.width, 30)
        XCTAssertEqual(loaded.pixelSize.height, 40)
    }

    func testRoundTrip_multipleImages_allRoundTrip() {
        let sizes: [(Int, Int)] = [(10, 10), (50, 30), (100, 200)]
        for (w, h) in sizes {
            let name = uniqueName()
            guard let image = makeNSImage(width: w, height: h),
                  let pngData = image.toPNGData(),
                  saveImageToDocumentsDirectory(imageData: pngData, withName: name) != nil
            else {
                XCTFail("Could not save \(w)x\(h) image")
                continue
            }
            let loaded = loadImageFromDocumentsDirectory(withName: name)
            XCTAssertNotNil(loaded, "Failed to load \(w)x\(h) image")
        }
    }

    func testRoundTrip_saveLoad_thenConvertToBase64() {
        let name = uniqueName()
        guard let image = makeNSImage(width: 20, height: 20),
              let pngData = image.toPNGData(),
              saveImageToDocumentsDirectory(imageData: pngData, withName: name) != nil
        else {
            return XCTFail("Could not save test image")
        }
        guard let loaded = loadImageFromDocumentsDirectory(withName: name) else {
            return XCTFail("Could not load image")
        }
        XCTAssertNotNil(loaded.toBase64PNG())
    }

    // MARK: - getImageSizeInBytes

    func testGetImageSizeInBytes_validURL_returnsPositive() throws {
        let name = uniqueName()
        guard let image = makeNSImage(width: 50, height: 50),
              let pngData = image.toPNGData(),
              let url = saveImageToDocumentsDirectory(imageData: pngData, withName: name)
        else {
            return XCTFail("Could not save test image")
        }
        let size = getImageSizeInBytes(imageURL: url)
        XCTAssertNotNil(size)
        XCTAssertGreaterThan(try XCTUnwrap(size), 0)
    }

    func testGetImageSizeInBytes_invalidURL_returnsNil() {
        let url = URL(fileURLWithPath: "/nonexistent/path/image.png")
        let size = getImageSizeInBytes(imageURL: url)
        XCTAssertNil(size)
    }

    func testGetImageSizeInBytes_matchesActualDataCount() {
        let name = uniqueName()
        guard let image = makeNSImage(width: 30, height: 30),
              let pngData = image.toPNGData(),
              let url = saveImageToDocumentsDirectory(imageData: pngData, withName: name)
        else {
            return XCTFail("Could not save test image")
        }
        let size = getImageSizeInBytes(imageURL: url)
        XCTAssertEqual(size, pngData.count)
    }

    func testGetImageSizeInBytes_largerImage_largerSize() {
        let name1 = uniqueName()
        let name2 = uniqueName()
        guard let small = makeNSImage(width: 10, height: 10),
              let large = makeNSImage(width: 100, height: 100),
              let smallData = small.toPNGData(),
              let largeData = large.toPNGData(),
              let url1 = saveImageToDocumentsDirectory(imageData: smallData, withName: name1),
              let url2 = saveImageToDocumentsDirectory(imageData: largeData, withName: name2)
        else {
            return XCTFail("Could not save images")
        }
        let size1 = getImageSizeInBytes(imageURL: url1) ?? 0
        let size2 = getImageSizeInBytes(imageURL: url2) ?? 0
        XCTAssertLessThan(size1, size2)
    }

    // MARK: - toPlatformImage(base64:)

    func testToPlatformImage_validPNGBase64_returnsImage() {
        guard let image = makeNSImage(width: 10, height: 10),
              let base64 = image.toBase64PNG()
        else {
            return XCTFail("Could not create base64 PNG")
        }
        let result = toPlatformImage(base64: base64)
        XCTAssertNotNil(result)
    }

    func testToPlatformImage_validJPEGBase64_returnsImage() {
        guard let image = makeNSImage(width: 10, height: 10),
              let base64 = image.toBase64JPEG()
        else {
            return XCTFail("Could not create base64 JPEG")
        }
        let result = toPlatformImage(base64: base64)
        XCTAssertNotNil(result)
    }

    func testToPlatformImage_invalidBase64_returnsNil() {
        let result = toPlatformImage(base64: "not_valid_base64!!!")
        XCTAssertNil(result)
    }

    func testToPlatformImage_emptyString_returnsNil() {
        let result = toPlatformImage(base64: "")
        XCTAssertNil(result)
    }

    func testToPlatformImage_validBase64ButNotImage_returnsNil() {
        let base64 = Data("Hello World".utf8).base64EncodedString()
        let result = toPlatformImage(base64: base64)
        XCTAssertNil(result)
    }

    // MARK: - Base64 Full Round-Trip Workflows

    func testBase64RoundTrip_png_imageToBase64ToImage() {
        guard let original = makeNSImage(width: 20, height: 20),
              let base64 = original.toBase64PNG()
        else {
            return XCTFail("Could not create base64 PNG")
        }
        let restored = toPlatformImage(base64: base64)
        XCTAssertNotNil(restored)
    }

    func testBase64RoundTrip_jpeg_imageToBase64ToImage() {
        guard let original = makeNSImage(width: 20, height: 20),
              let base64 = original.toBase64JPEG()
        else {
            return XCTFail("Could not create base64 JPEG")
        }
        let restored = toPlatformImage(base64: base64)
        XCTAssertNotNil(restored)
    }

    func testBase64RoundTrip_preservesDimensions() {
        guard let original = makeNSImage(width: 30, height: 40),
              let base64 = original.toBase64PNG(),
              let restored = toPlatformImage(base64: base64)
        else {
            return XCTFail("Could not create or restore image")
        }
        XCTAssertEqual(restored.pixelSize.width, 30)
        XCTAssertEqual(restored.pixelSize.height, 40)
    }

    func testBase64RoundTrip_multipleImages_allSucceed() {
        let sizes: [(Int, Int)] = [(10, 10), (50, 30), (100, 200)]
        for (w, h) in sizes {
            guard let image = makeNSImage(width: w, height: h),
                  let base64 = image.toBase64PNG(),
                  let restored = toPlatformImage(base64: base64)
            else {
                XCTFail("Round-trip failed for \(w)x\(h)")
                continue
            }
            XCTAssertEqual(restored.pixelCount, w * h, "Pixel count mismatch for \(w)x\(h)")
        }
    }

    func testBase64RoundTrip_saveThenLoadThenBase64ThenRestore() {
        let name = uniqueName()
        guard let image = makeNSImage(width: 25, height: 25),
              let pngData = image.toPNGData(),
              saveImageToDocumentsDirectory(imageData: pngData, withName: name) != nil
        else {
            return XCTFail("Could not save test image")
        }
        guard let loaded = loadImageFromDocumentsDirectory(withName: name),
              let base64 = loaded.toBase64PNG(),
              let restored = toPlatformImage(base64: base64)
        else {
            return XCTFail("Could not complete round-trip")
        }
        XCTAssertEqual(restored.pixelCount, 25 * 25)
    }
}
