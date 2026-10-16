import SwiftUI

@main
struct TikkApp: App {
    @State private var model = AppModel()

    init() { PopoverPosition.shared.start() }

    var body: some Scene {
        MenuBarExtra {
            MenuView(model: model)
        } label: {
            // Placeholder: the real item is drawn by MenuBarItem.update (called every second).
            Image(systemName: "clock")
        }
        .menuBarExtraStyle(.window)

        Window(WindowTitle.main, id: "main") {
            MainWindowView(model: model)
        }
        .defaultSize(width: 920, height: 620)
    }
}

/// Menu-bar item: Tikk (template image, animated while tracking) plus client and running time.
struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 4) {
            Image(model.menuIcon.name)
            if let client = model.activeClient {
                Text("\(client.name) \(Format.duration(model.activeElapsed))").monospacedDigit()
            }
        }
    }
}
