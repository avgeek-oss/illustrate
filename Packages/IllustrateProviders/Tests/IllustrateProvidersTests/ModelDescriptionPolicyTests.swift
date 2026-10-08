import Foundation
import Testing
@testable import IllustrateProviders

@Suite("Model description policy")
struct ModelDescriptionPolicyTests {
    @Test("Active model descriptions stay short, capability focused, and price free")
    func activeModelDescriptionsFollowPolicy() {
        let models = AllModels.createModels().filter(\.active)
        #expect(!models.isEmpty)

        let bannedTerms = [
            "$",
            "billing",
            "billed",
            "benchmark",
            "benchmarks",
            "billion",
            "cost",
            "credit",
            "credits",
            "dimension",
            "dimensions",
            "free",
            "latest",
            "launch",
            "launched",
            "million",
            "parameter",
            "parameters",
            "price",
            "pricing",
            "quota",
            "resolution",
            "resolutions",
            "token",
            "tokens",
        ]

        for model in models {
            let description = model.modelDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercasedDescription = description.lowercased()
            let sentenceMarks = description.filter { ".!?".contains($0) }.count
            let words = description
                .replacingOccurrences(of: ".", with: "")
                .split(whereSeparator: \.isWhitespace)
            let containsNumber = description.contains { character in
                character.isNumber
            }

            #expect(!description.isEmpty, "\(model.modelCode) description is empty")
            #expect(description.hasSuffix("."), "\(model.modelCode) description must end with a period")
            #expect(sentenceMarks == 1, "\(model.modelCode) description must be one sentence")
            #expect((6 ... 9).contains(words.count), "\(model.modelCode) description has \(words.count) words")
            #expect(!containsNumber, "\(model.modelCode) description contains numbers")

            for term in bannedTerms {
                #expect(!lowercasedDescription.contains(term), "\(model.modelCode) description contains \(term)")
            }
        }
    }
}
