import SwiftUI
import LittleWorksCore

/// Hourly rate input for one client.
struct RateField: View {
    let client: Client
    let onChange: (Decimal?) -> Void
    @State private var rate: Decimal?

    init(client: Client, onChange: @escaping (Decimal?) -> Void) {
        self.client = client
        self.onChange = onChange
        _rate = State(initialValue: client.hourlyRate)
    }

    var body: some View {
        HStack(spacing: 2) {
            Text("€")
            TextField("uurloon", value: $rate, format: .number)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(width: 64)
                .onChange(of: rate) { onChange(rate) }
            Text("/u").foregroundStyle(.secondary)
        }
    }
}

/// Fixed monthly fee input for one client.
struct FeeField: View {
    let client: Client
    let onChange: (Decimal?) -> Void
    @State private var fee: Decimal?

    init(client: Client, onChange: @escaping (Decimal?) -> Void) {
        self.client = client
        self.onChange = onChange
        _fee = State(initialValue: client.monthlyFee)
    }

    var body: some View {
        HStack(spacing: 2) {
            Text("€")
            TextField("vast/mnd", value: $fee, format: .number)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(width: 72)
                .onChange(of: fee) { onChange(fee) }
            Text("/mnd").foregroundStyle(.secondary)
        }
    }
}
