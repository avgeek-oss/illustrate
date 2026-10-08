// MARK: - UUID+Deterministic.swift

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

// MARK: - UUID Extension for Deterministic Generation

public extension UUID {
    /// Generates a deterministic UUID from a string using SHA256 hashing.
    ///
    /// This ensures the same input string always produces the same UUID,
    /// which is critical for consistent model/provider identification across
    /// devices and iCloud sync.
    ///
    /// ## Implementation
    /// 1. Converts the string to UTF-8 data
    /// 2. Computes SHA256 hash (32 bytes)
    /// 3. Uses first 16 bytes to construct UUID
    ///
    /// - Parameter string: The source string to hash
    /// - Returns: A deterministic UUID derived from the input
    static func deterministicUUID(from string: String) -> UUID {
        let hash = SHA256.hash(data: Data(string.utf8))
        let hashBytes = Array(hash)

        return UUID(uuid: (
            hashBytes[0], hashBytes[1], hashBytes[2], hashBytes[3],
            hashBytes[4], hashBytes[5], hashBytes[6], hashBytes[7],
            hashBytes[8], hashBytes[9], hashBytes[10], hashBytes[11],
            hashBytes[12], hashBytes[13], hashBytes[14], hashBytes[15]
        ))
    }
}
