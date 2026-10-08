// MARK: - G_REPLICATE_CATALOG_AUDIT.swift

import Foundation

public struct ReplicateCatalogImageInput: Codable, Sendable {
    public var prompt: String?
    public var instruction: String?
    public var bg_prompt: String?
    public var image: String?
    public var mask: String?
    public var image_input: [String]?
    public var reference_images: [String]?
    public var init_images: [String]?
    public var ref_image_file: String?
    public var aspect_ratio: String?
    public var size: String?
    public var resolution: String?
    public var guidance: Double?
    public var guidance_scale: Double?
    public var negative_prompt: String?
    public var seed: Int?
    public var steps: Int?
    public var prompt_upsampling: Bool?
    public var safety_tolerance: Int?
    public var output_format: String?
    public var outpaint: String?
    public var prompt_enhancement: Bool?
    public var enhance_image: Bool?
    public var sync: Bool?
    public var content_moderation: Bool?
    public var preserve_alpha: Bool?
    public var refine_prompt: Bool?
    public var original_quality: Bool?
    public var background: String?
    public var enhance_prompt: Bool?
    public var safety_checker: Bool?
    public var thinking_level: String?
    public var max_images: Int?
    public var sequential_image_generation: String?
    public var return_byteplus_urls: Bool?

    public init() {}
}

public struct ReplicateCatalogVideoInput: Codable, Sendable {
    public var prompt: String?
    public var image: String?
    public var video: String?
    public var first_frame: String?
    public var last_frame: String?
    public var first_clip: String?
    public var start_image: String?
    public var end_image: String?
    public var reference_images: [String]?
    public var reference_video: String?
    public var instruction_prompt: String?
    public var aspect_ratio: String?
    public var duration: Int?
    public var resolution: String?
    public var negative_prompt: String?
    public var enable_prompt_expansion: Bool?
    public var audio: Bool?
    public var seed: Int?
    public var cut_first_second: Bool?
    public var save_audio: Bool?
    public var ignore_audio: Bool?
    public var target_fps: String?
    public var turbo: Bool?
    public var disable_safety_checker: Bool?
    public var mode: String?
    public var keep_original_sound: Bool?
    public var video_reference_type: String?

    public init() {}
}

private struct ReplicateCatalogPredictionBody<Input: Codable & Sendable>: Codable {
    let input: Input
}

private func replicateCatalogIsTerminal(_ data: [String: Any]) -> Bool {
    if data["output"] != nil || data["error"] != nil || data["detail"] != nil {
        return true
    }
    guard let status = data["status"] as? String else { return false }
    return ["succeeded", "failed", "canceled"].contains(status)
}

private func performReplicateCatalogPrediction(
    model: ProviderModelData,
    providerSecret: String,
    input: some Codable & Sendable
) async throws -> NetworkResponseData {
    guard let url = URL(string: model.modelGenerateBaseURL) else {
        return .dictionary(statusCode: 400, data: ["error": "Invalid model URL"])
    }

    let headers = [
        "Authorization": "Bearer \(providerSecret)",
        "Content-Type": "application/json",
        "Prefer": "wait=60",
    ]
    let initial = try await ProviderDependencies.shared.networkProvider.performRequest(
        url: url,
        method: "POST",
        body: ReplicateCatalogPredictionBody(input: input),
        headers: headers,
        attachments: nil
    )

    guard case let .dictionary(_, initialData) = initial else { return initial }
    if replicateCatalogIsTerminal(initialData) { return initial }
    guard let predictionId = initialData["id"] as? String,
          let statusURL = model.statusURL
    else {
        return initial
    }

    for _ in 0 ..< 180 {
        try await Task.sleep(nanoseconds: 5_000_000_000)
        let response = try await ProviderDependencies.shared.networkProvider.performRequest(
            url: statusURL.appendingPathComponent(predictionId),
            method: "GET",
            body: nil as String?,
            headers: headers,
            attachments: nil
        )
        if case let .dictionary(_, data) = response, replicateCatalogIsTerminal(data) {
            return response
        }
    }

    return .dictionary(statusCode: 408, data: ["error": "Replicate prediction timed out"])
}

