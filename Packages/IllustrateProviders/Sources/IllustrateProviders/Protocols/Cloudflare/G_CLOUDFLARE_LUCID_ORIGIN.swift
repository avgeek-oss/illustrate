// MARK: - G_CLOUDFLARE_LUCID_ORIGIN.swift

import Foundation

public class G_CLOUDFLARE_LUCID_ORIGIN: G_CLOUDFLARE_BASE {
    public init() {
        super.init(
            modelCode: .CLOUDFLARE_LUCID_ORIGIN,
            cloudflareModelId: "@cf/leonardo/lucid-origin",
            pricePerImage: 0.007
        )
    }
}
