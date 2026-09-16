import Foundation

/// Central place for product/placement parameters.
enum PlacementConfiguration {
    /// Length of the rotation cycle shown in the tracker and the look-back window
    /// for the "recently used exact location" rule.
    static let rotationWindowDays = 14

    /// Radius (in metres, body-model space; the model is ~1.75 m tall) around a
    /// recent placement that is treated as "the same spot".
    ///
    /// MVP implementation parameter only. This value has NOT been clinically or
    /// product validated; it exists so two taps that are effectively the same
    /// location are treated as such. Calibrate before any real-world use.
    static let exclusionRadius: Float = 0.05

    /// Rules bundle consumed by the domain layer so tests can override values.
    static var defaultRules: PlacementRules {
        PlacementRules(
            rotationWindowDays: rotationWindowDays,
            exclusionRadius: exclusionRadius,
            sideRecommendationEnabled: true)
    }
}

struct PlacementRules: Hashable, Sendable {
    var rotationWindowDays: Int
    var exclusionRadius: Float
    var sideRecommendationEnabled: Bool
}
