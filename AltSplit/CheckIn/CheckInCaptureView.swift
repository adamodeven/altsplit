import SwiftUI
import SwiftData

/// Weight + photo, atomically. There is deliberately no path to save one
/// without the other — Save stays disabled until both exist.
struct CheckInCaptureView: View {
    let program: Program
    let previousCheckIn: CheckIn?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var weightText = ""
    @State private var capturedImage: UIImage?
    @State private var ghostImage: UIImage?
    @State private var isAuthenticating = true
    @State private var isAuthenticated = false

    var body: some View {
        NavigationStack {
            Group {
                if isAuthenticating {
                    ProgressView()
                } else if !isAuthenticated {
                    unauthorizedState
                } else {
                    form
                }
            }
            .navigationTitle("Check In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if isAuthenticated {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save() }
                            .fontWeight(.semibold)
                            .disabled(!canSave)
                            .accessibilityIdentifier("saveCheckInButton")
                    }
                }
            }
        }
        .task {
            ghostImage = previousCheckIn.flatMap { PhotoStore.load($0.photoRef) }
            isAuthenticated = await BiometricGate.authenticate(reason: "Unlock your check-in photos")
            isAuthenticating = false
        }
    }

    private var canSave: Bool {
        capturedImage != nil && Double(weightText) != nil
    }

    private var form: some View {
        Form {
            Section {
                CameraCaptureBox(capturedImage: $capturedImage, ghostImage: ghostImage)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section("Weight") {
                HStack {
                    TextField("Weight", text: $weightText)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("weightField")
                    Text("lb").foregroundStyle(.secondary)
                }
            }
        }
    }

    private var unauthorizedState: some View {
        ContentUnavailableView(
            "Locked",
            systemImage: "faceid",
            description: Text("Authentication is required to view or add check-in photos.")
        )
    }

    private func save() {
        guard let capturedImage, let pounds = Double(weightText) else { return }
        guard let filename = try? PhotoStore.save(capturedImage) else { return }

        let kilograms = pounds * 0.45359237
        let cycleIndex = PhaseCalculator.cycleIndex(on: .now, anchor: program.anchorDate)
        let checkIn = CheckIn(date: .now, weightKilograms: kilograms, photoRef: filename, cycleIndex: cycleIndex)
        modelContext.insert(checkIn)
        try? modelContext.save()
        Task { await AccountabilityCoordinator.refreshBadge(context: modelContext) }
        dismiss()
    }
}
