// MARK: - G_ALIBABA_WAN_2_7_IMAGE.swift

import Foundation

public struct AlibabaWanImageTaskRequest: Codable, Equatable, Sendable {
    struct Input: Codable, Equatable {
        struct Message: Codable, Equatable {
            struct Content: Codable, Equatable {
                let image: String?
                let text: String?

                init(image: String? = nil, text: String? = nil) {
                    self.image = image
                    self.text = text
                }
            }

            let role: String
            let content: [Content]
        }

        let messages: [Message]
    }

    struct Parameters: Codable, Equatable {
        let size: String
        let n: Int
        let watermark: Bool
        let thinking_mode: Bool?
        let seed: Int?
    }

    let model: String
    let input: Input
    let parameters: Parameters
}

public class G_ALIBABA_WAN_2_7_IMAGE_BASE: ImageGenerationProtocol {
    public let modelCode: EnumProviderModelCode
    public let modelName: String
    private let pollingPolicy: ProviderPollingPolicy

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(
        modelCode: EnumProviderModelCode,
        modelName: String,
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 40,
            intervalNanoseconds: 15_000_000_000
        )
    ) {
        self.modelCode = modelCode
        self.modelName = modelName
        self.pollingPolicy = pollingPolicy
    }

    public typealias ServiceRequest = AlibabaWanImageTaskRequest

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        AlibabaModelStudioClient.pricePerImage(
            modelCode: modelCode,
            region: pricingRegion(for: request.providerSecret)
        ) * Double(max(1, request.numberOfImages ?? 1))
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    private func pricingRegion(for providerSecret: String?) -> AlibabaModelStudioClient.Region {
        guard let providerSecret,
              let credentials = try? AlibabaModelStudioClient.credentials(from: providerSecret)
        else {
            return .singapore
        }
        return credentials.region
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        (try? validatedServiceRequest(from: request)) ?? ServiceRequest(
            model: modelName,
            input: .init(messages: [
                .init(role: "user", content: [.init(text: request.prompt)]),
            ]),
            parameters: .init(
                size: "2K",
                n: 1,
                watermark: false,
                thinking_mode: true,
                seed: request.seed
            )
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        do {
            let outputURL = try AlibabaModelStudioClient.outputURL(from: response, kind: .image)
            return ImageGenerationResponse(
                generationId: UUID(),
                status: .GENERATED,
                cost: getCostEstimate(request: ImageGenerationCostRequest(from: request)),
                modelPrompt: request.prompt,
                rawResponse: response.rawResponseString,
                metadata: ["alibabaOutputURL": outputURL.absoluteString],
                actualDimensions: AlibabaModelStudioClient.actualSize(from: response)
            )
        } catch {
            return failure(message: error.localizedDescription, rawResponse: response.rawResponseString)
        }
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        do {
            let credentials = try AlibabaModelStudioClient.credentials(from: request.providerSecret)
            let serviceRequest = try validatedServiceRequest(from: request)
            let network = ProviderDependencies.shared.networkProvider
            let job = try await AlibabaModelStudioClient.create(
                body: serviceRequest,
                path: "api/v1/services/aigc/image-generation/generation",
                credentials: credentials,
                network: network
            )

            do {
                let final = try await AlibabaModelStudioClient.poll(
                    job: job,
                    credentials: credentials,
                    network: network,
                    policy: pollingPolicy
                )
                let materialized = try await AlibabaModelStudioClient.materialize(
                    response: final,
                    kind: .image,
                    network: network
                )
                var metadata = job.metadata
                metadata["alibabaOutputURL"] = materialized.url.absoluteString
                metadata["alibabaModelId"] = serviceRequest.model
                metadata["alibabaResolution"] = serviceRequest.parameters.size

                return ImageGenerationResponse(
                    generationId: UUID(),
                    status: .GENERATED,
                    base64: materialized.base64,
                    cost: AlibabaModelStudioClient.pricePerImage(
                        modelCode: modelCode,
                        region: credentials.region
                    ),
                    modelPrompt: request.prompt,
                    rawResponse: final.rawResponseString,
                    metadata: metadata,
                    actualDimensions: AlibabaModelStudioClient.actualSize(from: final)
                )
            } catch {
                return failure(
                    message: "Alibaba image request failed: \(error.localizedDescription)",
                    metadata: job.metadata
                )
            }
        } catch {
            return failure(message: "Alibaba image request failed: \(error.localizedDescription)")
        }
    }

    func validatedServiceRequest(from request: ImageGenerationRequest) throws -> ServiceRequest {
        let prompt = request.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            throw AlibabaModelStudioError.invalidInput("Alibaba requires a non-empty image prompt.")
        }
        guard prompt.count <= 5000 else {
            throw AlibabaModelStudioError.invalidInput("Alibaba image prompts cannot exceed 5000 characters.")
        }
        guard request.numberOfImages == 1 else {
            throw AlibabaModelStudioError.invalidInput("Alibaba direct image requests generate exactly one image.")
        }
        guard request.negativePrompt?.isEmpty != false else {
            throw AlibabaModelStudioError.invalidInput("Wan 2.7 Image does not accept negative prompts.")
        }
        guard request.clientMask?.isEmpty != false else {
            throw AlibabaModelStudioError.invalidInput("Wan 2.7 Image does not accept an image mask.")
        }
        guard request.dimensions.isEmpty || request.dimensions == "1:1" else {
            throw AlibabaModelStudioError.invalidInput(
                "Alibaba tier-based image generation supports square output; source images preserve their ratio."
            )
        }

        var images: [String] = []
        if let clientImage = request.clientImage {
            try images.append(AlibabaModelStudioClient.validatedImageInput(clientImage))
        }
        for reference in request.clientReferenceImages ?? [] {
            let value: String = if reference.base64Image.lowercased().hasPrefix("data:")
                || reference.base64Image.lowercased().hasPrefix("https://")
            {
                reference.base64Image
            } else {
                "data:\(reference.mimeType);base64,\(reference.base64Image)"
            }
            try images.append(AlibabaModelStudioClient.validatedImageInput(value))
        }
        guard images.count <= 9 else {
            throw AlibabaModelStudioError.invalidInput("Alibaba accepts at most nine input images.")
        }

        let requestedResolution = (request.resolution ?? "2K").uppercased()
        let allowed = modelCode == .ALIBABA_WAN_2_7_IMAGE_PRO
            ? ["1K", "2K", "4K"]
            : ["1K", "2K"]
        guard allowed.contains(requestedResolution) else {
            throw AlibabaModelStudioError.invalidInput(
                "Alibaba \(modelName) supports image resolutions: \(allowed.joined(separator: ", "))."
            )
        }
        guard images.isEmpty || requestedResolution != "4K" else {
            throw AlibabaModelStudioError.invalidInput(
                "Wan 2.7 Image Pro supports 4K only for text-to-image generation."
            )
        }
        if let seed = request.seed, !(0 ... 2_147_483_647).contains(seed) {
            throw AlibabaModelStudioError.invalidInput(
                "Alibaba seed must be between 0 and 2147483647."
            )
        }

        var content = images.map { ServiceRequest.Input.Message.Content(image: $0) }
        content.append(.init(text: prompt))
        return ServiceRequest(
            model: modelName,
            input: .init(messages: [.init(role: "user", content: content)]),
            parameters: .init(
                size: requestedResolution,
                n: 1,
                watermark: false,
                thinking_mode: images.isEmpty ? (request.promptEnhance ?? true) : nil,
                seed: request.seed
            )
        )
    }

    private func failure(
        message: String,
        rawResponse: String? = nil,
        metadata: [String: String]? = nil
    ) -> ImageGenerationResponse {
        ImageGenerationResponse(
            status: .FAILED,
            errorCode: .MODEL_ERROR,
            errorMessage: message,
            rawResponse: rawResponse,
            metadata: metadata
        )
    }
}

public final class G_ALIBABA_WAN_2_7_IMAGE_PRO: G_ALIBABA_WAN_2_7_IMAGE_BASE {
    public init(
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 40,
            intervalNanoseconds: 15_000_000_000
        )
    ) {
        super.init(
            modelCode: .ALIBABA_WAN_2_7_IMAGE_PRO,
            modelName: "wan2.7-image-pro",
            pollingPolicy: pollingPolicy
        )
    }
}

public final class G_ALIBABA_WAN_2_7_IMAGE: G_ALIBABA_WAN_2_7_IMAGE_BASE {
    public init(
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy(
            maxAttempts: 40,
            intervalNanoseconds: 15_000_000_000
        )
    ) {
        super.init(
            modelCode: .ALIBABA_WAN_2_7_IMAGE,
            modelName: "wan2.7-image",
            pollingPolicy: pollingPolicy
        )
    }
}
