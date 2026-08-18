import SwiftUI

/// Changing the focus resets the 4-week staleness clock, since choosing it
/// now is exactly what "reconfirmed" means.
struct FocusPickerView: View {
    @Bindable var program: Program
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(MuscleGroup.allCases) { group in
            Button {
                program.currentFocus = group
                program.focusConfirmedAt = .now
                dismiss()
            } label: {
                HStack {
                    Text(group.displayName)
                        .foregroundStyle(.primary)
                    Spacer()
                    if group == program.currentFocus {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
        .navigationTitle("Double Day Focus")
    }
}
