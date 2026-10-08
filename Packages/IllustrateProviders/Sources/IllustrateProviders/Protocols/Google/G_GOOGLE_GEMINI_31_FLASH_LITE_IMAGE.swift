// MARK: - G_GOOGLE_GEMINI_31_FLASH_LITE_IMAGE.swift

// Implementation for Gemini 3.1 Flash Lite Image (Nano Banana 2 Lite).

import Foundation

/// Gemini 3.1 Flash Lite Image (Nano Banana 2 Lite) generation.
public class G_GOOGLE_GEMINI_31_FLASH_LITE_IMAGE: Gemini31FlashLiteImageBase {
    public init() {
        super.init()
    }

    override var geminiModelId: String {
        "gemini-3.1-flash-lite-image"
    }

    override public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .GOOGLE_GEMINI_31_FLASH_LITE_IMAGE)!
    }
}
