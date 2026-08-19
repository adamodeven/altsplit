import Foundation
import SwiftUI

/// Shared corner treatment for the home screen's bento boxes. Explicit
/// radius rather than `.rect(corners: .concentric)` — concentric corners
/// need an ancestor container to match against, and these boxes float
/// directly in the scroll content, so they'd otherwise resolve to square
/// corners while the press-state highlight still renders rounded.
enum BentoBoxStyle {
    static let cornerRadius: CGFloat = 28
    static var shape: some Shape { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous) }
}
