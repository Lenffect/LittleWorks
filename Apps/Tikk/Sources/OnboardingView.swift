import SwiftUI

/// Three short screens, shown in the popover the first time tikk. is opened.
struct OnboardingView: View {
    @AppStorage(SettingsKey.onboardingDone) private var done = false
    @State private var page = 0

    private struct Page { let title: LocalizedStringKey; let text: LocalizedStringKey }
    private let pages = [
        Page(title: "Hoi, ik ben Tikk.", text: "Ik houd je uren bij, rustig vanuit je menubalk."),
        Page(title: "Klik op een klant.", text: "Eén klik start de timer, nog een klik stopt hem. Wisselen van klant kan ook met één klik."),
        Page(title: "Zie waar je staat.", text: "Open tikk. voor je overzicht, je rapport en het urencriterium."),
    ]

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            Image("Onboarding\(page + 1)")
                .interpolation(.none)
                .resizable()
                .frame(width: 240, height: 156)   // 6 pt per art pixel
                .accessibilityHidden(true)
            VStack(spacing: 6) {
                Text(pages[page].title).font(.title2.weight(.semibold))
                Text(pages[page].text).multilineTextAlignment(.center).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 6) {
                ForEach(pages.indices, id: \.self) { i in
                    Circle().fill(i == page ? Color.accentColor : Brand.muted.opacity(0.4)).frame(width: 7, height: 7)
                }
            }
            Spacer(minLength: 0)
            HStack {
                Button("Overslaan") { done = true }.buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Button(page == pages.count - 1 ? LocalizedStringKey("Aan de slag") : LocalizedStringKey("Volgende")) {
                    if page == pages.count - 1 { done = true } else { page += 1 }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .multilineTextAlignment(.center)
    }
}
