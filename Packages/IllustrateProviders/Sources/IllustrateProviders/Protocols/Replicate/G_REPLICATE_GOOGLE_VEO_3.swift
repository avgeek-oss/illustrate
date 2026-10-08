// MARK: - G_REPLICATE_GOOGLE_VEO_3.swift

// Implementation for Google Veo 3 video models via Replicate.
// Supports Veo 3 and Veo 3 Fast with audio generation.

import Foundation

/// Base adapter for Google Veo 3 video models via Replicate.
public class G_REPLICATE_GOOGLE_VEO_3: VideoGenerationProtocol {
    let modelCode: EnumProviderModelCode

    public init(modelCode: EnumProviderModelCode = .REPLICATE_GOOGLE_VEO_3) {
        self.modelCode = modelCode
    }

    /// Returns cost per second based on model variant and audio
    /// - Veo 3 / Veo 3.1: $0.40/sec with audio, $0.20/sec without
    /// - Veo 3 Fast / Veo 3.1 Fast: $0.15/sec with audio, $0.10/sec without
    private func getCostPerSecond(withAudio: Bool) -> Double {
        switch modelCode {
        case .REPLICATE_GOOGLE_VEO_3, .REPLICATE_GOOGLE_VEO_3_1:
            withAudio ? 0.40 : 0.20
        case .REPLICATE_GOOGLE_VEO_3_FAST, .REPLICATE_GOOGLE_VEO_3_1_FAST:
            withAudio ? 0.15 : 0.10
        default:
            withAudio ? 0.40 : 0.20
        }
    }

    /// Whether this model supports Veo 3.1 features (last frame, reference images)
    private var supportsVeo31Features: Bool {
        modelCode == .REPLICATE_GOOGLE_VEO_3_1 || modelCode == .REPLICATE_GOOGLE_VEO_3_1_FAST
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let duration = Double(request.durationSeconds ?? 8)
        // Default to with audio for cost estimates
        let costPerSecond = getCostPerSecond(withAudio: true)
        return costPerSecond * duration
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        if cost == 0 { return "Free" }
        return formatEstimatedCost(cost)
    }

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public struct ServiceRequest: Codable, Sendable {
        let prompt: String
        let duration: Int
        let aspect_ratio: String
        let resolution: String
        let image: String?
        let last_frame: String?
        let reference_images: [String]?
        let negative_prompt: String?
        let generate_audio: Bool
        let seed: Int?

        init(
            prompt: String,
            duration: Int = 8,
            aspectRatio: String = "16:9",
            resolution: String = "1080p",
            image: String? = nil,
            lastFrame: String? = nil,
            referenceImages: [String]? = nil,
            negativePrompt: String? = nil,
            generateAudio: Bool = true,
            seed: Int? = nil
        ) {
            self.prompt = prompt
            self.duration = duration
            aspect_ratio = aspectRatio
            self.resolution = resolution
            self.image = image
            last_frame = lastFrame
            reference_images = referenceImages
            negative_prompt = negativePrompt
            generate_audio = generateAudio
            self.seed = seed
        }
    }

    func transformRequest(
        request: VideoGenerationRequest,
        inputImageUrl: String? = nil,
        lastFrameUrl: String? = nil,
        referenceImageUrls: [String]? = nil
    ) -> ServiceRequest {
        let aspectRatio = getAspectRatio(dimension: request.dimensions)

        return ServiceRequest(
            prompt: request.prompt ?? "",
            duration: request.durationSeconds ?? 8,
            aspectRatio: aspectRatio.ratio,
            resolution: request.resolution ?? "1080p",
            image: inputImageUrl,
            lastFrame: supportsVeo31Features ? lastFrameUrl : nil,
            referenceImages: supportsVeo31Features ? referenceImageUrls : nil,
            negativePrompt: request.negativePrompt,
            generateAudio: request.generateAudio ?? true,
            seed: request.seed
        )
    }

