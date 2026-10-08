import Foundation
import XCTest
@testable import AvgeekTestSupport

final class ResourceFixturesTests: XCTestCase {
    func testUserDefaultsSuitesAreUniqueAndStartEmpty() throws {
        let first = try IsolatedUserDefaults(prefix: "ResourceFixturesTests")
        let second = try IsolatedUserDefaults(prefix: "ResourceFixturesTests")
        first.defaults.set("value", forKey: "key")

        XCTAssertNotEqual(first.suiteName, second.suiteName)
        XCTAssertNil(second.defaults.string(forKey: "key"))
    }

    func testUserDefaultsExplicitCleanupIsIdempotent() throws {
        let fixture = try IsolatedUserDefaults(prefix: "ResourceFixturesTests")
        fixture.defaults.set("value", forKey: "key")

        fixture.cleanup()
        fixture.defaults.set("new-value", forKey: "key")
        fixture.cleanup()

        XCTAssertNil(fixture.defaults.string(forKey: "key"))
    }

    func testUserDefaultsDeinitRemovesPersistentDomain() throws {
        let suiteName = try makeReleasedUserDefaultsSuite()

        XCTAssertNil(try XCTUnwrap(UserDefaults(suiteName: suiteName)).string(forKey: "key"))
    }

    func testTemporaryDirectoryWritesNestedFiles() throws {
        let fixture = try TemporaryDirectoryFixture(prefix: "ResourceFixturesTests")

        let fileURL = try fixture.write("fixture", to: "nested/fixture.txt")

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), "fixture")
        XCTAssertEqual(fileURL.deletingLastPathComponent().lastPathComponent, "nested")
    }

    func testTemporaryDirectoryRejectsPathsOutsideItsRoot() throws {
        let fixture = try TemporaryDirectoryFixture(prefix: "ResourceFixturesTests")

        for path in ["", "/tmp/file", "../file", "nested/../file", "nested//file"] {
            XCTAssertThrowsError(try fixture.url(for: path)) { error in
                XCTAssertEqual(error as? TemporaryDirectoryFixtureError, .invalidRelativePath(path))
            }
        }
    }

    func testTemporaryDirectoryCleanupIsIdempotentAndPreventsReuse() throws {
        let fixture = try TemporaryDirectoryFixture(prefix: "ResourceFixturesTests")
        let rootURL = fixture.rootURL

        try fixture.cleanup()
        try fixture.cleanup()

        XCTAssertFalse(FileManager.default.fileExists(atPath: rootURL.path))
        XCTAssertThrowsError(try fixture.write("value", to: "file.txt")) { error in
            XCTAssertEqual(error as? TemporaryDirectoryFixtureError, .alreadyCleanedUp)
        }
    }

    func testTemporaryDirectoryDeinitRemovesRoot() throws {
        let rootURL = try makeReleasedTemporaryDirectory()

        XCTAssertFalse(FileManager.default.fileExists(atPath: rootURL.path))
    }

    func testConcurrentTemporaryFileWritesAreSerialized() async throws {
        let fixture = try TemporaryDirectoryFixture(prefix: "ResourceFixturesTests")

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0 ..< 25 {
                group.addTask {
                    try fixture.write("\(index)", to: "items/\(index).txt")
                }
            }
            try await group.waitForAll()
        }

        let files = try FileManager.default
            .contentsOfDirectory(atPath: fixture.rootURL.appendingPathComponent("items").path)
        XCTAssertEqual(files.count, 25)
    }

    private func makeReleasedUserDefaultsSuite() throws -> String {
        let fixture = try IsolatedUserDefaults(prefix: "ResourceFixturesTests")
        fixture.defaults.set("value", forKey: "key")
        return fixture.suiteName
    }

    private func makeReleasedTemporaryDirectory() throws -> URL {
        let fixture = try TemporaryDirectoryFixture(prefix: "ResourceFixturesTests")
        try fixture.write("value", to: "file.txt")
        return fixture.rootURL
    }
}
