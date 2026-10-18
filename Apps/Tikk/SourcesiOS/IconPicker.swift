import SwiftUI
import UIKit

/// Choose the home-screen icon. "TikkOranje" is the primary icon (it also has dark and tinted looks of its own).
struct AppIconOption: Identifiable, Sendable {
    let id: String
    let title: String
    var preview: String { "IconPreview" + id.dropFirst(4) }
    var alternateName: String? { id == "TikkOranje" ? nil : id }

    static let all = [
        AppIconOption(id: "TikkOranje", title: "Oranje"),
        AppIconOption(id: "TikkLicht", title: "Licht"),
        AppIconOption(id: "TikkDonker", title: "Donker"),
        AppIconOption(id: "TikkZwartWit", title: "Zwart-wit"),
        AppIconOption(id: "TikkNacht", title: "Nacht"),
        AppIconOption(id: "TikkGlas", title: "Glas"),
        AppIconOption(id: "TikkMint", title: "Mint"),
        AppIconOption(id: "TikkHemel", title: "Hemel"),
    ]
}

/// Settings row showing the current icon; tapping it opens a popup with all choices.
struct IconPicker: View {
    @State private var current = UIApplication.shared.alternateIconName ?? "TikkOranje"
    @State private var error: String?
    @State private var showing = false

    private var option: AppIconOption { AppIconOption.all.first { $0.id == current } ?? AppIconOption.all[0] }

    var body: some View {
        Button { showing = true } label: {
            HStack {
                Text("App-icoon").foregroundStyle(Brand.ink)
                Spacer()
                Text(LocalizedStringKey(option.title)).foregroundStyle(.secondary)
                Image(option.preview).resizable().scaledToFit().frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showing) {
            IconChoiceSheet(current: current, error: error, onChoose: choose) { showing = false }
                .presentationDetents([.medium])
        }
    }

    private func choose(_ option: AppIconOption) {
        guard option.id != current else { showing = false; return }
        UIApplication.shared.setAlternateIconName(option.alternateName) { err in
            Task { @MainActor in
                if let err { error = err.localizedDescription } else { current = option.id; error = nil; showing = false }
            }
        }
    }
}

private struct IconChoiceSheet: View {
    let current: String
    let error: String?
    let onChoose: (AppIconOption) -> Void
    let onDone: () -> Void
    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(AppIconOption.all) { option in
                        Button { onChoose(option) } label: {
                            VStack(spacing: 6) {
                                Image(option.preview)
                                    .resizable().scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                                            .strokeBorder(current == option.id ? Color.accentColor : Color.primary.opacity(0.12),
                                                          lineWidth: current == option.id ? 3 : 1)
                                    }
                                Text(LocalizedStringKey(option.title)).font(.caption)
                                    .foregroundStyle(current == option.id ? Color.accentColor : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                if let error { Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal, 20) }
            }
            .navigationTitle("App-icoon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Klaar", action: onDone) } }
        }
    }
}
