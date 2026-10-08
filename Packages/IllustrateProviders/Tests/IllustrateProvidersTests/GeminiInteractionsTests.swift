import Foundation
import Testing
@testable import IllustrateProviders

@Suite("Gemini Interactions API")
struct GeminiInteractionsTests {
    @Test("request encodes documented image edit fields")
    func requestEncodesDocumentedFields() throws {
        let request = GeminiInteractionRequest(
            model: "gemini-3.1-flash-image",
            input: .blocks([
                .image(base64: "abc123", mimeType: "image/png"),
                .text("Create a cleaner product photo."),
            ]),
            systemInstruction: "Return a production-ready asset.",
            previousInteractionId: "v1_previous",
            responseModalities: ["image"],
            responseFormat: .single(GeminiInteractionResponseFormat(
                type: "image",
                mimeType: "image/jpeg",
                aspectRatio: "16:9",
                imageSize: "2K"
            )),
            generationConfig: GeminiInteractionGenerationConfig(temperature: 0.2, seed: 1234),
            tools: [.googleSearch],
            serviceTier: "standard",
            store: true
        )

        let data = try JSONEncoder().encode(request)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["model"] as? String == "gemini-3.1-flash-image")
        #expect(json["system_instruction"] as? String == "Return a production-ready asset.")
        #expect(json["previous_interaction_id"] as? String == "v1_previous")
        #expect(json["response_modalities"] as? [String] == ["image"])
        #expect(json["service_tier"] as? String == "standard")
        #expect(json["store"] as? Bool == true)

        let input = try #require(json["input"] as? [[String: Any]])
        #expect(input[0]["type"] as? String == "image")
        #expect(input[0]["mime_type"] as? String == "image/png")
        #expect(input[0]["data"] as? String == "abc123")
        #expect(input[1]["type"] as? String == "text")
        #expect(input[1]["text"] as? String == "Create a cleaner product photo.")

        let responseFormat = try #require(json["response_format"] as? [String: Any])
        #expect(responseFormat["type"] as? String == "image")
        #expect(responseFormat["mime_type"] as? String == "image/jpeg")
        #expect(responseFormat["aspect_ratio"] as? String == "16:9")
        #expect(responseFormat["image_size"] as? String == "2K")

        let generationConfig = try #require(json["generation_config"] as? [String: Any])
        #expect(generationConfig["temperature"] as? Double == 0.2)
        #expect(generationConfig["seed"] as? Int == 1234)

