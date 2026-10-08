// MARK: - G_TOGETHER_IMAGE_BASE.swift

// Base implementation for Together AI image generation models.
//
// Together AI's image API is OpenAI-compatible:
// POST /v1/images/generations with Bearer token auth.
// Response: { "data": [{ "b64_json": "..." }] } or { "data": [{ "url": "..." }] }
//
// Pricing is per megapixel of output.

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public class G_TOGETHER_IMAGE_BASE: ImageGenerationProtocol {
    let modelCode: EnumProviderModelCode
    let modelName: String
    let pricePerMP: Double
    let defaultSteps: Int

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(modelCode: EnumProviderModelCode, modelName: String, pricePerMP: Double, defaultSteps: Int = 20) {
        self.modelCode = modelCode
        self.modelName = modelName
        self.pricePerMP = pricePerMP
        self.defaultSteps = defaultSteps
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let dimensions = request.dimensions ?? "1024x1024"
        let numberOfImages = request.numberOfImages ?? 1
        let parts = dimensions.split(separator: "x")
        let width = Double(parts.first ?? "1024") ?? 1024.0
        let height = Double(parts.last ?? "1024") ?? 1024.0
        let megapixels = (width * height) / 1_000_000.0
        return pricePerMP * megapixels * Double(numberOfImages)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        let model: String
        let prompt: String
        let n: Int?
        let width: Int?
        let height: Int?
        let steps: Int?
        let seed: Int?
        let negative_prompt: String?
        let guidance_scale: Double?
        let response_format: String?
        let image_url: String?
        let output_format: String?

        public init(
            model: String,
            prompt: String,
            n: Int? = nil,
            width: Int? = nil,
            height: Int? = nil,
            steps: Int? = nil,
            seed: Int? = nil,
            negativePrompt: String? = nil,
            guidanceScale: Double? = nil,
            imageURL: String? = nil
        ) {
            self.model = model
            self.prompt = prompt
            self.n = n
            self.width = width
            self.height = height
            self.steps = steps
            self.seed = seed
            negative_prompt = negativePrompt
            guidance_scale = guidanceScale
            response_format = "base64"
            image_url = imageURL
            output_format = "png"
        }
    }

    func parseDimensions(_ dimensions: String) -> (width: Int, height: Int) {
        let parts = dimensions.split(separator: "x")
        let w = Int(parts.first ?? "1024") ?? 1024
        let h = Int(parts.last ?? "1024") ?? 1024
        return (w, h)
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let (width, height) = parseDimensions(request.dimensions)

        var imageURL: String? = nil
        if let clientImage = request.clientImage {
            let cleanBase64 = clientImage.replacingOccurrences(
                of: "^data:.*;base64,",
                with: "",
                options: .regularExpression
            )
            imageURL = "data:image/png;base64,\(cleanBase64)"
        }

        return ServiceRequest(
            model: modelName,
            prompt: request.prompt,
            n: request.numberOfImages > 1 ? request.numberOfImages : nil,
            width: width,
            height: height,
            steps: request.steps,
            seed: request.seed,
            negativePrompt: request.negativePrompt,
            guidanceScale: request.guidance,
            imageURL: imageURL
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let nestedData = data["data"] as? [[String: Any]] {
                if let imageData = nestedData.first?["b64_json"] as? String {
                    return ImageGenerationResponse(
                        status: .GENERATED,
                        base64: imageData,
                        cost: getCostEstimate(request: ImageGenerationCostRequest(from: request)),
                        modelPrompt: request.prompt
                    )
                }

                if let url = nestedData.first?["url"] as? String {
                    return ImageGenerationResponse(
                        status: .GENERATED,
                        base64: nil,
                        cost: getCostEstimate(request: ImageGenerationCostRequest(from: request)),
                        modelPrompt: request.prompt,
                        rawResponse: url
                    )
                }
            }

            if let error = data["error"] as? [String: Any],
               let message = error["message"] as? String
            {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: message,
                    rawResponse: response.rawResponseString
                )
            }

            if let message = data["message"] as? String {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: message,
                    rawResponse: response.rawResponseString
                )
            }

        default:
            return createInvalidResponseError(
                response: response,
                modelCode: modelCode,
                customMessage: "Unexpected response"
            )
        }

        return createInvalidResponseError(
            response: response,
            modelCode: modelCode
        )
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        let transformedRequest = transformRequest(request: request)

        do {
            let generation = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: transformedRequest,
                headers: [
                    "Authorization": "Bearer \(request.providerSecret)",
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                ],
                attachments: nil
            )

            let result = try transformResponse(request: request, response: generation)

            if result.status == .GENERATED, result.base64 == nil,
               let videoURLString = result.rawResponse,
               let imageURL = URL(string: videoURLString)
            {
                var urlRequest = URLRequest(url: imageURL)
                let (data, urlResponse) = try await URLSession.shared.data(for: urlRequest)

                guard let httpResponse = urlResponse as? HTTPURLResponse,
                      httpResponse.statusCode == 200
                else {
                    return ImageGenerationResponse(
                        status: .FAILED,
                        errorCode: .MODEL_ERROR,
                        errorMessage: "Failed to download image from URL"
                    )
                }

                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: data.base64EncodedString(),
                    cost: result.cost,
                    modelPrompt: result.modelPrompt
                )
            }

            return result
        } catch {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Failed with error: \(error.localizedDescription)",
                rawResponse: "Error: \(error.localizedDescription)"
            )
        }
    }
}

