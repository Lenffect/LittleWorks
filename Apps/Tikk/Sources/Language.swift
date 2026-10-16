import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case en, nl
    var id: String { rawValue }
    var title: String { self == .en ? "English" : "Nederlands" }
    var locale: Locale { Locale(identifier: self == .en ? "en_NL" : "nl_NL") }
}

/// Source strings in the code are Dutch; `en.lproj` holds the English translations.
enum L10n {
    static var language: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: SettingsKey.language) ?? "") ?? .en
    }

    static var bundle: Bundle {
        Bundle.main.path(forResource: language.rawValue, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    }

    /// Applies at next launch to system dialogs (file pickers etc.).
    static func persist(_ language: AppLanguage) {
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
    }
}

func tr(_ key: String) -> String {
    L10n.bundle.localizedString(forKey: key, value: key, table: nil)
}

func tr(_ key: String, _ args: CVarArg...) -> String {
    String(format: tr(key), locale: L10n.language.locale, arguments: args)
}
