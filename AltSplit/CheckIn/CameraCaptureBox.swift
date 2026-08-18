import SwiftUI
import PhotosUI

/// The viewfinder. Ghosts the previous check-in's photo at ~30% opacity so
/// pose, distance, and framing match — without this the photos aren't
/// comparable six months out, which defeats the point.
struct CameraCaptureBox: View {
    @Binding var capturedImage: UIImage?
    let ghostImage: UIImage?

    @StateObject private var camera = CameraSessionController()
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)

            if let capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFill()
            } else if camera.isAvailable {
                CameraPreviewRepresentable(session: camera.session)
            } else {
                Text("Camera unavailable in Simulator")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding()
            }

            if capturedImage == nil, let ghostImage {
                Image(uiImage: ghostImage)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.3)
                    .allowsHitTesting(false)
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .bottom) {
            controls.padding(.bottom, 16)
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .task(id: pickerItem) {
            guard let pickerItem,
                  let data = try? await pickerItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }
            capturedImage = image
        }
    }

    @ViewBuilder
    private var controls: some View {
        if capturedImage != nil {
            Button("Retake") { capturedImage = nil }
                .buttonStyle(.glass)
                .accessibilityIdentifier("retakeButton")
        } else if camera.isAvailable {
            Button {
                camera.capturePhoto { image in capturedImage = image }
            } label: {
                Image(systemName: "circle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }
            .accessibilityIdentifier("shutterButton")
        } else {
            HStack(spacing: 12) {
                PhotosPicker("Choose Photo", selection: $pickerItem, matching: .images)
                    .buttonStyle(.glassProminent)
                    .accessibilityIdentifier("choosePhotoButton")

                // Test-only affordance: the system photo picker is a
                // separate process XCUITest can't drive deterministically,
                // so UI tests use this instead to exercise the real save
                // path end to end.
                if ProcessInfo.processInfo.arguments.contains("UITEST_RESET") {
                    Button("Use Test Photo") {
                        capturedImage = .solidColor(.systemTeal, size: CGSize(width: 300, height: 400))
                    }
                    .buttonStyle(.glass)
                    .accessibilityIdentifier("useTestPhotoButton")
                }
            }
        }
    }
}

private extension UIImage {
    static func solidColor(_ color: UIColor, size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