private func replicateCatalogErrorMessage(_ data: [String: Any]) -> String? {
    if let error = data["error"] as? String { return error }
    if let errors = data["error"] as? [String] { return errors.first }
    if let error = data["error"] as? [String: Any], let message = error["message"] as? String { return message }
    if let detail = data["detail"] as? String { return detail }
    return nil
}

private func replicateCatalogOutputURL(_ data: [String: Any]) -> String? {
    if let output = data["output"] as? String { return output }
    if let output = data["output"] as? [String] { return output.first }
    return nil
}

private func replicateCatalogDownload(_ output: String, mimeType: String) throws -> String {
    if output.hasPrefix("data:"), let comma = output.firstIndex(of: ",") {
        let base64 = String(output[output.index(after: comma)...])
        guard Data(base64Encoded: base64) != nil else {
            throw NSError(domain: "Invalid Replicate data URI", code: -1)
        }
        return base64
    }
    guard let url = URL(string: output) else {
        throw NSError(domain: "Invalid Replicate output URL", code: -1)
    }
    let data = try Data(contentsOf: url)
    guard !data.isEmpty else {
        throw NSError(domain: "Empty Replicate \(mimeType) output", code: -1)
    }
    return data.base64EncodedString()
}

func replicateCatalogAspectRatio(
    _ dimensions: String,
    allowed: [String],
    default fallback: String
) -> String {
    if allowed.contains(dimensions) { return dimensions }
    let ratio = getAspectRatio(dimension: dimensions).ratio
    return allowed.contains(ratio) ? ratio : fallback
}

public class ReplicateCatalogImageBase: ImageGenerationProtocol {
    public init() {}

    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override")
    }

    var costPerImage: Double {
        fatalError("Subclass must override")
    }

    var acceptsSourceImage: Bool {
        false
    }

    var acceptsMask: Bool {
        false
    }

    var maxReferenceImages: Int {
        0
    }

    var requiresSourceImage: Bool {
        false
    }

    var requiresMask: Bool {
        false
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
        costPerImage * Double(request.numberOfImages ?? 1)
    }

    public func formatCost(request: ImageGenerationCostRequest) -> String {
        let cost = getCostEstimate(request: request)
        return cost == 0 ? "Unavailable" : formatEstimatedCost(cost)
    }

    func buildInput(
        request: ImageGenerationRequest,
        sourceImageURL: String?,
        maskURL: String?,
        referenceImageURLs: [String]
    ) -> ReplicateCatalogImageInput {
        fatalError("Subclass must override")
    }

    public func transformResponse(
        request: ImageGenerationRequest,
        response: NetworkResponseData
    ) throws -> ImageGenerationResponse {
        guard case let .dictionary(_, data) = response else {
            return createInvalidResponseError(response: response, modelCode: modelCode)
        }
        if let error = replicateCatalogErrorMessage(data) {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: error,
                rawResponse: response.rawResponseString
            )
        }
        guard let output = replicateCatalogOutputURL(data) else {
            return createInvalidResponseError(response: response, modelCode: modelCode)
        }
        return try ImageGenerationResponse(
            status: .GENERATED,
            base64: replicateCatalogDownload(output, mimeType: "image"),
            cost: getCostEstimate(request: ImageGenerationCostRequest(from: request)),
            modelPrompt: request.prompt,
            rawResponse: response.rawResponseString
        )
    }

    public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        if requiresSourceImage, request.clientImage?.isEmpty != false {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires an input image"
            )
        }
        if requiresMask, request.clientMask?.isEmpty != false {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "This model requires a mask"
            )
        }

        do {
            let sourceURL: String? = if acceptsSourceImage, let source = request.clientImage, !source.isEmpty {
                try await ReplicateFileUploader.uploadImage(base64Image: source, apiToken: request.providerSecret)
            } else {
                nil
            }
            let maskURL: String? = if acceptsMask, let mask = request.clientMask, !mask.isEmpty {
                try await ReplicateFileUploader.uploadImage(base64Image: mask, apiToken: request.providerSecret)
            } else {
                nil
            }
            var referenceURLs: [String] = []
            for reference in (request.clientReferenceImages ?? []).prefix(maxReferenceImages) {
                try await referenceURLs.append(ReplicateFileUploader.uploadImage(
                    base64Image: reference.base64Image,
                    apiToken: request.providerSecret
                ))
            }
            let input = buildInput(
                request: request,
                sourceImageURL: sourceURL,
                maskURL: maskURL,
                referenceImageURLs: referenceURLs
            )
            let response = try await performReplicateCatalogPrediction(
                model: model,
                providerSecret: request.providerSecret,
                input: input
            )
            return try transformResponse(request: request, response: response)
        } catch {
            return ImageGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Request failed: \(error.localizedDescription)"
            )
        }
    }
}

