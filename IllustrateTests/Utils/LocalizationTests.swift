// MARK: - LocalizationTests.swift

import AvgeekLocalizationCore
import AvgeekLocalizationUI
import AvgeekTestSupport
import XCTest
@testable import Illustrate

final class LocalizationTests: XCTestCase {
    private let translationLocales = SupportedLanguage.allCases
        .map(\.rawValue)
        .filter { $0 != "en" }

    func testSupportedLanguagesMatchInitialDnsDeckSet() {
        XCTAssertEqual(
            Set(SupportedLanguage.allCases.map(\.rawValue)),
            Set([
                "en",
                "de",
                "es",
                "fr",
                "hi",
                "id",
                "ja",
                "ko",
                "pl",
                "pt-BR",
                "tr",
                "uk",
                "vi",
                "zh-Hans",
                "zh-Hant",
            ])
        )
    }

    func testBestMatchUsesFirstSupportedPreferredLanguage() {
        XCTAssertEqual(SupportedLanguage.bestMatch(for: ["it-IT", "fr-FR"]), .french)
        XCTAssertEqual(SupportedLanguage.bestMatch(for: ["pt-BR", "en-US"]), .brazilianPortuguese)
        XCTAssertEqual(SupportedLanguage.bestMatch(for: ["zh-HK", "en-US"]), .traditionalChinese)
        XCTAssertEqual(SupportedLanguage.bestMatch(for: ["zh-CN", "en-US"]), .simplifiedChinese)
        XCTAssertEqual(SupportedLanguage.bestMatch(for: ["ar-SA"]), .english)
    }

    @MainActor
    func testAppLanguageSettingsFollowsSystemOnceThenPersistsExplicitSelection() throws {
        let defaultsFixture = try IsolatedUserDefaults(prefix: "IllustrateLocalizationTests")
        let defaults = defaultsFixture.defaults
        defer { withExtendedLifetime(defaultsFixture) {} }

        let initial = AppLanguageSettings(
            storageKey: SupportedLanguage.storageKey,
            userDefaults: defaults,
            preferredLanguages: ["vi-VN", "en-US"]
        )
        XCTAssertEqual(initial.appLanguage, .vietnamese)
        XCTAssertEqual(defaults.string(forKey: SupportedLanguage.storageKey), "vi")

        initial.appLanguage = .german
        let restored = AppLanguageSettings(
            storageKey: SupportedLanguage.storageKey,
            userDefaults: defaults,
            preferredLanguages: ["ja-JP"]
        )
        XCTAssertEqual(restored.appLanguage, .german)
        XCTAssertEqual(defaults.string(forKey: SupportedLanguage.storageKey), "de")
    }

    func testAppLocalizationLocaleUsesPersistedSelectionAndFallsBackToEnglish() {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: SupportedLanguage.storageKey)
        defer {
            if let previous {
                defaults.set(previous, forKey: SupportedLanguage.storageKey)
            } else {
                defaults.removeObject(forKey: SupportedLanguage.storageKey)
            }
        }

        defaults.removeObject(forKey: SupportedLanguage.storageKey)
        XCTAssertEqual(AppLocalization.locale.identifier, "en")

        defaults.set("de", forKey: SupportedLanguage.storageKey)
        XCTAssertEqual(AppLocalization.locale.identifier, "de")
    }

    func testLocalizableCatalogHasFullLocaleCoverageAndValidPlaceholders() throws {
        let catalog = try loadCatalog(relativePath: "Illustrate/Localizable.xcstrings")
        try validateCatalog(catalog, minimumKeyCount: 760)
    }

    func testInfoPlistCatalogHasFullLocaleCoverageAndStableBundleName() throws {
        let catalog = try loadCatalog(relativePath: "Illustrate/InfoPlist.xcstrings")
        try validateCatalog(catalog, minimumKeyCount: 5)

        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
        for key in ["CFBundleDisplayName", "CFBundleName"] {
            let entry = try XCTUnwrap(strings[key] as? [String: Any])
            let source = try sourceText(for: key, entry: entry)

            for locale in translationLocales {
                let value = try localizedValue(for: locale, in: entry)
                XCTAssertEqual(value, source, "\(locale): \(key) must not be localized")
            }
        }
    }

    func testXcodeProjectKnownRegionsCoverSupportedLanguages() throws {
        let projectPath = illustrateRoot
            .appendingPathComponent("Illustrate.xcodeproj/project.pbxproj")
        let project = try String(contentsOf: projectPath, encoding: .utf8)

        for language in SupportedLanguage.allCases.map(\.rawValue) {
            XCTAssertTrue(project.contains(language), "Missing knownRegion for \(language)")
        }
    }

    private var illustrateRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func loadCatalog(relativePath: String) throws -> [String: Any] {
        let url = illustrateRoot.appendingPathComponent(relativePath)
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func validateCatalog(_ catalog: [String: Any], minimumKeyCount: Int) throws {
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
        XCTAssertGreaterThanOrEqual(strings.count, minimumKeyCount)

        for (key, rawEntry) in strings {
            let entry = try XCTUnwrap(rawEntry as? [String: Any])
            XCTAssertNotEqual(entry["extractionState"] as? String, "stale", "\(key) is stale")

            let source = try sourceText(for: key, entry: entry)
            guard isTranslatable(key: key, source: source, entry: entry) else { continue }

            let expectedPlaceholders = placeholders(in: source)
            for locale in translationLocales {
                let value = try localizedValue(for: locale, in: entry)
                XCTAssertFalse(value.isEmpty, "\(locale): missing translation for \(key)")
                XCTAssertEqual(
                    placeholders(in: value),
                    expectedPlaceholders,
                    "\(locale): placeholder mismatch for \(key)"
                )
            }
        }
    }

    private func sourceText(for key: String, entry: [String: Any]) throws -> String {
        if let localizations = entry["localizations"] as? [String: Any],
           let english = localizations["en"] as? [String: Any],
           let unit = english["stringUnit"] as? [String: Any],
           let value = unit["value"] as? String
        {
            return value
        }
        return key
    }

    private func localizedValue(for locale: String, in entry: [String: Any]) throws -> String {
        let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any])
        let localization = try XCTUnwrap(localizations[locale] as? [String: Any])
        let unit = try XCTUnwrap(localization["stringUnit"] as? [String: Any])
        return try XCTUnwrap(unit["value"] as? String)
    }

    private func isTranslatable(key: String, source: String, entry: [String: Any]) -> Bool {
        if ["CFBundleDisplayName", "CFBundleName"].contains(key) {
            return false
        }
        if entry["shouldTranslate"] as? Bool == false {
            return false
        }
        return source.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil
    }

    private func placeholders(in text: String) -> [String] {
        let pattern = #"%(?:\d+\$)?(?:lld|llu|ld|lu|zd|zu|[@diuoxXfFeEgGcCsSpaA])"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        return regex.matches(in: text, range: range).map { match in
            String(text[Range(match.range, in: text)!])
        }
        .sorted()
    }
}
