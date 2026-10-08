// MARK: - G_GOOGLE_GEMINI_PRO_IMAGE.swift

// Implementation for Gemini 3 Pro Image (Nano Banana Pro).

import Foundation

/// Gemini 3 Pro Image (Nano Banana Pro) generation.
public class G_GOOGLE_GEMINI_PRO_IMAGE: GeminiProImageBase {
    public init() {
        super.init()
    }

    override var geminiModelId: String {
        "gemini-3-pro-image"
    }

    override public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .GOOGLE_GEMINI_PRO_IMAGE)!
    }
}