public class ReplicateCatalogVideoBase: VideoGenerationProtocol {
    public init() {}

    var modelCode: EnumProviderModelCode {
        fatalError("Subclass must override")
    }

    var acceptsSourceImage: Bool {
        false
    }

    var acceptsLastFrame: Bool {
        false
    }

    var acceptsVideo: Bool {
        false
    }

    var maxReferenceImages: Int {
        0
    }

    var requiresSourceImage: Bool {
        false
    }

    var requiresVideo: Bool {
        false
    }

    public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: modelCode)!
    }

    public struct ServiceRequest: Codable, Sendable {
        let placeholder: Bool
    }

    public func transformRequest(request: VideoGenerationRequest) -> ServiceRequest {
        ServiceRequest(placeholder: true)
    }

    func costPerSecond(request: VideoGenerationCostRequest) -> Double {
        fatalError("Subclass must override")
    }

    public func getCostEstimate(request: VideoGenerationCostRequest) -> Double {
        costPerSecond(request: request) * Double(request.durationSeconds ?? 5) * Double(request.numberOfVideos ?? 1)
    }

    public func formatCost(request: VideoGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request))
    }

    func validationError(request: VideoGenerationRequest) -> String? {
        if requiresSourceImage, request.clientImage?.isEmpty != false { return "This model requires an input image" }
        if requiresVideo, request.clientVideo?.isEmpty != false { return "This model requires an input video" }
        return nil
    }

    func buildInput(
        request: VideoGenerationRequest,
        sourceImageURL: String?,
        lastFrameURL: String?,
        videoURL: String?,
        referenceImageURLs: [String]
    ) -> ReplicateCatalogVideoInput {
        fatalError("Subclass must override")
    }

    public func transformResponse(
        request: VideoGenerationRequest,
        response: NetworkResponseData
    ) throws -> VideoGenerationResponse {
        guard case let .dictionary(_, data) = response else {
            return createInvalidVideoResponseError(response: response, modelCode: modelCode)
        }
        if let error = replicateCatalogErrorMessage(data) {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: error,
                rawResponse: response.rawResponseString
            )
        }
        guard let output = replicateCatalogOutputURL(data) else {
            return createInvalidVideoResponseError(response: response, modelCode: modelCode)
        }
        return try VideoGenerationResponse(
            status: .GENERATED,
            base64: replicateCatalogDownload(output, mimeType: "video"),
            cost: getCostEstimate(request: VideoGenerationCostRequest(from: request)),
            modelPrompt: request.prompt,
            rawResponse: response.rawResponseString
        )
    }

    public func makeRequest(request: VideoGenerationRequest) async throws -> VideoGenerationResponse {
        if let error = validationError(request: request) {
            return VideoGenerationResponse(status: .FAILED, errorCode: .MODEL_ERROR, errorMessage: error)
        }

        do {
            let sourceURL: String? = if acceptsSourceImage, let source = request.clientImage, !source.isEmpty {
                try await ReplicateFileUploader.uploadImage(base64Image: source, apiToken: request.providerSecret)
            } else {
                nil
            }
            let lastFrameURL: String? = if acceptsLastFrame, let frame = request.clientLastFrame, !frame.isEmpty {
                try await ReplicateFileUploader.uploadImage(base64Image: frame, apiToken: request.providerSecret)
            } else {
                nil
            }
            let videoURL: String? = if acceptsVideo, let video = request.clientVideo, !video.isEmpty {
                try await ReplicateFileUploader.uploadVideo(base64Video: video, apiToken: request.providerSecret)
            } else {
                nil
            }
            var referenceURLs: [String] = []
            for reference in (request.clientReferenceImages ?? []).prefix(maxReferenceImages) {
                try await referenceURLs.append(ReplicateFileUploader.uploadImage(
                    base64Image: reference.base64Image,
                    apiToken: request.providerSecret
                ))
            }
            let input = buildInput(
                request: request,
                sourceImageURL: sourceURL,
                lastFrameURL: lastFrameURL,
                videoURL: videoURL,
                referenceImageURLs: referenceURLs
            )
            let response = try await performReplicateCatalogPrediction(
                model: model,
                providerSecret: request.providerSecret,
                input: input
            )
            return try transformResponse(request: request, response: response)
        } catch {
            return VideoGenerationResponse(
                status: .FAILED,
                errorCode: .MODEL_ERROR,
                errorMessage: "Request failed: \(error.localizedDescription)"
            )
        }
    }
}

