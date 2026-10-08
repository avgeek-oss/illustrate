import Foundation

public class G_XAI_GROK_IMAGINE_VIDEO_BASE: VideoGenerationProtocol {
    private static let defaultDuration = 8

    public enum Mode: Sendable {
        case standard
        case imageToVideo15
    }

    public let modelCode: EnumProviderModelCode
    public let upstreamModel: String
    public let mode: Mode
    private let pollingPolicy: ProviderPollingPolicy

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(
        modelCode: EnumProviderModelCode,
        upstreamModel: String,
        mode: Mode,
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 5_000_000_000
        )
    ) {
        self.modelCode = modelCode
        self.upstreamModel = upstreamModel
        self.mode = mode
        self.pollingPolicy = pollingPolicy
    }

    public struct ImageInput: Codable, Equatable, Sendable {
        public let url: String

        public init(url: String) {
            self.url = url
        }
    }

    public struct ServiceRequest: Codable, Equatable, Sendable {
        public let model: String
        public let prompt: String?
        public let image: ImageInput?
        public let referenceImages: [ImageInput]?
        public let duration: Int
        public let aspectRatio: String
        public let resolution: String

        enum CodingKeys: String, CodingKey {
            case model
            case prompt
            case image
            case referenceImages = "reference_images"
            case duration
            case aspectRatio = "aspect_ratio"
            case resolution
        }

        public init(
            model: String,
            prompt: String?,
            image: ImageInput? = nil,
            referenceImages: [ImageInput]? = nil,
            duration: Int,
            aspectRatio: String,
            resolution: String
        ) {
            self.model = model
            self.prompt = prompt
            self.image = image
            self.referenceImages = referenceImages
            self.duration = duration
            self.aspectRatio = aspectRatio
            self.resolution = resolution
        }
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        let resolution = canonicalResolution(request.resolution)
        let duration = max(1, request.durationSeconds ?? Self.defaultDuration)
        let count = max(1, request.numberOfVideos ?? 1)
        let referenceCount = request.referenceImageCount > 0
            ? request.referenceImageCount
            : (request.hasReferenceImages ? 1 : 0)
        let inputCount = (request.hasSourceImage ? 1 : 0) + referenceCount
        let inputPrice = mode == .imageToVideo15 ? 0.01 : 0.002
        let outputPrice = switch (mode, resolution) {
        case (.imageToVideo15, "1080p"): 0.25
        case (.imageToVideo15, "720p"): 0.14
        case (.imageToVideo15, _): 0.08
        case (.standard, "720p"): 0.07
        default: 0.05
        }
        return (outputPrice * Double(duration) + inputPrice * Double(inputCount)) * Double(count)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        (try? validatedServiceRequest(from: request)) ?? ServiceRequest(
            model: upstreamModel,
            prompt: request.prompt,
            duration: request.durationSeconds ?? Self.defaultDuration,
            aspectRatio: request.dimensions,
            resolution: canonicalResolution(request.resolution)
        )
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        guard case let .dictionary(statusCode, data) = response,
              (200 ... 299).contains(statusCode),
              (data["status"] as? String)?.lowercased() == "done",
              let video = data["video"] as? [String: Any],
              let output = video["url"] as? String
        else {
            return createInvalidVideoResponseError(
                response: response,
                modelCode: modelCode,
                customMessage: "xAI completed without a valid video response."
            )
        }

        if video["respect_moderation"] as? Bool == false
            || data["respect_moderation"] as? Bool == false
        {
            return failure(
                message: "xAI video response did not pass moderation.",
                rawResponse: response.rawResponseString
            )
        }

        guard let durationValue = XAIClient.numericDouble(video["duration"]) else {
            return failure(
                message: "xAI video response omitted its duration.",
                rawResponse: response.rawResponseString
            )
        }

        var metadata = ["xaiOutputURL": output]
        if let providerModel = data["model"] as? String, !providerModel.isEmpty {
            metadata["xaiModel"] = providerModel
        }
        if let progress = XAIClient.numericDouble(data["progress"]) {
            metadata["providerProgress"] = String(progress)
        }
        let actualDuration = Int(durationValue.rounded())

        return VideoGenerationResponse(
            status: .GENERATED,
            videoUrl: output,
            cost: XAIClient.usageCost(from: data) ?? atomicCost(for: request),
            modelPrompt: request.prompt,
            rawResponse: response.rawResponseString,
            metadata: metadata,
            actualDimensions: request.dimensions,
            actualDuration: actualDuration
        )
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        do {
            let credentials = try ProviderCredentialConfiguration(secret: request.providerSecret)
            let apiKey = try credentials.requireAPIKey()
            let serviceRequest = try validatedServiceRequest(from: request)
            guard let createURL = model.generateURL, let statusRoot = model.statusURL else {
                return failure(message: "Invalid xAI video endpoint configuration.")
            }
            let network = ProviderDependencies.shared.networkProvider
            let envelope = try await network.performSingleAttemptRequest(
                url: createURL,
                method: "POST",
                body: serviceRequest,
                headers: XAIClient.headers(apiKey: apiKey),
                attachments: nil
            )
            guard (200 ... 299).contains(envelope.statusCode) else {
                return failure(
                    message: XAIClient.httpFailureMessage(envelope: envelope, operation: "video create"),
                    rawResponse: envelope.response?.rawResponseString ?? envelope.bodyString
                )
            }
            guard let created = envelope.response,
                  case let .dictionary(_, createData) = created,
                  let requestId = createData["request_id"] as? String,
                  Self.isValidRequestID(requestId)
            else {
                return failure(
                    message: "xAI video create response omitted a valid request ID.",
                    rawResponse: envelope.response?.rawResponseString ?? envelope.bodyString
                )
            }

            let statusURL = statusRoot.appendingPathComponent(requestId)
            let jobMetadata = [
                ProviderJobMetadataKey.jobId: requestId,
                ProviderJobMetadataKey.statusURL: statusURL.absoluteString,
            ]

            do {
                let final = try await ProviderAsyncJobPoller.poll(
                    policy: pollingPolicy,
                    fetch: {
                        try await network.performRequest(
                            url: statusURL,
                            method: "GET",
                            body: nil as String?,
                            headers: XAIClient.headers(apiKey: apiKey, includesJSONBody: false),
                            attachments: nil
                        )
                    },
                    classify: Self.classify
                )
                var transformed = try transformResponse(request: request, response: final)
                guard transformed.status == .GENERATED,
                      let output = transformed.videoUrl
                else {
                    transformed.metadata = jobMetadata.merging(transformed.metadata ?? [:]) { _, current in current }
                    return transformed
                }

                let outputURL = try XAIClient.validatedOutputURL(output)
                transformed.base64 = try await ProviderMediaMaterializer.base64(
                    from: outputURL,
                    network: network
                )
                transformed.metadata?.removeValue(forKey: "xaiOutputURL")
                var metadata = jobMetadata
                for (key, value) in transformed.metadata ?? [:] {
                    metadata[key] = value
                }
                transformed.metadata = metadata
                return transformed
            } catch {
                return failure(
                    message: "xAI video request failed: \(error.localizedDescription)",
                    metadata: jobMetadata
                )
            }
        } catch {
            return failure(message: "xAI video request failed: \(error.localizedDescription)")
        }
    }

    public static func classify(_ response: NetworkResponseData) throws -> ProviderAsyncJobState {
        guard case let .dictionary(statusCode, data) = response else {
            return .failed("xAI video status response was not a JSON object.")
        }
        guard (200 ... 299).contains(statusCode) else {
            let detail = XAIClient.providerError(in: data).map { ": \($0)" } ?? ""
            return .failed("xAI video status failed with HTTP \(statusCode)\(detail).")
        }
        guard let status = data["status"] as? String, !status.isEmpty else {
            return .failed("xAI video status response omitted status.")
        }

        switch status.lowercased() {
        case "pending":
            return .pending
        case "done":
            return .succeeded
        case "failed":
            return .failed(failureMessage(from: data))
        case "expired":
            return .failed("xAI video request expired before completion.")
        default:
            // xAI's official SDK intentionally continues polling unrecognized
            // future states. The shared poller still bounds the wait.
            return .pending
        }
    }

    private func validatedServiceRequest(from request: VideoGenerationRequest) throws -> ServiceRequest {
        guard request.clientVideo?.isEmpty != false else {
            throw XAIAdapterError.invalidInput("xAI video edit and extension are not supported by this adapter.")
        }
        guard request.clientMask?.isEmpty != false, request.clientLastFrame?.isEmpty != false else {
            throw XAIAdapterError.invalidInput("xAI video generation does not accept masks or last frames.")
        }

        let prompt = try XAIClient.validatedPrompt(request.prompt ?? "", required: false)
        let duration = request.durationSeconds ?? Self.defaultDuration
        guard (1 ... 15).contains(duration) else {
            throw XAIAdapterError.invalidInput("xAI video duration must be between 1 and 15 seconds.")
        }
        guard Self.supportedAspectRatios.contains(request.dimensions) else {
            throw XAIAdapterError.invalidInput("xAI does not support the requested video aspect ratio.")
        }
        let resolution = canonicalResolution(request.resolution)
        let supportedResolutions: Set<String> = mode == .imageToVideo15
            ? ["480p", "720p", "1080p"]
            : ["480p", "720p"]
        guard supportedResolutions.contains(resolution) else {
            throw XAIAdapterError.invalidInput("xAI does not support the requested video resolution for this model.")
        }

        let sourceImage = try request.clientImage.map {
            try ImageInput(url: XAIClient.validatedImageURI($0))
        }
        let references = try (request.clientReferenceImages ?? []).map {
            try ImageInput(url: XAIClient.validatedImageURI($0.base64Image, mimeType: $0.mimeType))
        }
        guard sourceImage == nil || references.isEmpty else {
            throw XAIAdapterError.invalidInput("xAI video requests cannot combine a source image with references.")
        }
        guard references.count <= 7 else {
            throw XAIAdapterError.invalidInput("xAI reference-to-video accepts at most seven reference images.")
        }

        switch mode {
        case .standard:
            guard prompt != nil || sourceImage != nil || !references.isEmpty else {
                throw XAIAdapterError.invalidInput("xAI video generation requires a prompt or image input.")
            }
            if !references.isEmpty {
                guard prompt != nil else {
                    throw XAIAdapterError.invalidInput("xAI reference-to-video requires a non-empty prompt.")
                }
                guard duration <= 10 else {
                    throw XAIAdapterError.invalidInput(
                        "xAI reference-to-video duration cannot exceed 10 seconds."
                    )
                }
            }
        case .imageToVideo15:
            guard let sourceImage else {
                throw XAIAdapterError.invalidInput("Grok Imagine Video 1.5 requires a source image.")
            }
            guard references.isEmpty else {
                throw XAIAdapterError.invalidInput("Grok Imagine Video 1.5 does not support reference-image mode.")
            }
            return ServiceRequest(
                model: upstreamModel,
                prompt: prompt,
                image: sourceImage,
                duration: duration,
                aspectRatio: request.dimensions,
                resolution: resolution
            )
        }

        return ServiceRequest(
            model: upstreamModel,
            prompt: prompt,
            image: sourceImage,
            referenceImages: references.isEmpty ? nil : references,
            duration: duration,
            aspectRatio: request.dimensions,
            resolution: resolution
        )
    }

    private func canonicalResolution(_ value: String?) -> String {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized?.isEmpty == false ? normalized! : "720p"
    }

    private func atomicCost(for request: VideoGenerationRequest) -> Double {
        getCostEstimate(request: VideoGenerationCostRequest(
            dimensions: request.dimensions,
            durationSeconds: request.durationSeconds,
            numberOfVideos: 1,
            resolution: request.resolution,
            generateAudio: request.generateAudio,
            hasSourceImage: request.clientImage?.isEmpty == false,
            hasReferenceImages: request.clientReferenceImages?.isEmpty == false,
            referenceImageCount: request.clientReferenceImages?.count ?? 0
        ))
    }

    private func failure(
        message: String,
        rawResponse: String? = nil,
        metadata: [String: String]? = nil
    ) -> VideoGenerationResponse {
        VideoGenerationResponse(
            status: .FAILED,
            errorCode: .MODEL_ERROR,
            errorMessage: message,
            rawResponse: rawResponse,
            metadata: metadata
        )
    }

    private static func failureMessage(from data: [String: Any]) -> String {
        let detail = XAIClient.providerError(in: data) ?? "xAI video generation failed."
        return "xAI video generation failed: \(detail)"
    }

    private static func isValidRequestID(_ value: String) -> Bool {
        !value.isEmpty
            && value.utf8.count <= 256
            && value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    private static let supportedAspectRatios: Set = [
        "1:1", "16:9", "9:16", "4:3", "3:4", "3:2", "2:3",
    ]
}

public final class G_XAI_GROK_IMAGINE_VIDEO: G_XAI_GROK_IMAGINE_VIDEO_BASE {
    public init(
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 5_000_000_000
        )
    ) {
        super.init(
            modelCode: .XAI_GROK_IMAGINE_VIDEO,
            upstreamModel: "grok-imagine-video",
            mode: .standard,
            pollingPolicy: pollingPolicy
        )
    }
}

public final class G_XAI_GROK_IMAGINE_VIDEO_1_5: G_XAI_GROK_IMAGINE_VIDEO_BASE {
    public init(
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 120,
            intervalNanoseconds: 5_000_000_000
        )
    ) {
        super.init(
            modelCode: .XAI_GROK_IMAGINE_VIDEO_1_5,
            upstreamModel: "grok-imagine-video-1.5",
            mode: .imageToVideo15,
            pollingPolicy: pollingPolicy
        )
    }
}
