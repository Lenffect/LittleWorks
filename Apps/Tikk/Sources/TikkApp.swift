import SwiftUI

@main
struct TikkApp: App {
    @State private var model = AppModel()

    init() { PopoverPosition.shared.start() }

    var body: some Scene {
        MenuBarExtra {
            MenuView(model: model)
        } label: {
            if let client = model.activeClient {
                Text("● \(client.name) \(Format.duration(model.activeElapsed))")
            } else {
                Text("tikk.")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