public final class G_REPLICATE_SEEDREAM_5_LITE: ReplicateCatalogImageBase {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_SEEDREAM_5_LITE
    }

    override var costPerImage: Double {
        0.035
    }

    override var acceptsSourceImage: Bool {
        true
    }

    override var maxReferenceImages: Int {
        14
    }

    override func buildInput(
        request: ImageGenerationRequest,
        sourceImageURL: String?,
        maskURL _: String?,
        referenceImageURLs: [String]
    ) -> ReplicateCatalogImageInput {
        var input = ReplicateCatalogImageInput()
        let images = ([sourceImageURL].compactMap { $0 } + referenceImageURLs).prefix(14)
        input.prompt = request.prompt
        input.image_input = images.isEmpty ? nil : Array(images)
        input.aspect_ratio = replicateCatalogAspectRatio(
            request.dimensions,
            allowed: ["match_input_image", "1:1", "4:3", "3:4", "16:9", "9:16", "3:2", "2:3", "21:9"],
            default: sourceImageURL == nil ? "1:1" : "match_input_image"
        )
        input.size = request.resolution?.uppercased() == "3K" ? "3K" : "2K"
        input.max_images = 1
        input.sequential_image_generation = "disabled"
        input.output_format = "png"
        input.return_byteplus_urls = false
        return input
    }
}

public final class G_REPLICATE_FLUX_FILL_PRO: ReplicateCatalogImageBase {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_FLUX_FILL_PRO
    }

    override var costPerImage: Double {
        0.05
    }

    override var acceptsSourceImage: Bool {
        true
    }

    override var acceptsMask: Bool {
        true
    }

    override var requiresSourceImage: Bool {
        true
    }

    override func buildInput(
        request: ImageGenerationRequest,
        sourceImageURL: String?,
        maskURL: String?,
        referenceImageURLs _: [String]
    ) -> ReplicateCatalogImageInput {
        var input = ReplicateCatalogImageInput()
        input.prompt = request.prompt
        input.image = sourceImageURL
        input.mask = maskURL
        input.guidance = min(100, max(1.5, request.guidance ?? 60))
        input.steps = min(50, max(15, request.steps ?? 50))
        input.prompt_upsampling = request.promptEnhance ?? false
        input.safety_tolerance = min(6, max(1, request.safetyTolerance ?? 2))
        input.seed = request.seed
        input.outpaint = "None"
        input.output_format = "png"
        return input
    }
}

public final class G_REPLICATE_BRIA_FIBO: ReplicateCatalogImageBase {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_BRIA_FIBO
    }

    override var costPerImage: Double {
        0.04
    }

    override var acceptsSourceImage: Bool {
        true
    }

    override func buildInput(
        request: ImageGenerationRequest,
        sourceImageURL: String?,
        maskURL _: String?,
        referenceImageURLs _: [String]
    ) -> ReplicateCatalogImageInput {
        var input = ReplicateCatalogImageInput()
        input.prompt = request.prompt
        input.image = sourceImageURL
        input.aspect_ratio = replicateCatalogAspectRatio(
            request.dimensions,
            allowed: ["1:1", "2:3", "3:2", "3:4", "4:3", "4:5", "5:4", "9:16", "16:9"],
            default: "1:1"
        )
        input.guidance_scale = min(5, max(3, request.guidance ?? 4))
        input.negative_prompt = request.negativePrompt
        input.seed = request.seed
        return input
    }
}