    /// Protocol conformance
    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        transformRequest(request: request, inputImageUrl: nil, lastFrameUrl: nil, referenceImageUrls: nil)
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        switch response {
        case let .dictionary(_, data):
            if let videoUrl = data["output"] as? String {
                let url = URL(string: videoUrl)!
                let videoData = try Data(contentsOf: url)
                let base64 = videoData.base64EncodedString()

                return VideoGenerationResponse(
                    status: .GENERATED,
                    base64: base64,
                    cost: getCostEstimate(request: VideoGenerationCostRequest(from: request))
                )
            }
            if let output = data["output"] as? [String],
               let videoUrl = output.first
            {
                let url = URL(string: videoUrl)!
                let videoData = try Data(contentsOf: url)
                let base64 = videoData.base64EncodedString()

                return VideoGenerationResponse(
                    status: .GENERATED,
                    base64: base64,
                    cost: getCostEstimate(request: VideoGenerationCostRequest(from: request))
                )
            }
            // Handle errors
            if let errorList = data["error"] as? [String],
               let error = errorList.first
            {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: error
                )
            }
            if let error = data["error"] as? String {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: error
                )
            }
        default:
            return createInvalidVideoResponseError(
                response: response,
                modelCode: model.modelCode,
                customMessage: "Unexpected response"
            )
        }

        return createInvalidVideoResponseError(
            response: response,
            modelCode: model.modelCode
        )
    }

    func pollForResult(
        requestId: String,
        url: URL,
        headers: [String: String],
        maxAttempts: Int = 180
    ) async throws -> NetworkResponseData {
        var attempts = 0
        while attempts < maxAttempts {
            try await Task.sleep(nanoseconds: 5_000_000_000)

            do {
                let response = try await ProviderDependencies.shared.networkProvider.performRequest(
                    url: url.appendingPathComponent("/\(requestId)"),
                    method: "GET",
                    body: nil as String?,
                    headers: headers,
                    attachments: nil
                )

                switch response {
                case let .dictionary(_, data):
                    if let status = data["status"] as? String,
                       status == "succeeded" || status == "failed" || status == "canceled"
                    {
                        return response
                    }
                default:
                    break
                }
            } catch {
                throw NSError(domain: "Polling failed", code: -1, userInfo: nil)
            }

            attempts += 1
        }

        throw NSError(domain: "Polling exceeded max attempts", code: -1, userInfo: nil)
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        guard let url = URL(string: model.modelGenerateBaseURL) else {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Invalid URL"
            )
        }

        // Upload source image if provided
        var inputImageUrl: String? = nil
        if let clientImage = request.clientImage {
            do {
                inputImageUrl = try await ReplicateFileUploader.uploadImage(
                    base64Image: clientImage,
                    apiToken: request.providerSecret
                )
            } catch {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: "Failed to upload source image: \(error.localizedDescription)"
                )
            }
        }

        // Upload last frame if provided (Veo 3.1 only)
        var lastFrameUrl: String? = nil
        if supportsVeo31Features, let clientLastFrame = request.clientLastFrame {
            do {
                lastFrameUrl = try await ReplicateFileUploader.uploadImage(
                    base64Image: clientLastFrame,
                    apiToken: request.providerSecret
                )
            } catch {
                return VideoGenerationResponse(
                    status: .FAILED,
                    errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                    errorMessage: "Failed to upload last frame: \(error.localizedDescription)"
                )
            }
        }

        // Upload reference images if provided (Veo 3.1 only)
        var referenceImageUrls: [String]? = nil
        if supportsVeo31Features, let referenceImages = request.clientReferenceImages, !referenceImages.isEmpty {
            var uploadedUrls: [String] = []
            for (index, refImage) in referenceImages.prefix(3).enumerated() {
                do {
                    let url = try await ReplicateFileUploader.uploadImage(
                        base64Image: refImage.base64Image,
                        apiToken: request.providerSecret
                    )
                    uploadedUrls.append(url)
                } catch {
                    return VideoGenerationResponse(
                        status: .FAILED,
                        errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                        errorMessage: "Failed to upload reference image: \(error.localizedDescription)"
                    )
                }
            }
            referenceImageUrls = uploadedUrls
        }

        let headers = [
            "Authorization": "Bearer \(request.providerSecret)",
            "Content-Type": "application/json",
        ]

        let serviceRequest = transformRequest(
            request: request,
            inputImageUrl: inputImageUrl,
            lastFrameUrl: lastFrameUrl,
            referenceImageUrls: referenceImageUrls
        )

        do {
            let response = try await ProviderDependencies.shared.networkProvider.performRequest(
                url: url,
                method: "POST",
                body: ["input": serviceRequest],
                headers: headers,
                attachments: nil
            )

            guard case let .dictionary(_, data) = response,
                  let predictionId = data["id"] as? String
            else {
                return createInvalidVideoResponseError(
                    response: response,
                    modelCode: model.modelCode,
                    customMessage: "Failed to create prediction"
                )
            }

            // Poll for result
            guard let statusUrl = model.statusURL else {
                return createInvalidVideoStatusURLError()
            }

            let finalResponse = try await pollForResult(
                requestId: predictionId,
                url: statusUrl,
                headers: headers
            )

            return try transformResponse(request: request, response: finalResponse)
        } catch {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                errorMessage: "Request failed: \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - Subclasses for specific models

public class G_REPLICATE_GOOGLE_VEO_3_FAST: G_REPLICATE_GOOGLE_VEO_3 {
    public init() {
        super.init(modelCode: .REPLICATE_GOOGLE_VEO_3_FAST)
    }
}

public class G_REPLICATE_GOOGLE_VEO_3_1: G_REPLICATE_GOOGLE_VEO_3 {
    public init() {
        super.init(modelCode: .REPLICATE_GOOGLE_VEO_3_1)
    }
}

public class G_REPLICATE_GOOGLE_VEO_3_1_FAST: G_REPLICATE_GOOGLE_VEO_3 {
    public init() {
        super.init(modelCode: .REPLICATE_GOOGLE_VEO_3_1_FAST)
    }
}
