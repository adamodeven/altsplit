import Foundation
import LocalAuthentication

/// Gates the check-in section behind device authentication.
///
/// Uses `.deviceOwnerAuthentication` (biometrics with passcode fallback)
/// rather than biometrics-only, so a failed or unenrolled Face ID doesn't
/// lock the user out of their own data — Face ID is still the primary path
/// on a device that has it set up.
enum BiometricGate {
    static func authenticate(reason: String) async -> Bool {
        // UI tests run with no user present and no biometrics available;
        // skip the gate so automated flows stay deterministic.
        guard !ProcessInfo.processInfo.arguments.contains("UITEST_RESET") else { return true }

        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No passcode/biometrics enrolled on this device at all — don't
            // lock the user out of their own data over a device setting.
            return true
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