public final class G_REPLICATE_BRIA_FIBO_EDIT: ReplicateCatalogImageBase {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_BRIA_FIBO_EDIT
    }

    override var costPerImage: Double {
        0.04
    }

    override var acceptsSourceImage: Bool {
        true
    }

    override var acceptsMask: Bool {
        true
    }

    override var requiresSourceImage: Bool {
        true
    }

    override func buildInput(
        request: ImageGenerationRequest,
        sourceImageURL: String?,
        maskURL: String?,
        referenceImageURLs _: [String]
    ) -> ReplicateCatalogImageInput {
        var input = ReplicateCatalogImageInput()
        input.instruction = request.prompt
        input.image = sourceImageURL
        input.mask = maskURL
        input.guidance_scale = min(5, max(3, request.guidance ?? 4))
        input.negative_prompt = request.negativePrompt
        input.seed = request.seed
        return input
    }
}

public final class G_REPLICATE_BRIA_IMAGE_3_2: ReplicateCatalogImageBase {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_BRIA_IMAGE_3_2
    }

    override var costPerImage: Double {
        0.04
    }

    override func buildInput(
        request: ImageGenerationRequest,
        sourceImageURL _: String?,
        maskURL _: String?,
        referenceImageURLs _: [String]
    ) -> ReplicateCatalogImageInput {
        var input = ReplicateCatalogImageInput()
        input.prompt = request.prompt
        input.aspect_ratio = replicateCatalogAspectRatio(
            request.dimensions,
            allowed: ["1:1", "2:3", "3:2", "3:4", "4:3", "4:5", "5:4", "9:16", "16:9"],
            default: "1:1"
        )
        input.guidance_scale = min(5, max(3, request.guidance ?? 4))
        input.negative_prompt = request.negativePrompt
        input.prompt_enhancement = request.promptEnhance ?? false
        input.enhance_image = false
        input.seed = request.seed
        return input
    }
}

public final class G_REPLICATE_BRIA_ERASER: ReplicateCatalogImageBase {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_BRIA_ERASER
    }

    override var costPerImage: Double {
        0.04
    }

    override var acceptsSourceImage: Bool {
        true
    }

    override var acceptsMask: Bool {
        true
    }

    override var requiresSourceImage: Bool {
        true
    }

    override var requiresMask: Bool {
        true
    }

    override func buildInput(
        request _: ImageGenerationRequest,
        sourceImageURL: String?,
        maskURL: String?,
        referenceImageURLs _: [String]
    ) -> ReplicateCatalogImageInput {
        var input = ReplicateCatalogImageInput()
        input.image = sourceImageURL
        input.mask = maskURL
        input.sync = true
        input.content_moderation = true
        input.preserve_alpha = true
        return input
    }
}

public final class G_REPLICATE_BRIA_GENFILL: ReplicateCatalogImageBase {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_BRIA_GENFILL
    }

    override var costPerImage: Double {
        0.04
    }

    override var acceptsSourceImage: Bool {
        true
    }

    override var acceptsMask: Bool {
        true
    }

    override var requiresSourceImage: Bool {
        true
    }

    override var requiresMask: Bool {
        true
    }

    override func buildInput(
        request: ImageGenerationRequest,
        sourceImageURL: String?,
        maskURL: String?,
        referenceImageURLs _: [String]
    ) -> ReplicateCatalogImageInput {
        var input = ReplicateCatalogImageInput()
        input.prompt = request.prompt
        input.image = sourceImageURL
        input.mask = maskURL
        input.negative_prompt = request.negativePrompt
        input.seed = request.seed
        input.sync = true
        input.content_moderation = true
        input.preserve_alpha = true
        return input
    }
}

