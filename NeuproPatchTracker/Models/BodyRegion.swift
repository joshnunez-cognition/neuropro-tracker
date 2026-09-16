import Foundation

/// A rectangular patch of a body part's surface expressed in the part's
/// cylindrical parameter space.
///
/// - `heightRange`: normalized height along the part (0 = bottom, 1 = top).
/// - `angleRange`: degrees around the part's axis. 0° faces front (+Z),
///   +90° is the patient's left (+X), ±180° is the back, -90° is the patient's right.
struct SurfacePatch: Hashable, Sendable {
    var meshIdentifier: String
    var heightRange: ClosedRange<Float>
    var angleRange: ClosedRange<Float>

    func contains(height: Float, angle: Float) -> Bool {
        heightRange.contains(height) && angleRange.contains(angle)
    }
}

struct RegionSurfaceDefinition: Hashable, Sendable {
    var patches: [SurfacePatch]

    var meshIdentifiers: Set<String> { Set(patches.map(\.meshIdentifier)) }
}

struct BodyRegion: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let side: BodySide
    let surfaceDefinition: RegionSurfaceDefinition
}

/// Availability of a region for today's placement, derived from history.
enum RegionAvailability: String, Sendable {
    case available
    case recommended
    case unavailable
    case selected

    var label: String {
        switch self {
        case .available: return "Available"
        case .recommended: return "Recommended"
        case .unavailable: return "Used yesterday"
        case .selected: return "Selected"
        }
    }

    var symbolName: String {
        switch self {
        case .available: return "circle"
        case .recommended: return "star.fill"
        case .unavailable: return "minus.circle.fill"
        case .selected: return "checkmark.circle.fill"
        }
    }
}
