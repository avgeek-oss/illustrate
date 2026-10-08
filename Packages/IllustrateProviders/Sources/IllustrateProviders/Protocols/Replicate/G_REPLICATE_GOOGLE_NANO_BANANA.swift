// MARK: - G_REPLICATE_GOOGLE_NANO_BANANA.swift

// Google Nano Banana models via Replicate:
// - google/nano-banana (text-to-image with up to 4 reference images)
// - google/nano-banana-pro (text-to-image with up to 14 reference images, 1K-4K output)

import Foundation

// MARK: - Base Class

public class ReplicateNanoBananaBase: ImageGenerationProtocol {
    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override modelCode")
    }

    var maxPollingAttempts: Int {
        60
    }

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public struct ServiceRequest: Codable, Sendable {
        let placeholder: Bool
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        ServiceRequest(placeholder: true)
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        fatalError("Subclass must override getCostEstimate")
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Free" : formatEstimatedCost(cost)
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let imageUrl = data["output"] as? String {
                return try downloadAndReturnImage(urlStr: imageUrl, request: request)
            }
            if let output = data["output"] as? [String], let imageUrl = output.first {
                return try downloadAndReturnImage(urlStr: imageUrl, request: request)
            }
            if let errorList = data["error"] as? [String], let error = errorList.first {
                return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: error)
            }
            if let error = data["error"] as? String {
                return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: error)
            }
        default:
            break
        }
        return createInvalidResponseError(response: response, modelCode: modelCode)
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        fatalError("Subclass must override makeRequest")
    }

    // MARK: - Shared Helpers

    func pollForResult(
        requestId: String,
        url: URL,
        headers: [String: String]
    ) async throws -> NetworkResponseData {
        var attempts = 0
        while attempts < maxPollingAttempts {
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds

            let response = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url.appendingPathComponent("/\(requestId)"),
                method: "GET",
                body: nil as String?,
                headers: headers,
                attachments: nil
            )

            if case let .dictionary(_, data) = response,
               let status = data["status"] as? String,
               status == "succeeded" || status == "failed" || status == "canceled"
            {
                return response
            }
            attempts += 1
        }
        throw NSError(domain: "Polling exceeded max attempts", code: -1, userInfo: nil)
    }

    func performNanoBananaRequest(
        request: ImageGenerationRequest,
        body: some Codable & Sendable
    ) async throws -> ImageGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let headers = [
            "Authorization": "Bearer \(request.providerSecret)",
            "Content-Type": "application/json",
        ]

        do {
            let response = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: ["input": body],
                headers: headers,
                attachments: nil
            )

            guard case let .dictionary(_, data) = response,
                  let predictionId = data["id"] as? String
            else {
                return createInvalidResponseError(
                    response: response,
                    modelCode: modelCode,
                    customMessage: "Failed to create prediction"
                )
            }

            guard let statusUrl = model.statusURL else {
                return createInvalidStatusURLError()
            }

            let finalResponse = try await pollForResult(requestId: predictionId, url: statusUrl, headers: headers)
            return try transformResponse(request: request, response: finalResponse)
        } catch {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Request failed: \(error.localizedDescription)"
            )
        }
    }

    func uploadReferenceImages(
        _ referenceImages: [ReferenceImageData],
        apiToken: String
    ) async throws -> [String] {
        var uploadedUrls: [String] = []
        for refImage in referenceImages {
            let uploadedUrl = try await ReplicateFileUploader.uploadImage(
                base64Image: refImage.base64Image,
                apiToken: apiToken
            )
            uploadedUrls.append(uploadedUrl)
        }
        return uploadedUrls
    }

    func uploadInputImages(request: ImageGenerationRequest, apiToken: String) async throws -> [String] {
        var uploadedUrls: [String] = []

        if let clientImage = request.clientImage, !clientImage.isEmpty {
            let uploadedUrl = try await ReplicateFileUploader.uploadImage(
                base64Image: clientImage,
                apiToken: apiToken
            )
            uploadedUrls.append(uploadedUrl)
        }

        if let referenceImages = request.clientReferenceImages {
            for referenceImage in referenceImages {
                let uploadedUrl = try await ReplicateFileUploader.uploadImage(
                    base64Image: referenceImage.base64Image,
                    apiToken: apiToken
                )
                uploadedUrls.append(uploadedUrl)
            }
        }

        return uploadedUrls
    }

    private func downloadAndReturnImage(
        urlStr: String,
        request: ImageGenerationRequest
    ) throws -> ImageGenerationResponse {
        let base64: String
        if urlStr.hasPrefix("data:") {
            base64 = urlStr.replacingOccurrences(
                of: "^data:.*;base64,",
                with: "",
                options: .regularExpression
            )
        } else {
            let url = URL(string: urlStr)!
            base64 = try Data(contentsOf: url).base64EncodedString()
        }

        return ImageGenerationResponse(
            status: .GENERATED,
            base64: base64,
            cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
        )
    }
}

