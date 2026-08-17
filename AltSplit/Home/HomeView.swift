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

    var body: some View {
        NavigationStack {
            ScrollView {
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
                    .padding(.top, 80)
                }
            }
            .navigationTitle("AltSplit")
        }
    }

    @ViewBuilder
    private func content(for program: Program) -> some View {
        let today = DayResolver(program: program).resolve(for: .now)

        GlassEffectContainer {
            VStack(spacing: 16) {
                WorkoutBox(day: today) {
                    if !today.isRest { showingWorkout = true }
                }
                .accessibilityIdentifier("workoutBox")

                HStack(spacing: 16) {
                    SupplementBox(
                        title: "Protein",
                        symbol: "fork.knife",
                        isOn: todaysLog?.protein ?? false,
                        streak: streak(\.protein),
                        detail: streakDetail(streak(\.protein)),
                        identifier: "supplementBox.protein"
                    ) {
                        toggle(\.protein)
                    }
                    SupplementBox(
                        title: "Creatine",
                        symbol: "pill.fill",
                        isOn: todaysLog?.creatine ?? false,
                        streak: streak(\.creatine),
                        detail: complianceDetail(\.creatine),
                        identifier: "supplementBox.creatine"
                    ) {
                        toggle(\.creatine)
                    }
                }

                CheckInBox(
                    program: program,
                    checkIns: checkIns,
                    onTapDue: { showingCheckIn = true },
                    onTapNotDue: { selection = .progress }
                )
                .accessibilityIdentifier("checkInBox")
            }
            .padding(.bottom, 24)
        }
        .fullScreenCover(isPresented: $showingWorkout) {
            WorkoutSessionView(day: today)
        }
        .sheet(isPresented: $showingCheckIn) {
            CheckInCaptureStubView()
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
    }

    /// Consecutive days (walking back from today) with `keyPath` true. A
    /// missing day — no log at all — breaks the streak, same as a false
    /// value: honest data means the streak can go down.
    private func streak(_ keyPath: KeyPath<SupplementLog, Bool>) -> Int {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: .now)
        var count = 0
        var index = 0
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

    /// 30-day consistency, e.g. "26 / 30 days".
    private func complianceDetail(_ keyPath: KeyPath<SupplementLog, Bool>) -> String {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        guard let windowStart = calendar.date(byAdding: .day, value: -29, to: startOfToday) else {
            return "—"
        }
        let taken = supplementLogs.filter { $0.day >= windowStart && $0[keyPath: keyPath] }.count
        return "\(taken) / 30 days"
    }
}