public final class G_REPLICATE_BRIA_EXPAND_IMAGE: ReplicateCatalogImageBase {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_BRIA_EXPAND_IMAGE
    }

    override var costPerImage: Double {
        0.04
    }

    override var acceptsSourceImage: Bool {
        true
    }

    override var requiresSourceImage: Bool {
        true
    }

    override func buildInput(
        request: ImageGenerationRequest,
        sourceImageURL: String?,
        maskURL _: String?,
        referenceImageURLs _: [String]
    ) -> ReplicateCatalogImageInput {
        var input = ReplicateCatalogImageInput()
        input.image = sourceImageURL
        input.prompt = request.prompt
        input.aspect_ratio = replicateCatalogAspectRatio(
            request.dimensions,
            allowed: ["1:1", "2:3", "3:2", "3:4", "4:3", "4:5", "5:4", "9:16", "16:9"],
            default: "1:1"
        )
        input.negative_prompt = request.negativePrompt
        input.seed = request.seed
        input.sync = true
        input.content_moderation = true
        input.preserve_alpha = true
        return input
    }
}

public final class G_REPLICATE_BRIA_GENERATE_BACKGROUND: ReplicateCatalogImageBase {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_BRIA_GENERATE_BACKGROUND
    }

    override var costPerImage: Double {
        0.04
    }

    override var acceptsSourceImage: Bool {
        true
    }

    override var maxReferenceImages: Int {
        1
    }

    override var requiresSourceImage: Bool {
        true
    }

    override func buildInput(
        request: ImageGenerationRequest,
        sourceImageURL: String?,
        maskURL _: String?,
        referenceImageURLs: [String]
    ) -> ReplicateCatalogImageInput {
        var input = ReplicateCatalogImageInput()
        input.image = sourceImageURL
        input.bg_prompt = request.prompt
        input.ref_image_file = referenceImageURLs.first
        input.negative_prompt = request.negativePrompt
        input.refine_prompt = request.promptEnhance ?? true
        input.original_quality = true
        input.seed = request.seed
        input.sync = true
        input.content_moderation = true
        return input
    }
}

public class ReplicateRiverflow25Base: ReplicateCatalogImageBase {
    override var acceptsSourceImage: Bool {
        true
    }

    override public func formatCost(request: ImageGenerationCostRequest) -> String {
        formatEstimatedCost(getCostEstimate(request: request)) + "+"
    }

    override func buildInput(
        request: ImageGenerationRequest,
        sourceImageURL: String?,
        maskURL _: String?,
        referenceImageURLs: [String]
    ) -> ReplicateCatalogImageInput {
        var input = ReplicateCatalogImageInput()
        let images = ([sourceImageURL].compactMap { $0 } + referenceImageURLs).prefix(maxReferenceImages)
        input.instruction = request.prompt
        input.init_images = images.isEmpty ? nil : Array(images)
        input.aspect_ratio = replicateCatalogAspectRatio(
            request.dimensions,
            allowed: ["auto", "21:9", "16:9", "3:2", "4:3", "5:4", "1:1", "4:5", "3:4", "2:3", "9:16"],
            default: "auto"
        )
        let resolution = request.resolution?.uppercased()
        input.resolution = ["1K", "2K", "4K"].contains(resolution ?? "") ? resolution : "1K"
        input.output_format = "png"
        input.background = "original"
        input.enhance_prompt = request.promptEnhance ?? false
        input.safety_checker = true
        input.thinking_level = "medium"
        return input
    }
}

public final class G_REPLICATE_RIVERFLOW_2_5_PRO: ReplicateRiverflow25Base {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_RIVERFLOW_2_5_PRO
    }

    override var costPerImage: Double {
        0.02
    }

    override var maxReferenceImages: Int {
        10
    }
}

public final class G_REPLICATE_RIVERFLOW_2_5_FAST: ReplicateRiverflow25Base {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_RIVERFLOW_2_5_FAST
    }

    override var costPerImage: Double {
        0.0041
    }

    override var maxReferenceImages: Int {
        4
    }
}