// MARK: - Gemini 2.5 Flash Image

struct Gemini25FlashImageRequest: Codable {
    let prompt: String
    let image_input: [String]?
    let aspect_ratio: String
    let output_format: String
}

public final class G_REPLICATE_GOOGLE_GEMINI_2_5_FLASH_IMAGE: ReplicateNanoBananaBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_GOOGLE_GEMINI_2_5_FLASH_IMAGE
    }

    override public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        0.039 * Double(request.numberOfImages ?? 1)
    }

    func transformRequest(
        request: ImageGenerationRequest,
        imageURLs: [String]? = nil
    ) -> Gemini25FlashImageRequest {
        let imageInput = imageURLs?.isEmpty == false ? imageURLs : nil
        let aspectRatio = request.dimensions == "match_input_image"
            ? "match_input_image"
            : getAspectRatio(dimension: request.dimensions).ratio

        return Gemini25FlashImageRequest(
            prompt: request.prompt,
            image_input: imageInput,
            aspect_ratio: aspectRatio,
            output_format: "png"
        )
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let uploadedImageUrls: [String]
        do {
            uploadedImageUrls = try await uploadInputImages(request: request, apiToken: request.providerSecret)
        } catch {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Failed to upload image inputs: \(error.localizedDescription)"
            )
        }

        let body = transformRequest(request: request, imageURLs: uploadedImageUrls)
        return try await performNanoBananaRequest(request: request, body: body)
    }
}

// MARK: - Nano Banana (Standard)

private struct NanoBananaRequest: Codable {
    let prompt: String
    let image_input: [String]?
    let aspect_ratio: String
    let output_format: String
}

public final class G_REPLICATE_GOOGLE_NANO_BANANA: ReplicateNanoBananaBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_GOOGLE_NANO_BANANA
    }

    override public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        0.039 * Double(request.numberOfImages ?? 1)
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        // Upload reference images if provided
        var uploadedImageUrls: [String]?
        if let referenceImages = request.clientReferenceImages, !referenceImages.isEmpty {
            do {
                uploadedImageUrls = try await uploadReferenceImages(referenceImages, apiToken: request.providerSecret)
            } catch {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: "Failed to upload reference images: \(error.localizedDescription)"
                )
            }
        }

        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let body = NanoBananaRequest(
            prompt: request.prompt,
            image_input: uploadedImageUrls,
            aspect_ratio: aspectRatio.ratio,
            output_format: "png"
        )
        return try await performNanoBananaRequest(request: request, body: body)
    }
}

// MARK: - Nano Banana Pro

private struct NanoBananaProRequest: Codable {
    let prompt: String
    let resolution: String
    let image_input: [String]?
    let aspect_ratio: String
    let output_format: String
    let safety_filter_level: String
}

public final class G_REPLICATE_GOOGLE_NANO_BANANA_PRO: ReplicateNanoBananaBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_GOOGLE_NANO_BANANA_PRO
    }

    override var maxPollingAttempts: Int {
        90
    } // Higher resolution needs more time

    override public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let resolution = request.quality ?? "2K"
        let baseCost = resolution == "4K" ? 0.30 : 0.15
        return baseCost * Double(request.numberOfImages ?? 1)
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        // Upload reference images if provided
        var uploadedImageUrls: [String]?
        if let referenceImages = request.clientReferenceImages, !referenceImages.isEmpty {
            do {
                uploadedImageUrls = try await uploadReferenceImages(referenceImages, apiToken: request.providerSecret)
            } catch {
                return ImageGenerationResponse(
                    status: .FAILED,
                    errorCode: .MODEL_ERROR,
                    errorMessage: "Failed to upload reference images: \(error.localizedDescription)"
                )
            }
        }

        let aspectRatio = getAspectRatio(dimension: request.dimensions)
        let body = NanoBananaProRequest(
            prompt: request.prompt,
            resolution: request.resolution ?? "2K",
            image_input: uploadedImageUrls,
            aspect_ratio: aspectRatio.ratio,
            output_format: "png",
            safety_filter_level: "block_only_high"
        )
        return try await performNanoBananaRequest(request: request, body: body)
    }
}
