import SwiftUI
import SwiftData

/// "Today is the app." Static box sizing — boxes never resize, reflow, or
/// appear/disappear based on state. A box with nothing to report shows a
/// resting state at the same footprint.
struct HomeView: View {
    @Binding var selection: AppTab

    @Query private var programs: [Program]
    @Query(sort: \SupplementLog.day, order: .reverse) private var supplementLogs: [SupplementLog]
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]
    @Environment(\.modelContext) private var modelContext

    @State private var showingWorkout = false
    @State private var showingCheckIn = false
    @State private var activeWorkout = ActiveWorkoutState()

    var body: some View {
        NavigationStack {
            Group {
                if let program = programs.first {
                    content(for: program)
                        .padding(.horizontal)
                        .padding(.top, 8)
                } else {
                    ContentUnavailableView(
                        "No Program Yet",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("The default split hasn't been seeded.")
                    )
                }
            }
            .navigationTitle("AltSplit")
        }
        .task {
            guard let program = programs.first else { return }
            await AccountabilityCoordinator.refreshAll(program: program, context: modelContext)
        }
    }

    @ViewBuilder
    private func content(for program: Program) -> some View {
        let today = DayResolver(program: program).resolve(for: .now)

        GlassEffectContainer {
            VStack(spacing: 16) {
                WorkoutBox(day: today, isInProgress: activeWorkout.hasActiveSession) {
                    if !today.isRest { showingWorkout = true }
                }
                .accessibilityIdentifier("workoutBox")
                .frame(maxHeight: .infinity)

                HStack(spacing: 16) {
                    SupplementBox(
                        title: "Protein",
                        isOn: todaysLog?.protein ?? false,
                        streak: streak(\.protein),
                        detail: streakDetail(streak(\.protein)),
                        identifier: "supplementBox.protein"
                    ) {
                        toggle(\.protein)
                    }
                    SupplementBox(
                        title: "Creatine",
                        isOn: todaysLog?.creatine ?? false,
                        streak: streak(\.creatine),
                        detail: streakDetail(streak(\.creatine)),
                        identifier: "supplementBox.creatine"
                    ) {
                        toggle(\.creatine)
                    }
                    SupplementBox(
                        title: "Multivitamin",
                        isOn: todaysLog?.multivitamin ?? false,
                        streak: streak(\.multivitamin),
                        detail: streakDetail(streak(\.multivitamin)),
                        identifier: "supplementBox.multivitamin"
                    ) {
                        toggle(\.multivitamin)
                    }
                }
                .frame(maxHeight: .infinity)

                CheckInBox(
                    program: program,
                    checkIns: checkIns,
                    onTapDue: { showingCheckIn = true },
                    onTapNotDue: { selection = .progress }
                )
                .accessibilityIdentifier("checkInBox")
                .frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
            .padding(.bottom, 24)
        }
        .fullScreenCover(isPresented: $showingWorkout) {
            WorkoutSessionView(day: today, state: activeWorkout) {
                showingWorkout = false
            }
        }
        .sheet(isPresented: $showingCheckIn) {
            CheckInCaptureView(program: program, previousCheckIn: checkIns.first)
        }
    }

    // MARK: - Supplements

    private var todaysLog: SupplementLog? {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        return supplementLogs.first { Calendar.current.isDate($0.day, inSameDayAs: startOfToday) }
    }

    private func toggle(_ keyPath: ReferenceWritableKeyPath<SupplementLog, Bool>) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        let log = todaysLog ?? {
            let new = SupplementLog(day: startOfToday)
            modelContext.insert(new)
            return new
        }()
        log[keyPath: keyPath].toggle()
        try? modelContext.save()
        Task { await AccountabilityCoordinator.refreshBadge(context: modelContext) }
    }

    /// Count of consecutive prior days with `keyPath` true, walking back
    /// from the most recent day that already counts. Today isn't included
    /// until it's checked off — but an unchecked today doesn't zero out a
    /// streak built through yesterday either; the streak only breaks once
    /// a day passes without being checked off.
    private func streak(_ keyPath: KeyPath<SupplementLog, Bool>) -> Int {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: .now)
        var count = 0
        var index = 0

        let todayCompleted = todaysLog?[keyPath: keyPath] ?? false
        if !todayCompleted {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
            if todaysLog != nil {
                index = 1 // today's row exists but doesn't count for this keyPath
            }
        }

        while index < supplementLogs.count {
            let log = supplementLogs[index]
            guard calendar.isDate(log.day, inSameDayAs: day) else { break }
            guard log[keyPath: keyPath] else { break }
            count += 1
            index += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }

        return count
    }

    private func streakDetail(_ streak: Int) -> String {
        streak == 1 ? "1 day streak" : "\(streak) day streak"
    }
}
