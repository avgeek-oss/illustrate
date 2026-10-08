// MARK: - G_CLOUDFLARE_FLUX_2_KLEIN_4B.swift

import Foundation

public class G_CLOUDFLARE_FLUX_2_KLEIN_4B: G_CLOUDFLARE_BASE {
    public init() {
        super.init(
            modelCode: .CLOUDFLARE_FLUX_2_KLEIN_4B,
            cloudflareModelId: "@cf/black-forest-labs/flux-2-klein-4b",
            pricePerImage: 0.001148,
            usesMultipart: true,
            pricingModel: .flux2Klein4B
        )
    }
}
