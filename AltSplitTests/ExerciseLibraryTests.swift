import Testing
import Foundation
import SwiftData
@testable import AltSplit

@MainActor
struct ExerciseLibraryTests {

    @Test func namesAreUnique() {
        let names = ExerciseLibrary.all.map(\.name)
        #expect(Set(names).count == names.count)
    }

    @Test func everyMuscleGroupIsCovered() {
        let covered = Set(ExerciseLibrary.all.compactMap(\.muscleGroup))
        for group in MuscleGroup.allCases {
            #expect(covered.contains(group), "no seeded exercise for \(group)")
        }
    }

    @Test func ergExercisesHaveNoMuscleGroup() {
        for spec in ExerciseLibrary.erg {
            #expect(spec.muscleGroup == nil)
            #expect(spec.type == .erg)
        }
    }

    @Test func nonErgSpecsHaveAMuscleGroup() {
        for spec in ExerciseLibrary.all where spec.type != .erg && spec.type != .cardio {
            #expect(spec.muscleGroup != nil, "\(spec.name) is missing a muscle group")
        }
    }

    @Test func seedInsertsEveryExerciseAsNotUserCreated() throws {
        let schema = Schema([Exercise.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let lookup = ExerciseLibrary.seed(into: context)

        #expect(lookup.count == ExerciseLibrary.all.count)
        let fetched = try context.fetch(FetchDescriptor<Exercise>())
        #expect(fetched.count == ExerciseLibrary.all.count)
        #expect(fetched.allSatisfy { !$0.isUserCreated })
        for spec in ExerciseLibrary.all {
            #expect(lookup[spec.name]?.type == spec.type)
            #expect(lookup[spec.name]?.muscleGroup == spec.muscleGroup)
        }
    }
}
