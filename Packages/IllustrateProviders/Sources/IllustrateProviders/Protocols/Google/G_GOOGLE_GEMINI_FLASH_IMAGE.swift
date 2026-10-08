// MARK: - G_GOOGLE_GEMINI_FLASH_IMAGE.swift

// Implementation for Gemini 2.5 Flash image generation.
// Fast image generation via Gemini's multi-modal API.

import Foundation

/// Gemini 2.5 Flash image generation.
public class G_GOOGLE_GEMINI_FLASH_IMAGE: GeminiFlashImageBase {
    override public init() {}
    override public var model: ProviderModelData {
        ProviderDependencies.shared.modelProvider.model(by: .GOOGLE_GEMINI_FLASH_IMAGE)!
    }

    override public func transformRequest(request: ImageGenerationRequest) -> ServiceRequest {
        buildServiceRequest(request: request, uploadedSourceImage: nil, uploadedReferenceImages: nil)
    }

    private func buildServiceRequest(
        request: ImageGenerationRequest,
        uploadedSourceImage: GeminiImageTypes.ContentPart.FileData?,
        uploadedReferenceImages: [GeminiImageTypes.ContentPart.FileData]?
    ) -> ServiceRequest {
        let aspectRatio = convertToAspectRatio(request.dimensions)

        return ServiceRequest(
            prompt: request.prompt,
            sourceImage: uploadedSourceImage,
            referenceImages: uploadedReferenceImages,
            aspectRatio: aspectRatio,
            selectedTools: request.selectedTools
        )
    }

    override public func makeRequest(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        switch buildURL(request: request) {
        case let .failure(response):
            return response
        case let .success(finalURL):
            var uploadedSourceImage: GeminiImageTypes.ContentPart.FileData? = nil
            var uploadedReferenceImages: [GeminiImageTypes.ContentPart.FileData]? = nil

            if let clientImage = request.clientImage, model.modelParams.supportsSourceImage {
                do {
                    let uploadedImages = try await uploadSourceAndReferenceImages(
                        sourceImage: clientImage,
                        referenceImages: request.clientReferenceImages,
                        apiKey: request.providerSecret
                    )
                    uploadedSourceImage = uploadedImages.source
                    uploadedReferenceImages = uploadedImages.references
                } catch {
                    return ImageGenerationResponse(
                        status: .FAILED,
                        errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                        errorMessage: "Failed to upload images: \(error.localizedDescription)"
                    )
                }
            } else if let clientReferenceImages = request.clientReferenceImages, !clientReferenceImages.isEmpty {
                do {
                    uploadedReferenceImages = try await uploadReferenceImages(
                        clientReferenceImages,
                        apiKey: request.providerSecret
                    )
                } catch {
                    return ImageGenerationResponse(
                        status: .FAILED,
                        errorCode: EnumGenerationAdapterErrorCode.MODEL_ERROR,
                        errorMessage: "Failed to upload reference images: \(error.localizedDescription)"
                    )
                }
            }

            let transformedRequest = buildServiceRequest(
                request: request,
                uploadedSourceImage: uploadedSourceImage,
                uploadedReferenceImages: uploadedReferenceImages
            )
            return await executeRequest(url: finalURL, body: transformedRequest, request: request)
        }
    }
}
