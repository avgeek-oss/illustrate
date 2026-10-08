// MARK: - G_CLOUDFLARE_SD_15_IMG2IMG.swift

import Foundation

public class G_CLOUDFLARE_SD_15_IMG2IMG: G_CLOUDFLARE_BASE {
    public init() {
        super.init(
            modelCode: .CLOUDFLARE_SD_15_IMG2IMG,
            cloudflareModelId: "@cf/runwayml/stable-diffusion-v1-5-img2img",
            pricePerImage: 0.0,
            supportsImageB64Input: true
        )
    }
}
