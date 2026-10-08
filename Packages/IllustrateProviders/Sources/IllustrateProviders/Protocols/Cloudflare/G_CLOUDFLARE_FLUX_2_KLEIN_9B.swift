// MARK: - G_CLOUDFLARE_FLUX_2_KLEIN_9B.swift

import Foundation

public class G_CLOUDFLARE_FLUX_2_KLEIN_9B: G_CLOUDFLARE_BASE {
    public init() {
        super.init(
            modelCode: .CLOUDFLARE_FLUX_2_KLEIN_9B,
            cloudflareModelId: "@cf/black-forest-labs/flux-2-klein-9b",
            pricePerImage: 0.015,
            usesMultipart: true,
            pricingModel: .flux2Klein9B
        )
    }
}