public final class G_REPLICATE_WAN_2_7_T2V: ReplicateCatalogVideoBase {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_WAN_2_7_T2V
    }

    override func costPerSecond(request _: VideoGenerationCostRequest) -> Double {
        0.10
    }

    override func buildInput(
        request: VideoGenerationRequest,
        sourceImageURL _: String?,
        lastFrameURL _: String?,
        videoURL _: String?,
        referenceImageURLs _: [String]
    ) -> ReplicateCatalogVideoInput {
        var input = ReplicateCatalogVideoInput()
        input.prompt = request.prompt ?? ""
        input.negative_prompt = request.negativePrompt
        input.aspect_ratio = replicateCatalogAspectRatio(
            request.dimensions,
            allowed: ["16:9", "9:16", "1:1", "4:3", "3:4"],
            default: "16:9"
        )
        input.duration = min(15, max(2, request.durationSeconds ?? 5))
        input.resolution = request.resolution?.lowercased() == "720p" ? "720p" : "1080p"
        input.enable_prompt_expansion = request.promptEnhance ?? true
        input.seed = request.seed
        return input
    }
}

public final class G_REPLICATE_WAN_2_7_I2V: ReplicateCatalogVideoBase {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_WAN_2_7_I2V
    }

    override var acceptsSourceImage: Bool {
        true
    }

    override var acceptsLastFrame: Bool {
        true
    }

    override var acceptsVideo: Bool {
        true
    }

    override func costPerSecond(request: VideoGenerationCostRequest) -> Double {
        request.resolution?.lowercased() == "720p" ? 0.10 : 0.15
    }

    override func validationError(request: VideoGenerationRequest) -> String? {
        if request.clientImage?.isEmpty != false, request.clientVideo?.isEmpty != false {
            return "This model requires an input image or video"
        }
        return nil
    }

    override func buildInput(
        request: VideoGenerationRequest,
        sourceImageURL: String?,
        lastFrameURL: String?,
        videoURL: String?,
        referenceImageURLs _: [String]
    ) -> ReplicateCatalogVideoInput {
        var input = ReplicateCatalogVideoInput()
        input.first_clip = videoURL
        input.first_frame = videoURL == nil ? sourceImageURL : nil
        input.last_frame = videoURL == nil ? lastFrameURL : nil
        input.prompt = request.prompt ?? ""
        input.negative_prompt = request.negativePrompt
        input.duration = min(15, max(2, request.durationSeconds ?? 5))
        input.resolution = request.resolution?.lowercased() == "720p" ? "720p" : "1080p"
        input.enable_prompt_expansion = request.promptEnhance ?? true
        input.seed = request.seed
        return input
    }
}

public final class G_REPLICATE_VIDU_Q3_PRO: ReplicateCatalogVideoBase {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_VIDU_Q3_PRO
    }

    override var acceptsSourceImage: Bool {
        true
    }

    override var acceptsLastFrame: Bool {
        true
    }

    override func costPerSecond(request: VideoGenerationCostRequest) -> Double {
        switch request.resolution?.lowercased() {
        case "540p": 0.07
        case "1080p": 0.16
        default: 0.15
        }
    }

    override func buildInput(
        request: VideoGenerationRequest,
        sourceImageURL: String?,
        lastFrameURL: String?,
        videoURL _: String?,
        referenceImageURLs _: [String]
    ) -> ReplicateCatalogVideoInput {
        var input = ReplicateCatalogVideoInput()
        input.prompt = request.prompt ?? ""
        input.start_image = sourceImageURL
        input.end_image = sourceImageURL == nil ? nil : lastFrameURL
        input.duration = min(16, max(1, request.durationSeconds ?? 5))
        input.aspect_ratio = replicateCatalogAspectRatio(
            request.dimensions,
            allowed: ["16:9", "9:16", "3:4", "4:3", "1:1"],
            default: "16:9"
        )
        input.resolution = ["540p", "720p", "1080p"].contains(request.resolution?.lowercased() ?? "")
            ? request.resolution?.lowercased()
            : "720p"
        input.audio = request.generateAudio ?? true
        input.seed = request.seed
        return input
    }
}

