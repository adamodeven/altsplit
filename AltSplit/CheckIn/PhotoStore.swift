import Foundation
import UIKit

/// Check-in photos live in the app's own container, never the camera roll,
/// with file protection so the section can meaningfully sit behind Face ID.
enum PhotoStore {
    enum PhotoStoreError: Error {
        case encodingFailed
    }

    private static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("CheckInPhotos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
        }
        return dir
    }

    @discardableResult
    static func save(_ image: UIImage) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw PhotoStoreError.encodingFailed
        }
        let filename = "\(UUID().uuidString).jpg"
        let url = directory.appendingPathComponent(filename)
        try data.write(to: url, options: [.completeFileProtectionUntilFirstUserAuthentication])
        return filename
    }

    static func load(_ ref: String) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent(ref).path)
    }

    static func delete(_ ref: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(ref))
    }
}