public class G_TOGETHER_FLUX_SCHNELL: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(
            modelCode: .TOGETHER_FLUX_SCHNELL,
            modelName: "black-forest-labs/FLUX.1-schnell",
            pricePerMP: 0.0027,
            defaultSteps: 4
        )
    }
}

public class G_TOGETHER_FLUX_11_PRO: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_FLUX_11_PRO, modelName: "black-forest-labs/FLUX.1.1-pro", pricePerMP: 0.04)
    }
}

public class G_TOGETHER_FLUX_2_PRO: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_FLUX_2_PRO, modelName: "black-forest-labs/FLUX.2-pro", pricePerMP: 0.03)
    }
}

public class G_TOGETHER_FLUX_2_DEV: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_FLUX_2_DEV, modelName: "black-forest-labs/FLUX.2-dev", pricePerMP: 0.0154)
    }
}

public class G_TOGETHER_FLUX_2_MAX: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_FLUX_2_MAX, modelName: "black-forest-labs/FLUX.2-max", pricePerMP: 0.07)
    }
}

public class G_TOGETHER_FLUX_KONTEXT_PRO: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(
            modelCode: .TOGETHER_FLUX_KONTEXT_PRO,
            modelName: "black-forest-labs/FLUX.1-kontext-pro",
            pricePerMP: 0.04,
            defaultSteps: 28
        )
    }
}

public class G_TOGETHER_FLUX_KONTEXT_MAX: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(
            modelCode: .TOGETHER_FLUX_KONTEXT_MAX,
            modelName: "black-forest-labs/FLUX.1-kontext-max",
            pricePerMP: 0.08,
            defaultSteps: 28
        )
    }
}

public class G_TOGETHER_SD3: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_SD3, modelName: "stabilityai/stable-diffusion-3-medium", pricePerMP: 0.0019)
    }
}

public class G_TOGETHER_SDXL: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_SDXL, modelName: "stabilityai/stable-diffusion-xl-base-1.0", pricePerMP: 0.0019)
    }
}

public class G_TOGETHER_IMAGEN_4_FAST: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_IMAGEN_4_FAST, modelName: "google/imagen-4.0-fast", pricePerMP: 0.02)
    }
}

public class G_TOGETHER_IMAGEN_4_ULTRA: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_IMAGEN_4_ULTRA, modelName: "google/imagen-4.0-ultra", pricePerMP: 0.06)
    }
}

public class G_TOGETHER_SEEDREAM_4: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_SEEDREAM_4, modelName: "ByteDance-Seed/Seedream-4.0", pricePerMP: 0.03)
    }
}

public class G_TOGETHER_IDEOGRAM_3: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_IDEOGRAM_3, modelName: "ideogram/ideogram-3.0", pricePerMP: 0.06)
    }
}

