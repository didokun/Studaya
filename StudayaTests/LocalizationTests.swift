import XCTest
@testable import Studaya

final class LocalizationTests: XCTestCase {
    private func strings(_ language: String, table: String = "Localizable") throws -> [String: String] {
        let folder = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
        return try XCTUnwrap(NSDictionary(contentsOfFile: folder + "/" + table + ".strings") as? [String: String])
    }
    func testAllSixteenLanguagesHaveCompleteNativeCatalogsAndPermissionMessages() throws {
        let english = try strings("en")
        XCTAssertEqual(L10n.supportedLocales.count, 16)
        XCTAssertGreaterThan(english.count, 600)
        for language in L10n.supportedLocales {
            let catalog = try strings(language)
            XCTAssertEqual(Set(catalog.keys), Set(english.keys), language)
            XCTAssertEqual(Bundle.preferredLocalizations(from: L10n.supportedLocales, forPreferences: [language]).first, language)
            for (key, value) in catalog {
                if !key.isEmpty { XCTAssertFalse(value.isEmpty, language + ": " + key) }
                XCTAssertFalse(value.contains("ZXQ"), language + ": " + key)
                XCTAssertFalse(value.contains("{{ARG"), language + ": " + key)
            }
            let privacy = try strings(language, table: "InfoPlist")
            XCTAssertFalse(try XCTUnwrap(privacy["NSCameraUsageDescription"]).isEmpty)
            XCTAssertFalse(try XCTUnwrap(privacy["NSCalendarsFullAccessUsageDescription"]).isEmpty)
        }
    }
    func testFormatArgumentsArePreservedIncludingReorderedHindiAndJapaneseArguments() throws {
        let expression = try NSRegularExpression(pattern: #"(?<!%)%(?!%)(?:([0-9]+)\$)?[-+0 #]*[0-9]*(?:\.[0-9]+)?(ll|l|hh|h)?([@diufeg])"#)
        func signature(_ text: String) -> [String] {
            let matches = expression.matches(in: text, range: NSRange(text.startIndex..., in: text))
            return matches.enumerated().map { index, match in
                let ns = text as NSString
                let position = match.range(at: 1).location == NSNotFound ? String(index + 1) : ns.substring(with: match.range(at: 1))
                let size = match.range(at: 2).location == NSNotFound ? "" : ns.substring(with: match.range(at: 2))
                return position + ":" + size + ns.substring(with: match.range(at: 3))
            }.sorted()
        }
        let base = try strings("fr")
        for language in L10n.supportedLocales {
            let catalog = try strings(language)
            for key in base.keys { XCTAssertEqual(signature(key), signature(try XCTUnwrap(catalog[key])), language + ": " + key) }
        }
        let hindi = try strings("hi")
        let value = try XCTUnwrap(hindi["%lld séances terminées sur %lld"])
        let rendered = String(format: value, Int64(3), Int64(7))
        XCTAssertFalse(rendered.contains("%"))
        XCTAssertTrue(rendered.contains("3") && rendered.contains("7"))
    }
    @MainActor func testStudentDataAndCanonicalTypesAreNotTranslated() {
        let subject = Subject("Présentation", exam: .now)
        let chapter = Chapter("Meine Notizen", subject: subject.id, target: 2)
        XCTAssertEqual(subject.name, "Présentation")
        XCTAssertEqual(chapter.name, "Meine Notizen")
        XCTAssertEqual(chapter.kind, "Cours")
        XCTAssertEqual(ImportedKind.td.rawValue, "TD")
    }
}
