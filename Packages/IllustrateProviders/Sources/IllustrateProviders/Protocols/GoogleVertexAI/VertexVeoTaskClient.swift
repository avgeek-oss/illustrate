// MARK: - VertexVeoTaskClient.swift

import Foundation

enum VertexVeoTaskClient {
    static let defaultPollingPolicy = ProviderPollingPolicy(
        maxAttempts: 120,
        intervalNanoseconds: 5_000_000_000
    )

    struct Job: Equatable {
        let operationName: String
        let modelId: String
        let statusURL: URL

        var id: String {
            operationName.split(separator: "/").last.map(String.init) ?? operationName
        }

        var metadata: [String: String] {
            [
                ProviderJobMetadataKey.jobId: id,
                ProviderJobMetadataKey.statusURL: statusURL.absoluteString,
                "vertexOperationName": operationName,
                "vertexModelId": modelId,
            ]
        }
    }

    struct OperationRequest: Codable, Equatable {
        let operationName: String
    }

    static func create(
        modelId: String,
        body: some Codable & Sendable,
        configuration: VertexAIConfiguration,
        network: any NetworkProvider
    ) async throws -> Job {
        let createURL = try configuration.modelURL(modelId: modelId, method: "predictLongRunning")
        let envelope = try await network.performSingleAttemptRequest(
            url: createURL,
            method: "POST",
            body: body,
            headers: VertexAIClient.headers(configuration: configuration),
            attachments: nil
        )
        let parsed = try VertexAIClient.response(from: envelope, operation: "video creation")
        let data = try VertexAIClient.response(from: parsed, operation: "video creation")
        guard let operationName = data["name"] as? String,
              VertexAIClient.isValidOperationName(
                  operationName,
                  configuration: configuration,
                  modelId: modelId
              )
        else {
            throw VertexAIError.invalidResponse(
                "Vertex AI video creation omitted a valid operation name."
            )
        }
        return try Job(
            operationName: operationName,
            modelId: modelId,
            statusURL: configuration.modelURL(modelId: modelId, method: "fetchPredictOperation")
        )
    }

    static func poll(
        job: Job,
        configuration: VertexAIConfiguration,
        network: any NetworkProvider,
        policy: ProviderPollingPolicy
    ) async throws -> NetworkResponseData {
        try await ProviderAsyncJobPoller.poll(
            policy: policy,
            fetch: {
                // Google defines fetchPredictOperation as an idempotent POST.
                // Retrying this read-only status operation cannot create a job.
                try await network.performRequest(
                    url: job.statusURL,
                    method: "POST",
                    body: OperationRequest(operationName: job.operationName),
                    headers: VertexAIClient.headers(configuration: configuration),
                    attachments: nil
                )
            },
            classify: classify
        )
    }

    static func classify(_ response: NetworkResponseData) throws -> ProviderAsyncJobState {
        guard case let .dictionary(statusCode, data) = response else {
            return .failed("Vertex AI video status did not return a JSON object.")
        }
        guard (200 ... 299).contains(statusCode) else {
            return .failed("Vertex AI video status failed with HTTP \(statusCode).")
        }
        if let error = data["error"] as? [String: Any] {
            let code = error["code"].map { String(describing: $0) } ?? "unknown"
            let message = error["message"] as? String ?? "Vertex AI video generation failed."
            return .failed("Vertex AI video generation failed (\(code)): \(message)")
        }
        guard data["done"] as? Bool == true else { return .pending }
        do {
            _ = try video(from: data)
            return .succeeded
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    static func video(from data: [String: Any]) throws -> (base64: String, mimeType: String) {
        guard let response = data["response"] as? [String: Any] else {
            throw VertexAIError.invalidResponse("Vertex AI completed without a response object.")
        }
        let videos = (response["videos"] as? [[String: Any]])
            ?? (response["generatedVideos"] as? [[String: Any]])
            ?? []
        guard videos.count == 1, let item = videos.first else {
            let filtered = response["raiMediaFilteredCount"].map { String(describing: $0) } ?? "0"
            throw VertexAIError.invalidResponse(
                "Vertex AI completed with \(videos.count) videos (filtered: \(filtered))."
            )
        }
        let media = (item["video"] as? [String: Any]) ?? item
        guard let base64 = media["bytesBase64Encoded"] as? String,
              !base64.isEmpty,
              Data(base64Encoded: base64) != nil
        else {
            if media["gcsUri"] != nil {
                throw VertexAIError.invalidResponse(
                    "Vertex AI returned only a Cloud Storage URI; Illustrate requests inline bytes."
                )
            }
            throw VertexAIError.invalidResponse("Vertex AI completed without inline video bytes.")
        }
        let mimeType = media["mimeType"] as? String ?? "video/mp4"
        guard mimeType.hasPrefix("video/") else {
            throw VertexAIError.invalidResponse("Vertex AI returned a non-video MIME type.")
        }
        return (base64, mimeType)
    }
}