public class G_TOGETHER_QWEN_IMAGE: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_QWEN_IMAGE, modelName: "Qwen/Qwen-Image-2.0", pricePerMP: 0.035)
    }
}

public class G_TOGETHER_FLUX_2_FLEX: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_FLUX_2_FLEX, modelName: "black-forest-labs/FLUX.2-flex", pricePerMP: 0.03)
    }
}

public class G_TOGETHER_FLUX_KREA_DEV: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(
            modelCode: .TOGETHER_FLUX_KREA_DEV,
            modelName: "black-forest-labs/FLUX.1-krea-dev",
            pricePerMP: 0.025
        )
    }
}

public class G_TOGETHER_IMAGEN_4_PREVIEW: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_IMAGEN_4_PREVIEW, modelName: "google/imagen-4.0-preview", pricePerMP: 0.04)
    }
}

public class G_TOGETHER_FLASH_IMAGE_25: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_FLASH_IMAGE_25, modelName: "google/flash-image-2.5", pricePerMP: 0.039)
    }
}

public class G_TOGETHER_GEMINI_3_PRO_IMAGE: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_GEMINI_3_PRO_IMAGE, modelName: "google/gemini-3-pro-image", pricePerMP: 0.134)
    }
}

public class G_TOGETHER_FLASH_IMAGE_31: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_FLASH_IMAGE_31, modelName: "google/flash-image-3.1", pricePerMP: 0.05)
    }
}

public class G_TOGETHER_SEEDREAM_3: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_SEEDREAM_3, modelName: "ByteDance-Seed/Seedream-3.0", pricePerMP: 0.018)
    }
}

public class G_TOGETHER_QWEN_IMAGE_PRO: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_QWEN_IMAGE_PRO, modelName: "Qwen/Qwen-Image-2.0-Pro", pricePerMP: 0.075)
    }
}

public class G_TOGETHER_HIDREAM_DEV: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_HIDREAM_DEV, modelName: "HiDream-ai/HiDream-I1-Dev", pricePerMP: 0.0045)
    }
}

public class G_TOGETHER_HIDREAM_FAST: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_HIDREAM_FAST, modelName: "HiDream-ai/HiDream-I1-Fast", pricePerMP: 0.0032)
    }
}

public class G_TOGETHER_WAN_26_IMAGE: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_WAN_26_IMAGE, modelName: "Wan-AI/wan2.6-image", pricePerMP: 0.03)
    }
}

public class G_TOGETHER_GPT_IMAGE_15: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_GPT_IMAGE_15, modelName: "openai/gpt-image-1.5", pricePerMP: 0.034)
    }
}

public class G_TOGETHER_GROK_IMAGINE_PRO: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_GROK_IMAGINE_PRO, modelName: "xai/grok-imagine-image-pro", pricePerMP: 0.07)
    }
}

public class G_TOGETHER_QWEN_IMAGE_BASE: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_QWEN_IMAGE_BASE, modelName: "Qwen/Qwen-Image", pricePerMP: 0.0058)
    }
}

public class G_TOGETHER_JUGGERNAUT_PRO_FLUX: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(
            modelCode: .TOGETHER_JUGGERNAUT_PRO_FLUX,
            modelName: "RunDiffusion/Juggernaut-pro-flux",
            pricePerMP: 0.0049
        )
    }
}

public class G_TOGETHER_JUGGERNAUT_LIGHTNING_FLUX: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(
            modelCode: .TOGETHER_JUGGERNAUT_LIGHTNING_FLUX,
            modelName: "Rundiffusion/Juggernaut-Lightning-Flux",
            pricePerMP: 0.0017
        )
    }
}

public class G_TOGETHER_DREAMSHAPER: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_DREAMSHAPER, modelName: "Lykon/DreamShaper", pricePerMP: 0.0006)
    }
}

public class G_TOGETHER_HIDREAM_FULL: G_TOGETHER_IMAGE_BASE {
    public init() {
        super.init(modelCode: .TOGETHER_HIDREAM_FULL, modelName: "HiDream-ai/HiDream-I1-Full", pricePerMP: 0.009)
    }
}
