import SwiftUI
import LittleWorksCore

@main
struct TikkiOSApp: App {
    @State private var model = AppModel()
    @AppStorage(SettingsKey.language) private var language = AppLanguage.en.rawValue

    private var locale: Locale { (AppLanguage(rawValue: language) ?? .en).locale }

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .environment(\.locale, locale)
                .tint(Color.accentColor)
        }
    }
}

struct RootView: View {
    let model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            TimerScreen(model: model)
                .tabItem { Label("Timer", systemImage: "timer") }
            OverviewScreen(model: model)
                .tabItem { Label("Overzicht", systemImage: "list.bullet.rectangle") }
            ReportScreen(model: model)
                .tabItem { Label("Rapport", systemImage: "chart.bar.doc.horizontal") }
            ClientsScreen(model: model)
                .tabItem { Label("Klanten", systemImage: "person.2") }
            SettingsScreen(model: model)
                .tabItem { Label("Instellingen", systemImage: "gearshape") }
        }
        .fontDesign(.rounded)
        .onChange(of: scenePhase) {
            switch scenePhase {
            case .background: model.didEnterBackground()
            case .active: model.didBecomeActive()
            default: break
            }
        }
        .alert(awayTitle, isPresented: Binding(get: { model.awayPrompt != nil }, set: { _ in })) {
            Button("Stop op het moment van weggaan") { model.resolveAway(stopAtLeave: true) }
            Button("Tijd behouden", role: .cancel) { model.resolveAway(stopAtLeave: false) }
        } message: {
            Text("De timer liep door. Wat doen we met die tijd?")
        }
    }

    private var awayTitle: String {
        guard let since = model.awayPrompt?.since else { return "" }
        let seconds = Date().timeIntervalSince(since)
        return "\(tr("tikk. was niet actief")) \(Format.duration(seconds)) (\(Int(seconds / 60)) min)"
    }
}
