import SwiftUI
import SwiftData

/// Split editor and exercise library.
struct BuilderTabView: View {
    @Query private var programs: [Program]

    var body: some View {
        NavigationStack {
            List {
                if let program = programs.first {
                    NavigationLink("Split Editor") {
                        SplitEditorView(program: program)
                    }
                }
                NavigationLink("Exercise Library") {
                    ExerciseLibraryView()
                }
            }
            .navigationTitle("Builder")
            .tabBarMinimizeBehavior(.onScrollDown)
        }
    }
}
