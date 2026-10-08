// MARK: - G_GOOGLE_GEMINI_31_FLASH_IMAGE.swift

// Implementation for Gemini 3.1 Flash Image (Nano Banana 2).

import Foundation

/// Gemini 3.1 Flash Image (Nano Banana 2) generation.
public class G_GOOGLE_GEMINI_31_FLASH_IMAGE: Gemini31FlashImageBase {
    public init() {
        super.init()
    }

    override var geminiModelId: String {
        "gemini-3.1-flash-image"
    }

    override public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .GOOGLE_GEMINI_31_FLASH_IMAGE)!
    }
}
