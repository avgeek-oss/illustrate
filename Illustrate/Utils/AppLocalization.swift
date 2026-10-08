import AvgeekLocalizationCore
import AvgeekLocalizationUI
import Foundation

enum AppLocalization {
    private static let client = AppLocalizationClient(storageKey: SupportedLanguage.storageKey)

    static var locale: Locale {
        client.locale
    }

    static var bundle: Bundle {
        client.bundle
    }

    static func bundle(for language: SupportedLanguage) -> Bundle {
        client.bundle(for: language)
    }

    static func string(_ key: String) -> String {
        client.string(key)
    }

    static func string(_ key: String, language: SupportedLanguage) -> String {
        client.string(key, language: language)
    }

    static func string(_ value: String.LocalizationValue) -> String {
        client.string(value)
    }

    static func string(_ value: String.LocalizationValue, language: SupportedLanguage) -> String {
        client.string(value, language: language)
    }
}
