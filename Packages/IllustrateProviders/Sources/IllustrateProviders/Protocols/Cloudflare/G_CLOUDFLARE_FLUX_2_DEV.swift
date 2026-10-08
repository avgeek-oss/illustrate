// MARK: - G_CLOUDFLARE_FLUX_2_DEV.swift

import Foundation

public class G_CLOUDFLARE_FLUX_2_DEV: G_CLOUDFLARE_BASE {
    public init() {
        super.init(
            modelCode: .CLOUDFLARE_FLUX_2_DEV,
            cloudflareModelId: "@cf/black-forest-labs/flux-2-dev",
            pricePerImage: 0.041,
            usesMultipart: true,
            pricingModel: .flux2Dev
        )
    }
}
