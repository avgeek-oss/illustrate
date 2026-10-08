// MARK: - G_CLOUDFLARE_BASE.swift

// Base implementation for Cloudflare Workers AI image generation models.
//
// Cloudflare Workers AI uses a REST API with:
// - Bearer token authentication
// - URL path contains the Account ID: /accounts/{ACCOUNT_ID}/ai/run/{MODEL_ID}
// - JSON credentials stored as {"account_id": "...", "api_token": "..."}
// - Response wrapped in {"result": {...}, "success": true/false, "errors": [...]}
//
// Two request patterns:
// 1. JSON POST body (flux-1-schnell, SDXL, dreamshaper, phoenix, lucid-origin)
// 2. Multipart form-data (flux-2-klein-*, flux-2-dev)

import Foundation

public enum CloudflarePricingModel: Sendable {
    case flat(pricePerImage: Double)
    case flux2Dev
    case flux2Klein4B
    case flux2Klein9B

    var sendsAdjustableSteps: Bool {
        switch self {
        case .flux2Klein4B, .flux2Klein9B:
            false
        case .flat, .flux2Dev:
            true
        }
    }
}

public class G_CLOUDFLARE_BASE: ImageGenerationProtocol {
    let modelCode: EnumProviderModelCode
    let cloudflareModelId: String
    let pricePerImage: Double
    let pricingModel: CloudflarePricingModel
    let usesMultipart: Bool
    let supportsImageB64Input: Bool

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(
        modelCode: EnumProviderModelCode,
        cloudflareModelId: String,
        pricePerImage: Double,
        usesMultipart: Bool = false,
        supportsImageB64Input: Bool = false,
        pricingModel: CloudflarePricingModel? = nil
    ) {
        self.modelCode = modelCode
        self.cloudflareModelId = cloudflareModelId
        self.pricePerImage = pricePerImage
        self.pricingModel = pricingModel ?? .flat(pricePerImage: pricePerImage)
        self.usesMultipart = usesMultipart
        self.supportsImageB64Input = supportsImageB64Input
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        getCostEstimate(
            dimensions: request.dimensions,
            numberOfImages: request.numberOfImages,
            inputImageCount: 0,
            steps: nil
        )
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public struct ServiceRequest: Codable, Sendable {
        public let prompt: String
        public let steps: Int?
        public let num_steps: Int?
        public let seed: Int?
        public let guidance: Double?
        public let negative_prompt: String?
        public let width: Int?
        public let height: Int?
        public let image_b64: String?

        public init(
            prompt: String,
            steps: Int? = nil,
            numSteps: Int? = nil,
            seed: Int? = nil,
            guidance: Double? = nil,
            negativePrompt: String? = nil,
            width: Int? = nil,
            height: Int? = nil,
            imageB64: String? = nil
        ) {
            self.prompt = prompt
            self.steps = steps
            num_steps = numSteps
            self.seed = seed
            self.guidance = guidance
            negative_prompt = negativePrompt
            self.width = width
            self.height = height
            image_b64 = imageB64
        }
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        if modelCode == .CLOUDFLARE_FLUX_1_SCHNELL {
            return ServiceRequest(prompt: request.prompt, steps: request.steps, seed: request.seed)
        }

        var width: Int? = nil
        var height: Int? = nil

        let dims = request.dimensions
        if dims.contains("x") {
            let parts = dims.split(separator: "x")
            if parts.count == 2 {
                width = Int(parts[0])
                height = Int(parts[1])
            }
        }

        var steps: Int? = nil
        if let requestSteps = request.steps {
            steps = requestSteps
        }

        var guidance: Double? = nil
        if let requestGuidance = request.guidance {
            guidance = requestGuidance
        }

        var negativePrompt: String? = nil
        if let np = request.negativePrompt, !np.isEmpty {
            negativePrompt = np
        }

        let imageB64 = supportsImageB64Input
            ? request.clientImage?.replacingOccurrences(
                of: "^data:.*;base64,",
                with: "",
                options: .regularExpression
            )
            : nil

        let includeSteps = usesMultipart && pricingModel.sendsAdjustableSteps

        return ServiceRequest(
            prompt: request.prompt,
            steps: includeSteps ? steps : nil,
            numSteps: usesMultipart ? nil : steps,
            seed: request.seed,
            guidance: guidance,
            negativePrompt: negativePrompt,
            width: width,
            height: height,
            imageB64: imageB64
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let success = data["success"] as? Bool, !success {
                let errors = data["errors"] as? [[String: Any]] ?? []
                let messages = errors.compactMap { $0["message"] as? String }.joined(separator: "; ")
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: messages.isEmpty ? "Cloudflare API error" : messages,
                    rawResponse: response.rawResponseString
                )
            }

            if let result = data["result"] as? [String: Any],
               let imageBase64 = result["image"] as? String
            {
                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: imageBase64,
                    cost: getCostEstimate(request: request),
                    modelPrompt: request.prompt
                )
            }

            if let imageBase64 = data["result"] as? String {
                return ImageGenerationResponse(
                    status: .GENERATED,
                    base64: imageBase64,
                    cost: getCostEstimate(request: request),
                    modelPrompt: request.prompt
                )
            }

            if let errors = data["errors"] as? [[String: Any]], !errors.isEmpty {
                let messages = errors.compactMap { $0["message"] as? String }.joined(separator: "; ")
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: messages,
                    rawResponse: response.rawResponseString
                )
            }
        case let .image(_, base64, _):
            return ImageGenerationResponse(
                status: .GENERATED,
                base64: base64,
                cost: getCostEstimate(request: request),
                modelPrompt: request.prompt
            )
        default:
            break
        }

        return createInvalidResponseError(response: response, modelCode: modelCode)
    }

    func parseCredentials(_ secret: String) -> (accountId: String, apiToken: String)? {
        guard let data = secret.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let accountId = json["account_id"],
              let apiToken = json["api_token"],
              !accountId.isEmpty, !apiToken.isEmpty
        else {
            return nil
        }
        return (accountId, apiToken)
    }

    func buildURL(accountId: String) -> String {
        model.modelGenerateBaseURL.replacingOccurrences(of: "{{ACCOUNT_ID}}", with: accountId)
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let creds = parseCredentials(request.providerSecret) else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Invalid credentials. Expected JSON with account_id and api_token."
            )
        }

        guard let url = URL(string: buildURL(accountId: creds.accountId)) else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        let transformedRequest = transformRequest(request: request)
        let headers: [String: String] = usesMultipart
            ? [
                "Authorization": "Bearer \(creds.apiToken)",
                "Content-Type": "multipart/form-data",
            ]
            : [
                "Authorization": "Bearer \(creds.apiToken)",
                "Content-Type": "application/json",
            ]

        let response = try await ProviderDependencies.shared.networkProvider.performRequest(
            url: url,
            method: "POST",
            body: transformedRequest,
            headers: headers,
            attachments: usesMultipart ? makeMultipartAttachments(request: request) : nil
        )

        return try transformResponse(request: request, response: response)
    }

    func getCostEstimate(request: ImageGenerationRequest) -> Double {
        getCostEstimate(
            dimensions: request.dimensions,
            numberOfImages: request.numberOfImages,
            inputImageCount: inputImageCount(request: request),
            steps: request.steps
        )
    }

    private func getCostEstimate(
        dimensions: String?,
        numberOfImages: Int?,
        inputImageCount: Int,
        steps: Int?
    ) -> Double {
        let imageCount = Double(max(numberOfImages ?? 1, 1))
        let outputTileCount = Double(tileCount512(for: dimensions))
        let inputTileCount = Double(inputImageCount)
        let outputMegapixels = megapixels1024(for: dimensions)
        let inputMegapixels = Double(inputImageCount) * 0.25

        switch pricingModel {
        case let .flat(pricePerImage):
            return pricePerImage * imageCount
        case .flux2Dev:
            let stepCount = Double(max(steps ?? 25, 1))
            let outputCost = outputTileCount * 0.00041 * stepCount
            let inputCost = inputTileCount * 0.00021 * stepCount
            return (outputCost + inputCost) * imageCount
        case .flux2Klein4B:
            let outputCost = outputTileCount * 0.000287
            let inputCost = inputTileCount * 0.000059
            return (outputCost + inputCost) * imageCount
        case .flux2Klein9B:
            let outputCost = 0.015 + max(outputMegapixels - 1.0, 0) * 0.002
            let inputCost = inputMegapixels * 0.002
            return (outputCost + inputCost) * imageCount
        }
    }

    private func tileCount512(for dimensions: String?) -> Int {
        let size = parseDimensions(dimensions)
        let widthTiles = Int(ceil(Double(size.width) / 512.0))
        let heightTiles = Int(ceil(Double(size.height) / 512.0))
        return max(widthTiles, 1) * max(heightTiles, 1)
    }

    private func megapixels1024(for dimensions: String?) -> Double {
        let size = parseDimensions(dimensions)
        return Double(size.width * size.height) / Double(1024 * 1024)
    }

    private func parseDimensions(_ dimensions: String?) -> (width: Int, height: Int) {
        guard let dimensions else {
            return (1024, 1024)
        }

        let parts = dimensions.lowercased().split(separator: "x")
        if parts.count == 2,
           let width = Int(parts[0]),
           let height = Int(parts[1]),
           width > 0,
           height > 0
        {
            return (width, height)
        }

        return (1024, 1024)
    }

    private func inputImageCount(request: ImageGenerationRequest) -> Int {
        makeMultipartAttachments(request: request)?.count ?? 0
    }

    private func makeMultipartAttachments(request: ImageGenerationRequest) -> [NetworkRequestAttachment]? {
        var images: [(mimeType: String, data: Data)] = []

        if let clientImage = request.clientImage,
           let imageData = decodeBase64Image(clientImage)
        {
            images.append((mimeType(from: clientImage, fallback: "image/png"), imageData))
        }

        if let referenceImages = request.clientReferenceImages {
            for referenceImage in referenceImages {
                guard let imageData = decodeBase64Image(referenceImage.base64Image) else { continue }
                images.append((referenceImage.mimeType, imageData))
            }
        }

        let attachments = images.prefix(4).enumerated().map { index, image in
            NetworkRequestAttachment(
                name: "input_image_\(index)",
                mimeType: image.mimeType,
                data: image.data
            )
        }

        return attachments.isEmpty ? nil : Array(attachments)
    }

    private func decodeBase64Image(_ image: String) -> Data? {
        let cleanBase64 = image.replacingOccurrences(
            of: "^data:.*;base64,",
            with: "",
            options: .regularExpression
        )
        return Data(base64Encoded: cleanBase64)
    }

    private func mimeType(from image: String, fallback: String) -> String {
        guard image.hasPrefix("data:"),
              let semicolonIndex = image.firstIndex(of: ";")
        else {
            return fallback
        }

        let start = image.index(image.startIndex, offsetBy: 5)
        guard start < semicolonIndex else {
            return fallback
        }

        return String(image[start ..< semicolonIndex])
    }
}
