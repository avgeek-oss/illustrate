// MARK: - G_CLOUDFLARE_SD_XL_BASE.swift

import Foundation

public class G_CLOUDFLARE_SD_XL_BASE: G_CLOUDFLARE_BASE {
    public init() {
        super.init(
            modelCode: .CLOUDFLARE_SD_XL_BASE,
            cloudflareModelId: "@cf/stabilityai/stable-diffusion-xl-base-1.0",
            pricePerImage: 0.0
        )
    }
}
