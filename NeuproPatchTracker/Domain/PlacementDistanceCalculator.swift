import Foundation
import simd

/// Distances between surface locations.
///
/// All body parts share the body root's coordinate frame, so the stored local
/// coordinates are directly comparable. If a future model uses per-part
/// transforms, convert both locations into body space here.
enum PlacementDistanceCalculator {
    static func distance(between a: SurfaceLocation, and b: SurfaceLocation) -> Float {
        simd_distance(a.position, b.position)
    }

    static func isWithinExclusionRadius(
        _ a: SurfaceLocation, _ b: SurfaceLocation, radius: Float
    ) -> Bool {
        distance(between: a, and: b) <= radius
    }
}
