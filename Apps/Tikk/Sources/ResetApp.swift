import SwiftUI

/// Typed confirmation before the whole app is reset to factory settings.
struct ResetAppSheet: View {
    let model: AppModel
    let onDone: () -> Void
    @State private var typed = ""
    @State private var saveBackup = true
    @FocusState private var focused: Bool

    private var phrase: String { tr("ik weet zeker dat ik de hele app wil resetten en alle gegevens wil verwijderen") }
    private var matches: Bool {
        typed.trimmingCharacters(in: .whitespacesAndNewlines).compare(phrase, options: [.caseInsensitive]) == .orderedSame
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Hele app resetten").font(.headline)
            Text("Dit verwijdert **definitief** alle klanten, projecten en registraties, en al je instellingen (taal, herinneringen, back-upmap, urencriterium, enzovoort). tikk. start daarna opnieuw op alsof het net is geïnstalleerd, met de introductie. De automatische back-up wordt ook overschreven met de lege situatie. Dit kan niet ongedaan worden gemaakt.")
                .foregroundStyle(.secondary)
            Toggle("Bewaar eerst een laatste back-up in de back-upmap", isOn: $saveBackup)
            Text("Typ de volgende zin om te bevestigen:")
            Text(phrase).font(.callout.weight(.semibold)).textSelection(.enabled)
            TextField("", text: $typed)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(reset)
            HStack {
                Button("Annuleer", action: onDone).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Alles verwijderen en resetten", role: .destructive, action: reset)
                    .disabled(!matches)
            }
        }
        .padding(18)
        .frame(width: 460)
        .onAppear { focused = true }
    }

    private func reset() {
        guard matches else { return }
        model.factoryReset(saveBackupFirst: saveBackup)
        onDone()
    }
}
