import AvgeekLocalizationCore
import AvgeekLocalizationUI

typealias AppLanguageSettings = AppLanguageController

@MainActor
enum IllustrateLanguageSettings {
    static let shared = AppLanguageSettings(storageKey: SupportedLanguage.storageKey)
}
