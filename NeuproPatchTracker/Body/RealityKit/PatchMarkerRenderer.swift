import Foundation
import RealityKit
import UIKit
import simd

enum PatchMarkerStyle {
    case today
    case history
    case blocked
    case focused
}

/// Creates small transdermal-patch shaped markers attached flush to the body surface.
@MainActor
enum PatchMarkerRenderer {
    static let patchSize: Float = 0.042

    static func makeMarker(
        at location: SurfaceLocation,
        style: PatchMarkerStyle,
        placementID: UUID?,
        exclusionRadius: Float?
    ) -> Entity {
        let anchor = Entity()
        anchor.name = "marker"
        anchor.position = location.position
        anchor.orientation = orientation(alignedTo: location.normal)

        let size = style == .today || style == .focused ? patchSize * 1.15 : patchSize
        let thickness: Float = 0.004

        // Backing/border for contrast against skin.
        let border = ModelEntity(
            mesh: .generateBox(size: SIMD3(size + 0.008, size + 0.008, thickness * 0.8), cornerRadius: 0.006),
            materials: [SimpleMaterial(color: borderColor(style), roughness: 0.5, isMetallic: false)])
        border.position = SIMD3(0, 0, thickness * 0.5)
        anchor.addChild(border)

        let patch = ModelEntity(
            mesh: .generateBox(size: SIMD3(size, size, thickness), cornerRadius: 0.005),
            materials: [SimpleMaterial(color: fillColor(style), roughness: 0.4, isMetallic: false)])
        patch.position = SIMD3(0, 0, thickness)
        anchor.addChild(patch)

        if let placementID {
            patch.components.set(PlacementMarkerComponent(placementID: placementID))
            patch.components.set(CollisionComponent(shapes: [
                .generateBox(size: SIMD3(size + 0.01, size + 0.01, thickness * 3)),
            ]))
        }

        if let exclusionRadius {
            let halo = ModelEntity(
                mesh: .generateCylinder(height: 0.0015, radius: exclusionRadius),
                materials: [haloMaterial(style)])
            // Cylinder axis is +Y; rotate so it lies flat on the surface (marker +Z = normal).
            halo.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0))
            halo.position = SIMD3(0, 0, 0.0015)
            anchor.addChild(halo)
        }

        return anchor
    }

    static func orientation(alignedTo normal: SIMD3<Float>) -> simd_quatf {
        let n = simd_length(normal) > 0 ? simd_normalize(normal) : SIMD3<Float>(0, 0, 1)
        let from = SIMD3<Float>(0, 0, 1)
        let d = simd_dot(from, n)
        if d > 0.9999 { return simd_quatf(angle: 0, axis: SIMD3(0, 1, 0)) }
        if d < -0.9999 { return simd_quatf(angle: .pi, axis: SIMD3(0, 1, 0)) }
        return simd_quatf(from: from, to: n)
    }

    private static func fillColor(_ style: PatchMarkerStyle) -> UIColor {
        switch style {
        case .today: return UIColor(red: 0.96, green: 0.62, blue: 0.16, alpha: 1)
        case .focused: return UIColor(red: 0.20, green: 0.55, blue: 0.95, alpha: 1)
        case .history: return UIColor(red: 0.93, green: 0.90, blue: 0.84, alpha: 1)
        case .blocked: return UIColor(red: 0.80, green: 0.30, blue: 0.28, alpha: 1)
        }
    }

    private static func borderColor(_ style: PatchMarkerStyle) -> UIColor {
        switch style {
        case .today, .focused: return .white
        case .history: return UIColor(white: 0.45, alpha: 1)
        case .blocked: return .white
        }
    }

    private static func haloMaterial(_ style: PatchMarkerStyle) -> UnlitMaterial {
        var material = UnlitMaterial(color: UIColor(red: 0.55, green: 0.45, blue: 0.40, alpha: 1))
        material.blending = .transparent(opacity: .init(floatLiteral: 0.22))
        return material
    }
}
