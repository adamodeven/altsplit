import SwiftUI

/// One tap for anything daily. Toggles immediately with a symbol
/// transition — no confirmation, tap again to undo.
struct SupplementBox: View {
    let title: String
    let symbol: String
    let isOn: Bool
    let streak: Int
    let detail: String
    let identifier: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(title.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Image(systemName: isOn ? "\(symbol).circle.fill" : "circle")
                    .font(.system(size: 36))
                    .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .glassEffect(Glass.regular.interactive(), in: .rect(corners: .concentric))
        .animation(.default, value: isOn)
        .accessibilityIdentifier(identifier)
    }
}
