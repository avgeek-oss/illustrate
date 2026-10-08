import SwiftUI
import ZIPFoundation

enum ZipExtractor {
    static func extractImages(from zipURL: URL) -> [(name: String, image: PlatformImage)] {
        guard let archive = try? Archive(url: zipURL, accessMode: .read, pathEncoding: nil) else {
            return []
        }

        let imageExtensions: Set = ["png", "jpg", "jpeg", "heic", "heif", "webp", "tiff", "bmp", "gif"]
        var results: [(name: String, image: PlatformImage)] = []

        for entry in archive {
            let path = entry.path
            let fileExtension = (path as NSString).pathExtension.lowercased()
            guard imageExtensions.contains(fileExtension) else { continue }
            guard !path.hasPrefix("__MACOSX"), !path.contains("/__MACOSX/") else { continue }

            var data = Data()
            _ = try? archive.extract(entry) { chunk in
                data.append(chunk)
            }

            guard !data.isEmpty else { continue }

            #if os(macOS)
            guard let image = NSImage(data: data) else { continue }
            #else
            guard let image = UIImage(data: data) else { continue }
            #endif

            let filename = (path as NSString).lastPathComponent
            results.append((name: filename, image: image))

            if results.count >= bulkEditMaxItems { break }
        }

        return results
    }
}
