import AVFoundation
import UIKit

/// Thin wrapper around an `AVCaptureSession` for the check-in viewfinder.
/// `isAvailable` is false on Simulator (no camera hardware), which the UI
/// uses to fall back to a photo picker.
@MainActor
final class CameraSessionController: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var completion: ((UIImage?) -> Void)?

    let isAvailable: Bool

    override init() {
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(for: .video)
        isAvailable = device != nil
        super.init()

        guard let device, let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
    }

    func start() {
        guard isAvailable, !session.isRunning else { return }
        session.startRunning()
    }

    func stop() {
        guard session.isRunning else { return }
        session.stopRunning()
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        // The preview layer auto-mirrors the front camera feed, but the photo
        // output connection doesn't by default — without this the saved photo
        // comes out flipped relative to what was shown before the shutter.
        if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }
}

extension CameraSessionController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        Task { @MainActor in
            completion?(image)
            completion = nil
        }
    }
}