public final class G_REPLICATE_XAI_GROK_IMAGINE_VIDEO_1_5: ReplicateCatalogVideoBase {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_XAI_GROK_IMAGINE_VIDEO_1_5
    }

    override var acceptsSourceImage: Bool {
        true
    }

    override var requiresSourceImage: Bool {
        true
    }

    override func costPerSecond(request _: VideoGenerationCostRequest) -> Double {
        0.08
    }

    override func buildInput(
        request: VideoGenerationRequest,
        sourceImageURL: String?,
        lastFrameURL _: String?,
        videoURL _: String?,
        referenceImageURLs _: [String]
    ) -> ReplicateCatalogVideoInput {
        var input = ReplicateCatalogVideoInput()
        input.prompt = request.prompt ?? ""
        input.image = sourceImageURL
        input.duration = min(15, max(1, request.durationSeconds ?? 5))
        input.resolution = request.resolution?.lowercased() == "480p" ? "480p" : "720p"
        input.aspect_ratio = replicateCatalogAspectRatio(
            request.dimensions,
            allowed: ["auto", "16:9", "4:3", "1:1", "9:16", "3:4", "3:2", "2:3"],
            default: "auto"
        )
        return input
    }
}

public final class G_REPLICATE_BYTEDANCE_DREAMACTOR_M2_0: ReplicateCatalogVideoBase {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_BYTEDANCE_DREAMACTOR_M2_0
    }

    override var acceptsSourceImage: Bool {
        true
    }

    override var acceptsVideo: Bool {
        true
    }

    override var requiresSourceImage: Bool {
        true
    }

    override var requiresVideo: Bool {
        true
    }

    override func costPerSecond(request _: VideoGenerationCostRequest) -> Double {
        0.05
    }

    override func buildInput(
        request _: VideoGenerationRequest,
        sourceImageURL: String?,
        lastFrameURL _: String?,
        videoURL: String?,
        referenceImageURLs _: [String]
    ) -> ReplicateCatalogVideoInput {
        var input = ReplicateCatalogVideoInput()
        input.image = sourceImageURL
        input.video = videoURL
        input.cut_first_second = true
        return input
    }
}

public final class G_REPLICATE_PRUNA_P_VIDEO_ANIMATE: ReplicateCatalogVideoBase {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_PRUNA_P_VIDEO_ANIMATE
    }

    override var acceptsSourceImage: Bool {
        true
    }

    override var acceptsVideo: Bool {
        true
    }

    override var requiresSourceImage: Bool {
        true
    }

    override var requiresVideo: Bool {
        true
    }

    override func costPerSecond(request: VideoGenerationCostRequest) -> Double {
        request.resolution?.lowercased() == "1080p" ? 0.06 : 0.03
    }

    override func buildInput(
        request: VideoGenerationRequest,
        sourceImageURL: String?,
        lastFrameURL _: String?,
        videoURL: String?,
        referenceImageURLs _: [String]
    ) -> ReplicateCatalogVideoInput {
        var input = ReplicateCatalogVideoInput()
        let keepAudio = request.generateAudio ?? true
        input.video = videoURL
        input.image = sourceImageURL
        input.instruction_prompt = request.prompt ?? ""
        input.resolution = request.resolution?.lowercased() == "1080p" ? "1080p" : "720p"
        input.target_fps = [24, 48].contains(request.fps ?? 0) ? String(request.fps!) : "original"
        input.save_audio = keepAudio
        input.ignore_audio = !keepAudio
        input.turbo = false
        input.disable_safety_checker = false
        input.seed = request.seed
        return input
    }
}

public final class G_REPLICATE_KLING_O1: ReplicateCatalogVideoBase {
    override var modelCode: EnumProviderModelCode {
        .REPLICATE_KLING_O1
    }

    override var acceptsSourceImage: Bool {
        true
    }

    override var acceptsVideo: Bool {
        true
    }

    override var maxReferenceImages: Int {
        4
    }

    override var requiresVideo: Bool {
        true
    }

    override func costPerSecond(request _: VideoGenerationCostRequest) -> Double {
        0.168
    }

    override func buildInput(
        request: VideoGenerationRequest,
        sourceImageURL: String?,
        lastFrameURL _: String?,
        videoURL: String?,
        referenceImageURLs: [String]
    ) -> ReplicateCatalogVideoInput {
        var input = ReplicateCatalogVideoInput()
        let references = ([sourceImageURL].compactMap { $0 } + referenceImageURLs).prefix(4)
        input.prompt = request.prompt ?? ""
        input.reference_video = videoURL
        input.reference_images = references.isEmpty ? nil : Array(references)
        input.video_reference_type = "base"
        input.keep_original_sound = request.generateAudio ?? true
        input.mode = "pro"
        return input
    }
}
