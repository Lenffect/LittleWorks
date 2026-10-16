import SwiftUI

@main
struct TikkApp: App {
    @State private var model = AppModel()
    @AppStorage(SettingsKey.language) private var language = AppLanguage.en.rawValue

    private var locale: Locale { (AppLanguage(rawValue: language) ?? .en).locale }

    init() { PopoverPosition.shared.start() }

    var body: some Scene {
        MenuBarExtra {
            MenuView(model: model).environment(\.locale, locale)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Window(WindowTitle.main, id: "main") {
            MainWindowView(model: model).environment(\.locale, locale)
        }
        .defaultSize(width: 920, height: 620)
    }
}

/// Menu-bar item: Tikk (template image, animated while tracking) plus client and running time.
struct MenuBarLabel: View {
    let model: AppModel
    @AppStorage(SettingsKey.menuBarStyle) private var styleRaw = MenuBarStyle.both.rawValue

    var body: some View {
        let style = MenuBarStyle(rawValue: styleRaw) ?? .both
        let client = model.activeClient
        HStack(spacing: 4) {
            // With "only time" and no timer running there would be nothing to click, so show the icon.
            if style != .timeOnly || client == nil {
                Image(model.menuIcon.name)
            }
            if let client, style != .iconOnly {
                Text("\(client.name) \(Format.duration(model.activeElapsed))").monospacedDigit()
            }
        }
    }
}
