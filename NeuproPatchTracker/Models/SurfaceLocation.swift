import Foundation
import simd

/// A stable description of a point on the human body's surface.
///
/// The body is a deterministic procedural model made of named parts. Every part is
/// placed at the identity transform relative to the body root, so a point expressed
/// in the part's local space is also a body-space point. Storing the part identifier
/// alongside the local coordinates lets the marker be reconstructed on the same part
/// even if unrelated parts are later adjusted, and lets the region mapper resolve the
/// point without a scene.
struct SurfaceLocation: Codable, Hashable, Sendable {
    var meshIdentifier: String

    var localX: Float
    var localY: Float
    var localZ: Float

    var normalX: Float
    var normalY: Float
    var normalZ: Float

    init(meshIdentifier: String, position: SIMD3<Float>, normal: SIMD3<Float>) {
        self.meshIdentifier = meshIdentifier
        localX = position.x
        localY = position.y
        localZ = position.z
        let n = simd_length(normal) > 0 ? simd_normalize(normal) : SIMD3<Float>(0, 0, 1)
        normalX = n.x
        normalY = n.y
        normalZ = n.z
    }

    var position: SIMD3<Float> { SIMD3(localX, localY, localZ) }
    var normal: SIMD3<Float> { SIMD3(normalX, normalY, normalZ) }
}
