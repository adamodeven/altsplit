import Foundation
import SwiftData

/// Groups a planned exercise with the concrete sets logged against it this
/// session, in the day's current (possibly locally reordered) order.
struct ExerciseLogGroup: Identifiable {
    let id: PersistentIdentifier
    let planned: PlannedExercise
    var entries: [SetEntry]
}

/// Holds an in-progress workout's live state outside of `WorkoutSessionView`
/// itself. `WorkoutSessionView` is presented via `fullScreenCover`, which
/// tears down the covered view (and any `@State` on it) as soon as it's
/// dismissed — so minimizing the workout would otherwise silently drop the
/// rest timer and every logged set. Owning that state here instead, in an
/// object the presenting view holds onto across dismiss/re-present cycles,
/// lets "minimize" just hide the screen while everything on this object,
/// including the running rest-timer `Task`, keeps going.
@Observable
@MainActor
final class ActiveWorkoutState {
    var session: WorkoutSession?
    var groups: [ExerciseLogGroup] = []
    var startedAt: Date = .now

    var restRemaining: Int?
    var restTotal: Int = 0
    /// The set whose checkmark started the active rest timer — unchecking
    /// this specific set should cancel that timer, but unchecking some other
    /// already-completed set shouldn't touch it.
    var restSourceEntryID: PersistentIdentifier?
    @ObservationIgnored private var restTask: Task<Void, Never>?

    var cardioDistance = ""
    var cardioMinutes = ""
    var cardioSeconds = ""
    var cardioStrokeRate = ""

    var hasActiveSession: Bool { session != nil }

    var allSetsComplete: Bool {
        !groups.isEmpty && groups.allSatisfy { !$0.entries.isEmpty && $0.entries.allSatisfy(\.isComplete) }
    }

    func startRest(seconds: Int, sourceEntryID: PersistentIdentifier) {
        restTask?.cancel()
        restSourceEntryID = sourceEntryID
        guard seconds > 0 else {
            restRemaining = nil
            return
        }
        restTotal = seconds
        restRemaining = seconds
        restTask = Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                guard let self, let remaining = self.restRemaining, remaining > 1 else {
                    self?.restRemaining = nil
                    return
                }
                self.restRemaining = remaining - 1
            }
        }
    }

    func skipRest() {
        restTask?.cancel()
        restRemaining = nil
        restSourceEntryID = nil
    }

    /// Called when a set is unchecked — only cancels the timer if that set is
    /// the one that started it, so unchecking an older, unrelated set doesn't
    /// kill the timer for the one in progress.
    func cancelRestIfSource(_ entryID: PersistentIdentifier) {
        guard restSourceEntryID == entryID else { return }
        skipRest()
    }

    /// Clears everything — called after Finish or Cancel, so the next tap on
    /// today's workout box starts (or resumes) from a clean slate.
    func reset() {
        restTask?.cancel()
        session = nil
        groups = []
        restRemaining = nil
        restTotal = 0
        restSourceEntryID = nil
        cardioDistance = ""
        cardioMinutes = ""
        cardioSeconds = ""
        cardioStrokeRate = ""
    }
}
