// MARK: - VideoFileIOTests.swift

// Tests for video file IO: saveVideoToDocumentsDirectory,
// loadVideoUrlFromDocumentsDirectory, getVideoSizeInBytes,
// and round-trip workflows.
//
// Covers:
// - Save and load from Documents directory
// - File size checking
// - Full round-trip: save → load → verify data
// - Cross image/video IO independence

import XCTest
@testable import Illustrate

final class VideoFileIOTests: XCTestCase {
    // MARK: - Helpers

    private var testVideoNames: [String] = []
    private var testImageNames: [String] = []

    override func tearDown() {
        super.tearDown()
        let fm = FileManager.default
        let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        for name in testVideoNames {
            let url = docsURL.appendingPathComponent("\(name).mp4")
            try? fm.removeItem(at: url)
        }
        for name in testImageNames {
            let url = docsURL.appendingPathComponent("\(name).png")
            try? fm.removeItem(at: url)
        }
        testVideoNames.removeAll()
        testImageNames.removeAll()
    }

    private func uniqueVideoName() -> String {
        let name = "test_vid_\(UUID().uuidString)"
        testVideoNames.append(name)
        return name
    }

    private func uniqueImageName() -> String {
        let name = "test_img_\(UUID().uuidString)"
        testImageNames.append(name)
        return name
    }

    private func makeFakeVideoData(size: Int = 100) -> Data {
        Data(repeating: 0xAB, count: size)
    }

    // MARK: - saveVideoToDocumentsDirectory

    func testSaveVideo_validData_returnsURL() {
        let name = uniqueVideoName()
        let data = makeFakeVideoData()
        let url = saveVideoToDocumentsDirectory(videoData: data, withName: name)
        XCTAssertNotNil(url)
    }

    func testSaveVideo_returnedURL_containsMp4Extension() {
        let name = uniqueVideoName()
        let data = makeFakeVideoData()
        let url = saveVideoToDocumentsDirectory(videoData: data, withName: name)
        XCTAssertTrue(url?.lastPathComponent.hasSuffix(".mp4") ?? false)
    }

