// MARK: - G_REPLICATE_REVE_2_1.swift

import Foundation

public final class G_REPLICATE_REVE_2_1: ReplicateCatalogImageBase {
    private static let supportedAspectRatios = [
        "auto", "4:1", "3:1", "21:9", "2:1", "17:9", "16:9", "3:2", "4:3",
        "5:4", "1:1", "4:5", "3:4", "2:3", "9:16", "1:2", "1:3", "1:4",
    ]

    override var modelCode: EnumProviderModelCode {
        .REPLICATE_REVE_2_1
    }

    override var costPerImage: Double {
        0.20
    }

    override var acceptsSourceImage: Bool {
        true
    }

    override var maxReferenceImages: Int {
        8
    }

    override func buildInput(
        request: ImageGenerationRequest,
        sourceImageURL: String?,
        maskURL _: String?,
        referenceImageURLs: [String]
    ) -> ReplicateCatalogImageInput {
        var input = ReplicateCatalogImageInput()
        let references = ([sourceImageURL].compactMap { $0 } + referenceImageURLs).prefix(8)

        input.prompt = request.prompt
        input.reference_images = references.isEmpty ? nil : Array(references)
        input.aspect_ratio = replicateCatalogAspectRatio(
            request.dimensions,
            allowed: Self.supportedAspectRatios,
            default: "auto"
        )
        return input
    }
}
