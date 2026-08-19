import SwiftUI
import SwiftData

struct SplitEditorView: View {
    @Bindable var program: Program

    var body: some View {
        List {
            Section("Double Day Focus") {
                NavigationLink {
                    FocusPickerView(program: program)
                } label: {
                    LabeledContent("Current Focus", value: program.currentFocus.displayName)
                }
            }

            Section("Week") {
                ForEach(sortedDays, id: \.persistentModelID) { day in
                    NavigationLink {
                        DayEditorView(day: day, program: program)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(day.weekday.displayName)
                                .font(.headline)
                            Text(day.title)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Split Editor")
    }

    private var sortedDays: [DayTemplate] {
        program.days.sorted { $0.weekday < $1.weekday }
    }
}
