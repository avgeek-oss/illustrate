import Foundation

/// Owns a uniquely named UserDefaults suite and removes its persistent domain on cleanup.
public final class IsolatedUserDefaults: @unchecked Sendable {
    public let suiteName: String
    public let defaults: UserDefaults

    private let cleanupLock = Locked(())

    public init(prefix: String = "AvgeekTestSupport") throws {
        suiteName = "\(prefix).\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw IsolatedUserDefaultsError.couldNotCreateSuite(name: suiteName)
        }
        self.defaults = defaults
        defaults.removePersistentDomain(forName: suiteName)
    }

    deinit {
        cleanup()
    }

    /// Removes all values. Calling this more than once is safe.
    public func cleanup() {
        cleanupLock.withValue { _ in
            defaults.removePersistentDomain(forName: suiteName)
        }
    }
}

public enum IsolatedUserDefaultsError: Error, Equatable, Sendable {
    case couldNotCreateSuite(name: String)
}
