import Foundation

enum L10n {
    static let supportedLocales = ["en", "fr", "es", "pt-BR", "de", "it", "nl", "pl", "ru", "uk", "tr", "ar", "hi", "zh-Hans", "ja", "ko"]
    /// Use only for built-in labels and canonical enum values, never student-entered names.
    static func key(_ value: String) -> String { String(localized: String.LocalizationValue(value)) }
    static func activity(_ value: String) -> String {
        value.components(separatedBy: " · ").map(key).joined(separator: " · ")
    }
}