    func testSaveVideo_returnedURL_fileExists() {
        let name = uniqueVideoName()
        let data = makeFakeVideoData()
        guard let url = saveVideoToDocumentsDirectory(videoData: data, withName: name) else {
            return XCTFail("Save returned nil")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testSaveVideo_dataAtURL_matchesCount() {
        let name = uniqueVideoName()
        let data = makeFakeVideoData(size: 200)
        guard let url = saveVideoToDocumentsDirectory(videoData: data, withName: name) else {
            return XCTFail("Save returned nil")
        }
        let loadedData = try? Data(contentsOf: url)
        XCTAssertEqual(loadedData?.count, 200)
    }

    func testSaveVideo_overwrite_succeeds() {
        let name = uniqueVideoName()
        let data1 = makeFakeVideoData(size: 50)
        let data2 = makeFakeVideoData(size: 150)
        _ = saveVideoToDocumentsDirectory(videoData: data1, withName: name)
        guard let url = saveVideoToDocumentsDirectory(videoData: data2, withName: name) else {
            return XCTFail("Overwrite returned nil")
        }
        let loadedData = try? Data(contentsOf: url)
        XCTAssertEqual(loadedData?.count, 150)
    }

    func testSaveVideo_uniqueNames_separateFiles() {
        let name1 = uniqueVideoName()
        let name2 = uniqueVideoName()
        let url1 = saveVideoToDocumentsDirectory(videoData: makeFakeVideoData(), withName: name1)
        let url2 = saveVideoToDocumentsDirectory(videoData: makeFakeVideoData(), withName: name2)
        XCTAssertNotNil(url1)
        XCTAssertNotNil(url2)
        XCTAssertNotEqual(url1, url2)
    }

    func testSaveVideo_largeData_succeeds() {
        let name = uniqueVideoName()
        let data = Data(repeating: 0xCD, count: 100_000)
        let url = saveVideoToDocumentsDirectory(videoData: data, withName: name)
        XCTAssertNotNil(url)
    }

    // MARK: - loadVideoUrlFromDocumentsDirectory

    func testLoadVideo_existingFile_returnsURL() {
        let name = uniqueVideoName()
        _ = saveVideoToDocumentsDirectory(videoData: makeFakeVideoData(), withName: name)
        let url = loadVideoUrlFromDocumentsDirectory(withName: name)
        XCTAssertNotNil(url)
    }

    func testLoadVideo_nonExistentFile_returnsNil() {
        let url = loadVideoUrlFromDocumentsDirectory(withName: "nonexistent_\(UUID().uuidString)")
        XCTAssertNil(url)
    }

    func testLoadVideo_returnedURL_matchesSavedPath() {
        let name = uniqueVideoName()
        guard let savedURL = saveVideoToDocumentsDirectory(videoData: makeFakeVideoData(), withName: name) else {
            return XCTFail("Save returned nil")
        }
        let loadedURL = loadVideoUrlFromDocumentsDirectory(withName: name)
        XCTAssertEqual(savedURL.path, loadedURL?.path)
    }

    // MARK: - getVideoSizeInBytes

    func testGetVideoSizeInBytes_validURL_returnsPositive() {
        let name = uniqueVideoName()
        guard let url = saveVideoToDocumentsDirectory(videoData: makeFakeVideoData(size: 500), withName: name) else {
            return XCTFail("Save returned nil")
        }
        let size = getVideoSizeInBytes(videoURL: url)
        XCTAssertNotNil(size)
        XCTAssertEqual(size, 500)
    }

    func testGetVideoSizeInBytes_invalidURL_returnsNil() {
        let url = URL(fileURLWithPath: "/nonexistent/path/video.mp4")
        let size = getVideoSizeInBytes(videoURL: url)
        XCTAssertNil(size)
    }

    func testGetVideoSizeInBytes_matchesDataCount() {
        let name = uniqueVideoName()
        let data = makeFakeVideoData(size: 999)
        guard let url = saveVideoToDocumentsDirectory(videoData: data, withName: name) else {
            return XCTFail("Save returned nil")
        }
        let size = getVideoSizeInBytes(videoURL: url)
        XCTAssertEqual(size, 999)
    }

    // MARK: - Video Round-Trip Workflow

    func testVideoRoundTrip_saveAndLoad_returnsCorrectURL() {
        let name = uniqueVideoName()
        let data = makeFakeVideoData()
        guard saveVideoToDocumentsDirectory(videoData: data, withName: name) != nil else {
            return XCTFail("Save returned nil")
        }
        let url = loadVideoUrlFromDocumentsDirectory(withName: name)
        XCTAssertNotNil(url)
    }

    func testVideoRoundTrip_savedData_matchesOriginal() {
        let name = uniqueVideoName()
        let data = Data([0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70]) // fake mp4 header
        guard saveVideoToDocumentsDirectory(videoData: data, withName: name) != nil else {
            return XCTFail("Save returned nil")
        }
        guard let url = loadVideoUrlFromDocumentsDirectory(withName: name),
              let loadedData = try? Data(contentsOf: url)
        else {
            return XCTFail("Could not load video data")
        }
        XCTAssertEqual(loadedData, data)
    }

    func testVideoRoundTrip_multipleVideos_allRetrievable() {
        let names = (0 ..< 3).map { _ in uniqueVideoName() }
        for name in names {
            _ = saveVideoToDocumentsDirectory(videoData: makeFakeVideoData(), withName: name)
        }
        for name in names {
            XCTAssertNotNil(loadVideoUrlFromDocumentsDirectory(withName: name), "Failed to load \(name)")
        }
    }

    func testVideoRoundTrip_overwriteAndLoad_getsLatestData() {
        let name = uniqueVideoName()
        let data1 = Data(repeating: 0xAA, count: 50)
        let data2 = Data(repeating: 0xBB, count: 100)
        _ = saveVideoToDocumentsDirectory(videoData: data1, withName: name)
        _ = saveVideoToDocumentsDirectory(videoData: data2, withName: name)
        guard let url = loadVideoUrlFromDocumentsDirectory(withName: name),
              let loadedData = try? Data(contentsOf: url)
        else {
            return XCTFail("Could not load video data")
        }
        XCTAssertEqual(loadedData, data2)
    }

    // MARK: - Cross Image/Video IO

    func testCrossIO_saveImageAndVideo_differentNamespaces() throws {
        let baseName = "test_cross_\(UUID().uuidString)"
        testImageNames.append(baseName)
        testVideoNames.append(baseName)

        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        NSColor.red.set()
        NSBezierPath(rect: NSRect(origin: .zero, size: image.size)).fill()
        image.unlockFocus()
        guard let pngData = image.toPNGData() else {
            return XCTFail("Could not create PNG data")
        }

        let imgURL = saveImageToDocumentsDirectory(imageData: pngData, withName: baseName)
        let vidURL = saveVideoToDocumentsDirectory(videoData: makeFakeVideoData(), withName: baseName)
        XCTAssertNotNil(imgURL)
        XCTAssertNotNil(vidURL)
        // .png vs .mp4
        XCTAssertTrue(try XCTUnwrap(imgURL?.lastPathComponent.hasSuffix(".png")))
        XCTAssertTrue(try XCTUnwrap(vidURL?.lastPathComponent.hasSuffix(".mp4")))
    }

    func testCrossIO_videoSize_imageSize_independent() {
        let imgName = uniqueImageName()
        let vidName = uniqueVideoName()
        let imgData = Data(repeating: 0xAA, count: 500)
        let vidData = makeFakeVideoData(size: 1000)

        guard let imgURL = saveImageToDocumentsDirectory(imageData: imgData, withName: imgName),
              let vidURL = saveVideoToDocumentsDirectory(videoData: vidData, withName: vidName)
        else {
            return XCTFail("Could not save files")
        }

        let imgSize = getImageSizeInBytes(imageURL: imgURL)
        let vidSize = getVideoSizeInBytes(videoURL: vidURL)
        XCTAssertEqual(imgSize, 500)
        XCTAssertEqual(vidSize, 1000)
    }
}
