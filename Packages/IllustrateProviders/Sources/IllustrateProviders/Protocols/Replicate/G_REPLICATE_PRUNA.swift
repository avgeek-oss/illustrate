// MARK: - G_REPLICATE_PRUNA.swift

// PrunaAI models via Replicate:
// - prunaai/p-image (text-to-image)
// - prunaai/p-image-edit (image editing with reference images)
// - prunaai/flux-fast (fast FLUX text-to-image)
// - prunaai/flux-kontext-fast (fast FLUX image-to-image)
// - prunaai/z-image-turbo (super fast 6B parameter text-to-image)
// - prunaai/z-image-turbo-img2img (image-to-image with LoRA support)

import Foundation

// MARK: - Base Class

public class ReplicatePrunaBase: ImageGenerationProtocol {
    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override modelCode")
    }

    var baseCost: Double {
        0.005
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
        baseCost * Double(request.numberOfImages ?? 1)
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
        headers: [String: String],
        maxAttempts: Int = 60
    ) async throws -> NetworkResponseData {
        var attempts = 0
        while attempts < maxAttempts {
            try await Task.sleep(nanoseconds: 2_000_000_000)

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

    func performReplicateRequest(
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

    func calculateDimensions(from dimensions: String, baseSize: Int = 1024) -> (width: Int, height: Int) {
        let aspectRatio = getAspectRatio(dimension: dimensions)
        if aspectRatio.width >= aspectRatio.height {
            return (baseSize * aspectRatio.width / aspectRatio.height, baseSize)
        } else {
            return (baseSize, baseSize * aspectRatio.height / aspectRatio.width)
        }
    }

    private func downloadAndReturnImage(
        urlStr: String,
        request: ImageGenerationRequest
    ) throws -> ImageGenerationResponse {
        let url = URL(string: urlStr)!
        let imageData = try Data(contentsOf: url)
        return ImageGenerationResponse(
            status: .GENERATED,
            base64: imageData.base64EncodedString(),
            cost: getCostEstimate(request: ImageGenerationCostRequest(from: request))
        )
    }
}

// MARK: - P-Image (Text-to-Image)

private struct PImageRequest: Codable {
    let prompt: String
    let aspect_ratio: String
    let width: Int?
    let height: Int?
    let prompt_upsampling: Bool
    let seed: Int?
    let disable_safety_checker: Bool
}

public final class G_REPLICATE_PRUNA_P_IMAGE: ReplicatePrunaBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_PRUNA_P_IMAGE
    }

    override var baseCost: Double {
        0.005
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)

        // Parse custom dimensions if provided (format: "WIDTHxHEIGHT")
        var width: Int?
        var height: Int?
        var ratio = aspectRatio.ratio

        if request.dimensions.contains("x") {
            let parts = request.dimensions.lowercased().split(separator: "x")
            if parts.count == 2, let w = Int(parts[0]), let h = Int(parts[1]) {
                width = w
                height = h
                ratio = "custom"
            }
        }

        let body = PImageRequest(
            prompt: request.prompt,
            aspect_ratio: ratio,
            width: width,
            height: height,
            prompt_upsampling: request.promptEnhance ?? false,
            seed: request.seed,
            disable_safety_checker: false
        )
        return try await performReplicateRequest(request: request, body: body)
    }
}

// MARK: - P-Image Edit (Image Editing)

private struct PImageEditRequest: Codable {
    let prompt: String
    let images: [String]?
    let turbo: Bool
    let aspect_ratio: String
    let seed: Int?
    let disable_safety_checker: Bool
}

public final class G_REPLICATE_PRUNA_P_IMAGE_EDIT: ReplicatePrunaBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_PRUNA_P_IMAGE_EDIT
    }

    override var baseCost: Double {
        0.01
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
        let ratio = (uploadedImageUrls != nil && !uploadedImageUrls!.isEmpty) ? "1:1" : aspectRatio.ratio

        let body = PImageEditRequest(
            prompt: request.prompt,
            images: uploadedImageUrls,
            turbo: !(request.promptEnhance ?? false), // turbo=false for complex tasks
            aspect_ratio: ratio,
            seed: request.seed,
            disable_safety_checker: false
        )
        return try await performReplicateRequest(request: request, body: body)
    }
}

// MARK: - FLUX Fast (Text-to-Image)

private struct FluxFastRequest: Codable {
    let prompt: String
    let aspect_ratio: String
    let image_size: Int
    let guidance: Double
    let num_inference_steps: Int
    let seed: Int?
    let speed_mode: String
    let output_format: String
    let output_quality: Int
}

public final class G_REPLICATE_PRUNA_FLUX_FAST: ReplicatePrunaBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_PRUNA_FLUX_FAST
    }

    override var baseCost: Double {
        0.005
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)

        let body = FluxFastRequest(
            prompt: request.prompt,
            aspect_ratio: aspectRatio.ratio,
            image_size: 1024,
            guidance: request.guidance ?? 3.5,
            num_inference_steps: request.steps ?? 28,
            seed: request.seed,
            speed_mode: "Extra Juiced 🔥 (more speed)",
            output_format: "png",
            output_quality: 100
        )
        return try await performReplicateRequest(request: request, body: body)
    }
}

