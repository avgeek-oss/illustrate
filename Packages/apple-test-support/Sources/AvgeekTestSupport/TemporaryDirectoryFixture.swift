import Foundation

/// Owns a unique temporary directory and removes it on cleanup.
public final class TemporaryDirectoryFixture: @unchecked Sendable {
    public let rootURL: URL

    private let state = Locked(true)

    public init(
        prefix: String = "AvgeekTestSupport",
        baseDirectory: URL = FileManager.default.temporaryDirectory
    ) throws {
        let safePrefix = prefix.replacingOccurrences(of: "/", with: "-")
        rootURL = baseDirectory.appendingPathComponent("\(safePrefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    deinit {
        try? cleanup()
    }

    public func url(for relativePath: String) throws -> URL {
        try withActiveDirectory {
            try resolvedURL(for: relativePath)
        }
    }

    @discardableResult
    public func makeDirectory(at relativePath: String) throws -> URL {
        try withActiveDirectory {
            let url = try resolvedURL(for: relativePath)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }
    }

    @discardableResult
    public func write(_ data: Data, to relativePath: String) throws -> URL {
        try withActiveDirectory {
            let url = try resolvedURL(for: relativePath)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
            return url
        }
    }

    @discardableResult
    public func write(
        _ string: String,
        to relativePath: String,
        encoding: String.Encoding = .utf8
    ) throws -> URL {
        guard let data = string.data(using: encoding) else {
            throw TemporaryDirectoryFixtureError.couldNotEncodeString(encoding: encoding.rawValue)
        }
        return try write(data, to: relativePath)
    }

    /// Removes the directory. Calling this more than once is safe.
    public func cleanup() throws {
        try state.withValue { isActive in
            guard isActive else { return }
            if FileManager.default.fileExists(atPath: rootURL.path) {
                try FileManager.default.removeItem(at: rootURL)
            }
            isActive = false
        }
    }

    private func withActiveDirectory<Result>(_ operation: () throws -> Result) throws -> Result {
        try state.withValue { isActive in
            guard isActive else {
                throw TemporaryDirectoryFixtureError.alreadyCleanedUp
            }
            return try operation()
        }
    }

    private func resolvedURL(for relativePath: String) throws -> URL {
        let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." })
        else {
            throw TemporaryDirectoryFixtureError.invalidRelativePath(relativePath)
        }

        let candidate = rootURL.appendingPathComponent(relativePath).standardizedFileURL
        let rootPath = rootURL.standardizedFileURL.path
        guard candidate.path.hasPrefix("\(rootPath)/") else {
            throw TemporaryDirectoryFixtureError.invalidRelativePath(relativePath)
        }
        return candidate
    }
}

public enum TemporaryDirectoryFixtureError: Error, Equatable, Sendable {
    case invalidRelativePath(String)
    case couldNotEncodeString(encoding: UInt)
    case alreadyCleanedUp
}