        let tools = try #require(json["tools"] as? [[String: Any]])
        #expect(tools.first?["type"] as? String == "google_search")
    }

    @Test("decodes image and text outputs from model output steps")
    func decodesImageAndTextOutputs() throws {
        let response = NetworkResponseData.dictionary(statusCode: 200, data: [
            "id": "v1_image",
            "status": "completed",
            "model": "gemini-3.1-flash-image",
            "object": "interaction",
            "updated": "2026-06-30T12:00:00Z",
            "usage": [
                "total_input_tokens": 12,
                "total_output_tokens": 20,
                "total_tokens": 32,
                "input_tokens_by_modality": [
                    ["modality": "text", "tokens": 12],
                ],
            ],
            "steps": [
                [
                    "type": "model_output",
                    "content": [
                        ["type": "text", "text": "Earlier caption."],
                        ["type": "image", "mime_type": "image/png", "data": "earlier-image-data"],
                        ["type": "text", "text": "Generated "],
                        ["type": "text", "text": "a product photo."],
                        ["type": "image", "mime_type": "image/png", "data": "image-data"],
                    ],
                ],
            ],
        ])

        let interaction = try GeminiInteractionsService.decodeInteraction(from: response)

        #expect(interaction.id == "v1_image")
        #expect(interaction.updated == "2026-06-30T12:00:00Z")
        #expect(interaction.outputText == "Generated a product photo.")
        #expect(interaction.outputImage?.data == "image-data")
        #expect(interaction.outputImage?.mimeType == "image/png")
        #expect(interaction.usage?.totalTokens == 32)
        #expect(interaction.usage?.inputTokensByModality?.first?.modality == "text")
        #expect(interaction.usage?.inputTokensByModality?.first?.tokens == 12)
        #expect(interaction.outputMetadata[GeminiInteractionMetadataKey.interactionId] == "v1_image")
    }

    @Test("decodes inline and URI video outputs")
    func decodesVideoOutputs() throws {
        let inlineResponse = NetworkResponseData.dictionary(statusCode: 200, data: [
            "id": "v1_video",
            "status": "completed",
            "steps": [
                [
                    "type": "model_output",
                    "content": [
                        ["type": "video", "mime_type": "video/mp4", "data": "video-data"],
                    ],
                ],
            ],
        ])

        let inlineInteraction = try GeminiInteractionsService.decodeInteraction(from: inlineResponse)
        #expect(inlineInteraction.outputVideo?.data == "video-data")
        #expect(inlineInteraction.outputVideo?.mimeType == "video/mp4")

        let uriResponse = NetworkResponseData.dictionary(statusCode: 200, data: [
            "id": "v1_video_uri",
            "status": "completed",
            "steps": [
                [
                    "type": "model_output",
                    "content": [
                        [
                            "type": "video",
                            "mime_type": "video/mp4",
                            "uri": "https://generativelanguage.googleapis.com/v1beta/files/example:download?alt=media",
                        ],
                    ],
                ],
            ],
        ])

        let uriInteraction = try GeminiInteractionsService.decodeInteraction(from: uriResponse)
        #expect(uriInteraction.outputVideo?
            .uri == "https://generativelanguage.googleapis.com/v1beta/files/example:download?alt=media")
    }

    @Test("service posts through injected network provider")
    func servicePostsThroughInjectedNetworkProvider() async throws {
        let mock = MockNetworkProvider(response: .dictionary(statusCode: 200, data: [
            "id": "v1_created",
            "status": "completed",
            "steps": [],
        ]))
        let service = GeminiInteractionsService(networkProvider: mock)
        let request = GeminiInteractionRequest(
            model: "gemini-omni-flash-preview",
            input: .text("A marble rolling on a track.")
        )

        let interaction = try await service.createInteraction(request: request, apiKey: "AIza-test")

        #expect(interaction.id == "v1_created")
        #expect(mock.capturedURL?.absoluteString == "https://generativelanguage.googleapis.com/v1beta/interactions")
        #expect(mock.capturedMethod == "POST")
        #expect(mock.capturedHeaders?["x-goog-api-key"] == "AIza-test")
        #expect(mock.capturedHeaders?["Content-Type"] == "application/json")
        #expect(mock.capturedHeaders?["Api-Revision"] == GeminiInteractionsService.apiRevision)

        let data = try #require(mock.capturedBodyData)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["model"] as? String == "gemini-omni-flash-preview")
        #expect(json["input"] as? String == "A marble rolling on a track.")
    }

    @Test("service gets interactions through injected network provider")
    func serviceGetsInteractionsThroughInjectedNetworkProvider() async throws {
        let mock = MockNetworkProvider(response: .dictionary(statusCode: 200, data: [
            "id": "v1_existing",
            "status": "completed",
            "environment_id": "env_existing",
            "steps": [],
        ]))
        let service = GeminiInteractionsService(networkProvider: mock)

        let interaction = try await service.getInteraction(id: "v1_existing", apiKey: "AIza-test")

        #expect(interaction.id == "v1_existing")
        #expect(interaction.environmentId == "env_existing")
        #expect(mock.capturedURL?
            .absoluteString == "https://generativelanguage.googleapis.com/v1beta/interactions/v1_existing")
        #expect(mock.capturedMethod == "GET")
        #expect(mock.capturedHeaders?["Api-Revision"] == GeminiInteractionsService.apiRevision)
        #expect(mock.capturedBodyData == nil)
    }

    @Test("service maps provider error payloads")
    func serviceMapsProviderErrors() async throws {
        let mock = MockNetworkProvider(response: .dictionary(statusCode: 400, data: [
            "error": ["message": "Prompt blocked"],
        ]))
        let service = GeminiInteractionsService(networkProvider: mock)
        let request = GeminiInteractionRequest(model: "gemini-omni-flash-preview", input: .text("blocked"))

        do {
            _ = try await service.createInteraction(request: request, apiKey: "AIza-test")
            Issue.record("Expected provider error")
        } catch let error as GeminiInteractionsError {
            #expect(error.localizedDescription == "Prompt blocked")
        }
    }
}

final class MockNetworkProvider: @unchecked Sendable, NetworkProvider {
    let response: NetworkResponseData
    var capturedURL: URL?
    var capturedMethod: String?
    var capturedBodyData: Data?
    var capturedHeaders: [String: String]?

    init(response: NetworkResponseData) {
        self.response = response
    }

    func performRequest(
        url: URL,
        method: String,
        body: (some Codable & Sendable)?,
        headers: [String: String]?,
        attachments: [NetworkRequestAttachment]?
    ) async throws -> NetworkResponseData {
        capturedURL = url
        capturedMethod = method
        capturedHeaders = headers
        if let body {
            capturedBodyData = try JSONEncoder().encode(body)
        }
        return response
    }
}
