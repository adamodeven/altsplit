import SwiftUI

/// Placeholder for the weight + photo capture sheet. The real flow (camera,
/// onion-skin overlay, atomic save) is a separate increment — this exists
/// so the check-in box has somewhere to go when due.
struct CheckInCaptureStubView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Check-In Capture",
                systemImage: "camera.fill",
                description: Text("Weight + photo capture with onion-skin overlay is coming in a later step.")
            )
            .navigationTitle("Check In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
