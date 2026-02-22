import Foundation

/// Convenience for localized string selection
extension String {
    /// Pick between two strings based on language
    static func localized(en: String, de: String, language: AppLanguage) -> String {
        switch language {
        case .en: return en
        case .de: return de
        }
    }
}