// MARK: - FLUX Kontext Fast (Image-to-Image)

private struct FluxKontextFastRequest: Codable {
    let prompt: String
    let img_cond_path: String
    let aspect_ratio: String
    let image_size: Int
    let guidance: Double
    let num_inference_steps: Int
    let seed: Int?
    let speed_mode: String
    let output_format: String
    let output_quality: Int
}

public final class G_REPLICATE_PRUNA_FLUX_KONTEXT_FAST: ReplicatePrunaBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_PRUNA_FLUX_KONTEXT_FAST
    }

    override var baseCost: Double {
        0.01
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        // This model REQUIRES a source image
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "FLUX Kontext Fast requires an input image"
            )
        }

        let sourceImageUrl: String
        do {
            sourceImageUrl = try await ReplicateFileUploader.uploadImage(
                base64Image: clientImage,
                apiToken: request.providerSecret
            )
        } catch {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Failed to upload source image: \(error.localizedDescription)"
            )
        }

        let body = FluxKontextFastRequest(
            prompt: request.prompt,
            img_cond_path: sourceImageUrl,
            aspect_ratio: "1:1",
            image_size: 1024,
            guidance: request.guidance ?? 3.5,
            num_inference_steps: request.steps ?? 30,
            seed: request.seed,
            speed_mode: "Extra Juiced 🔥 (more speed)",
            output_format: "png",
            output_quality: 100
        )
        return try await performReplicateRequest(request: request, body: body)
    }
}

// MARK: - Z-Image Turbo (Text-to-Image)

private struct ZImageTurboRequest: Codable {
    let prompt: String
    let width: Int
    let height: Int
    let num_inference_steps: Int
    let guidance_scale: Double
    let seed: Int?
    let go_fast: Bool
    let output_format: String
    let output_quality: Int
}

public final class G_REPLICATE_PRUNA_Z_IMAGE_TURBO: ReplicatePrunaBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_PRUNA_Z_IMAGE_TURBO
    }

    override var baseCost: Double {
        0.005
    } // $0.005 at 1MP

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        let dims = calculateDimensions(from: request.dimensions, baseSize: 1024)

        let body = ZImageTurboRequest(
            prompt: request.prompt,
            width: dims.width,
            height: dims.height,
            num_inference_steps: request.steps ?? 8,
            guidance_scale: 0, // Must be 0 for turbo models
            seed: request.seed,
            go_fast: true,
            output_format: "jpg",
            output_quality: 80
        )
        return try await performReplicateRequest(request: request, body: body)
    }
}

// MARK: - Z-Image Turbo Img2Img (Image-to-Image with LoRA)

private struct ZImageTurboI2IInput: Codable {
    let prompt: String
    let image: String
    let strength: Double
    let num_inference_steps: Int
    let guidance_scale: Double
    let seed: Int?
    let output_format: String
    let output_quality: Int
}

private struct ZImageTurboI2IRequest: Codable {
    let version: String
    let input: ZImageTurboI2IInput
}

public final class G_REPLICATE_PRUNA_Z_IMAGE_TURBO_I2I: ReplicatePrunaBase {
    override public init() {}
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_PRUNA_Z_IMAGE_TURBO_I2I
    }

    override var baseCost: Double {
        0.0059
    }

    /// Model version hash for the predictions endpoint
    private let modelVersion = "5c958e90e0f904240629ee35c69196e3bd790b5528c0696705ebdb1656871dd8"

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        // This model REQUIRES a source image
        guard let clientImage = request.clientImage else {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Z-Image Turbo I2I requires an input image"
            )
        }

        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return ImageGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: "Invalid URL")
        }

        let sourceImageUrl: String
        do {
            sourceImageUrl = try await ReplicateFileUploader.uploadImage(
                base64Image: clientImage,
                apiToken: request.providerSecret
            )
        } catch {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Failed to upload source image: \(error.localizedDescription)"
            )
        }

        // Strength: guidance value mapped to 0.0-1.0 range (default 0.6)
        let strength = request.guidance ?? 0.6

        let input = ZImageTurboI2IInput(
            prompt: request.prompt,
            image: sourceImageUrl,
            strength: strength,
            num_inference_steps: request.steps ?? 8,
            guidance_scale: 0, // Must be 0 for turbo models
            seed: request.seed,
            output_format: "jpg",
            output_quality: 80
        )

        let body = ZImageTurboI2IRequest(version: modelVersion, input: input)

        let headers = [
            "Authorization": "Bearer \(request.providerSecret)",
            "Content-Type": "application/json",
        ]

        do {
            let response = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: body,
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
}
