// MARK: - G_BFL_FLUX_2.swift

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public class G_BFL_FLUX_2: ImageGenerationProtocol {
    public let modelCode: EnumProviderModelCode
    public let textPricePerMegapixel: Double
    public let editPricePerMegapixel: Double
    private let pollingPolicy: ProviderPollingPolicy

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public init(
        modelCode: EnumProviderModelCode,
        textPricePerMegapixel: Double,
        editPricePerMegapixel: Double,
        pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy()
    ) {
        self.modelCode = modelCode
        self.textPricePerMegapixel = textPricePerMegapixel
        self.editPricePerMegapixel = editPricePerMegapixel
        self.pollingPolicy = pollingPolicy
    }

    public func getCostEstimate(request: ImageGenerationCostRequest) -> Double {
        let megapixels = Self.megapixels(for: request.dimensions ?? "1024x1024")
        let unitPrice = request.hasSourceImage ? editPricePerMegapixel : textPricePerMegapixel
        return unitPrice * max(1, megapixels) * Double(max(1, request.numberOfImages ?? 1))
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    public struct ServiceRequest: Codable, Sendable {
        public let prompt: String
        public let width: Int
        public let height: Int
        public let input_image: String?
        public let seed: Int?
        public let safety_tolerance: Int?
        public let prompt_upsampling: Bool?
        public let output_format: String
    }

    public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        let dimensions = Self.dimensions(for: request.dimensions)
        return ServiceRequest(
            prompt: request.prompt,
            width: dimensions.width,
            height: dimensions.height,
            input_image: request.clientImage.map(Self.dataURI),
            seed: request.seed,
            safety_tolerance: request.safetyTolerance,
            prompt_upsampling: request.promptEnhance,
            output_format: "png"
        )
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        guard case let .dictionary(_, data) = response,
              let result = data["result"] as? [String: Any],
              let sample = result["sample"] as? String,
              !sample.isEmpty
        else {
            return createInvalidResponseError(response: response, modelCode: modelCode)
        }

        return ImageGenerationResponse(
            status: .GENERATED,
            cost: atomicCost(for: request),
            modelPrompt: request.prompt,
            rawResponse: sample,
            metadata: Self.resultMetadata(data)
        )
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        guard let url = model.generateURL else {
            return failure(message: "Invalid Black Forest Labs generation URL")
        }

        do {
            let credentials = try ProviderCredentialConfiguration(secret: request.providerSecret)
            let apiKey = try credentials.requireAPIKey()
            let network = ProviderDependencies.shared.networkProvider
            let headers = ["x-key": apiKey, "Accept": "application/json"]
            let createdEnvelope = try await network.performSingleAttemptRequest(
                url: url,
                method: "POST",
                body: transformRequest(request: request),
                headers: headers.merging(["Content-Type": "application/json"]) { current, _ in current },
                attachments: nil
            )
            let created = try createdEnvelope.requireParsedResponse()
            guard (200 ... 299).contains(createdEnvelope.statusCode) else {
                let data: [String: Any] = if case let .dictionary(_, responseData) = created {
                    responseData
                } else {
                    [:]
                }
                let detail = Self.failureMessage(
                    from: data,
                    fallback: "Black Forest Labs rejected the request."
                )
                return failure(
                    message: "Black Forest Labs create failed with HTTP \(createdEnvelope.statusCode): \(detail)",
                    response: created
                )
            }
            let job = try Self.job(from: created)
            let policy = pollingPolicy

            let final = try await ProviderAsyncJobPoller.poll(
                policy: policy,
                fetch: {
                    try await network.performRequest(
                        url: job.pollingURL,
                        method: "GET",
                        body: nil as String?,
                        headers: headers,
                        attachments: nil
                    )
                },
                classify: Self.classify
            )

            var result = try transformResponse(request: request, response: final)
            guard result.status == .GENERATED,
                  let output = result.rawResponse,
                  let outputURL = URL(string: output)
            else {
                return result
            }

            var downloadRequest = URLRequest(url: outputURL)
            downloadRequest.httpMethod = "GET"
            let downloaded = try await network.performRawRequest(downloadRequest)
            guard case let .image(_, base64, _) = downloaded else {
                return failure(
                    message: "Black Forest Labs returned an unsupported image response",
                    response: downloaded
                )
            }

            result.base64 = base64
            result.rawResponse = final.rawResponseString
            var metadata = result.metadata ?? [:]
            metadata[ProviderJobMetadataKey.jobId] = job.id
            metadata[ProviderJobMetadataKey.statusURL] = job.pollingURL.absoluteString
            result.metadata = metadata
            return result
        } catch {
            return failure(message: "Black Forest Labs request failed: \(error.localizedDescription)")
        }
    }

    public static func classify(_ response: NetworkResponseData) throws -> ProviderAsyncJobState {
        guard case let .dictionary(_, data) = response,
              let status = data["status"] as? String
        else {
            return .failed("Black Forest Labs returned a status without a state.")
        }

        switch status.lowercased() {
        case "ready": return .succeeded
        case "pending", "processing", "running": return .pending
        case "error", "failed", "request moderated", "content moderated", "task not found":
            return .failed(Self.failureMessage(from: data, fallback: status))
        default:
            return .failed("Unknown Black Forest Labs status: \(status)")
        }
    }

    public static func dimensions(for value: String) -> (width: Int, height: Int) {
        let parts = value.split(separator: "x", maxSplits: 1)
        guard parts.count == 2,
              let width = Int(parts[0]),
              let height = Int(parts[1]),
              width >= 256,
              height >= 256
        else {
            return (1024, 1024)
        }
        return (width, height)
    }

    private struct Job {
        let id: String
        let pollingURL: URL
    }

    private static func job(from response: NetworkResponseData) throws -> Job {
        guard case let .dictionary(_, data) = response,
              let id = data["id"] as? String,
              let pollingURLString = data["polling_url"] as? String,
              let pollingURL = URL(string: pollingURLString)
        else {
            throw BFLAdapterError.invalidResponse(
                "Black Forest Labs response did not include id and polling_url."
            )
        }

        guard pollingURL.scheme?.lowercased() == "https",
              pollingURL.user == nil,
              pollingURL.password == nil,
              pollingURL.port == nil || pollingURL.port == 443,
              let host = pollingURL.host?.lowercased(),
              ["api.bfl.ai", "api.eu.bfl.ai", "api.us.bfl.ai"].contains(host)
        else {
            throw BFLAdapterError.invalidResponse(
                "Black Forest Labs returned an untrusted polling URL."
            )
        }
        return Job(id: id, pollingURL: pollingURL)
    }

    private static func resultMetadata(_ data: [String: Any]) -> [String: String]? {
        var metadata: [String: String] = [:]
        if let id = data["id"] as? String { metadata[ProviderJobMetadataKey.jobId] = id }
        if let progress = data["progress"] as? Double { metadata["providerProgress"] = String(progress) }
        return metadata.isEmpty ? nil : metadata
    }

    private static func failureMessage(from data: [String: Any], fallback: String) -> String {
        if let error = data["error"] as? String { return error }
        if let details = data["details"] as? String { return details }
        if let details = data["details"] as? [String: Any],
           let message = details["message"] as? String
        {
            return message
        }
        return fallback
    }

    private static func dataURI(_ value: String) -> String {
        value.hasPrefix("data:") ? value : "data:image/png;base64,\(value)"
    }

    private static func megapixels(for dimensions: String) -> Double {
        let parsed = Self.dimensions(for: dimensions)
        return Double(parsed.width * parsed.height) / 1_000_000
    }

    private func atomicCost(for request: ImageGenerationRequest) -> Double {
        let costRequest = ImageGenerationCostRequest(
            dimensions: request.dimensions,
            numberOfImages: 1,
            hasSourceImage: request.clientImage?.isEmpty == false,
            referenceImageCount: request.clientReferenceImages?.count ?? 0
        )
        return getCostEstimate(request: costRequest)
    }

    private func failure(
        message: String,
        response: NetworkResponseData? = nil
    ) -> ImageGenerationResponse {
        ImageGenerationResponse(
            status: .FAILED,
            errorCode: .MODEL_ERROR,
            errorMessage: message,
            rawResponse: response?.rawResponseString
        )
    }
}

private enum BFLAdapterError: LocalizedError {
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case let .invalidResponse(message): message
        }
    }
}

public final class G_BFL_FLUX_2_PRO: G_BFL_FLUX_2 {
    public init(pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy()) {
        super.init(
            modelCode: .BFL_FLUX_2_PRO,
            textPricePerMegapixel: 0.03,
            editPricePerMegapixel: 0.045,
            pollingPolicy: pollingPolicy
        )
    }
}

public final class G_BFL_FLUX_2_MAX: G_BFL_FLUX_2 {
    public init(pollingPolicy: ProviderPollingPolicy = ProviderPollingPolicy()) {
        super.init(
            modelCode: .BFL_FLUX_2_MAX,
            textPricePerMegapixel: 0.07,
            editPricePerMegapixel: 0.07,
            pollingPolicy: pollingPolicy
        )
    }
}
