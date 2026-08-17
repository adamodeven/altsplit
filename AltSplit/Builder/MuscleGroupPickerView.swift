import SwiftUI

/// Multi-select checklist for a day's trained groups.
struct MuscleGroupPickerView: View {
    @Binding var selection: [MuscleGroup]

    var body: some View {
        List(MuscleGroup.allCases) { group in
            Button {
                toggle(group)
            } label: {
                HStack {
                    Text(group.displayName)
                        .foregroundStyle(.primary)
                    Spacer()
                    if selection.contains(group) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
        .navigationTitle("Groups")
    }

    private func toggle(_ group: MuscleGroup) {
        if let index = selection.firstIndex(of: group) {
            selection.remove(at: index)
        } else {
            selection.append(group)
        }
    }
}
