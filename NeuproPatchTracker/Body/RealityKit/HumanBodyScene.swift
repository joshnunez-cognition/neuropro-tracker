import Foundation
import RealityKit
import UIKit

/// Tags a body part entity with its `BodyPart` identifier.
struct BodyPartComponent: Component {
    var partID: String
}

/// Tags a rendered marker with the placement it represents.
struct PlacementMarkerComponent: Component {
    var placementID: UUID
}

/// Tags a region overlay entity.
struct RegionOverlayComponent: Component {
    var regionID: String
}

/// Builds the RealityKit entity hierarchy for the procedural human body.
@MainActor
enum HumanBodyScene {
    static let skinColor = UIColor(red: 0.86, green: 0.78, blue: 0.70, alpha: 1)

    struct Built {
        var root: Entity
        var body: Entity
        var parts: [String: ModelEntity]
        var overlays: [String: ModelEntity]
    }

    static func registerComponents() {
        BodyPartComponent.registerComponent()
        PlacementMarkerComponent.registerComponent()
        RegionOverlayComponent.registerComponent()
    }

    static func build(model: HumanBodyModel, mapper: BodyRegionMapper) async throws -> Built {
        registerComponents()

        let root = Entity()
        root.name = "bodyRoot"

        let body = Entity()
        body.name = "body"
        root.addChild(body)

        var skin = PhysicallyBasedMaterial()
        skin.baseColor = .init(tint: skinColor)
        skin.roughness = .init(floatLiteral: 0.62)
        skin.metallic = .init(floatLiteral: 0.0)
        skin.specular = .init(floatLiteral: 0.25)

        var parts: [String: ModelEntity] = [:]
        var overlays: [String: ModelEntity] = [:]

        for part in model.parts {
            let loft = LoftMeshBuilder.build(part)
            let mesh = try makeMesh(name: part.id, positions: loft.positions, normals: loft.normals, indices: loft.indices)
            let entity = ModelEntity(mesh: mesh, materials: [skin])
            entity.name = part.id
            entity.components.set(BodyPartComponent(partID: part.id))

            if model.selectablePartIDs.contains(part.id) {
                let shape: ShapeResource
                if let precise = try? await ShapeResource.generateStaticMesh(from: mesh) {
                    shape = precise
                } else {
                    shape = try await ShapeResource.generateConvex(from: mesh)
                }
                entity.components.set(CollisionComponent(shapes: [shape], mode: .default, filter: .default))
            }
            body.addChild(entity)
            parts[part.id] = entity

            for region in mapper.regions where region.surfaceDefinition.meshIdentifiers.contains(part.id) {
                let tris = mapper.triangleIndices(of: region, part: part, mesh: loft)
                guard !tris.isEmpty else { continue }
                // Push the overlay slightly off the skin so it does not z-fight.
                let offsetPositions = zip(loft.positions, loft.normals).map { $0 + $1 * 0.0025 }
                let overlayMesh = try makeMesh(
                    name: "overlay_\(region.id)_\(part.id)", positions: offsetPositions,
                    normals: loft.normals, indices: tris)
                let overlay = ModelEntity(
                    mesh: overlayMesh, materials: [RegionMaterials.material(for: .available)])
                overlay.name = "overlay_\(region.id)"
                overlay.components.set(RegionOverlayComponent(regionID: region.id))
                body.addChild(overlay)
                overlays[region.id] = overlay
            }
        }

        return Built(root: root, body: body, parts: parts, overlays: overlays)
    }

    static func makeMesh(
        name: String, positions: [SIMD3<Float>], normals: [SIMD3<Float>], indices: [UInt32]
    ) throws -> MeshResource {
        var descriptor = MeshDescriptor(name: name)
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }

    /// Camera + lights for a studio-like neutral presentation.
    static func makeLighting() -> [Entity] {
        let key = DirectionalLight()
        key.light.intensity = 2600
        key.light.color = UIColor(white: 1.0, alpha: 1)
        key.look(at: SIMD3(0, 0.9, 0), from: SIMD3(1.5, 3.0, 2.5), relativeTo: nil)

        let fill = DirectionalLight()
        fill.light.intensity = 1100
        fill.light.color = UIColor(red: 0.85, green: 0.9, blue: 1.0, alpha: 1)
        fill.look(at: SIMD3(0, 0.9, 0), from: SIMD3(-2.5, 1.5, 1.5), relativeTo: nil)

        let rim = DirectionalLight()
        rim.light.intensity = 900
        rim.look(at: SIMD3(0, 0.9, 0), from: SIMD3(0.5, 2.0, -3.0), relativeTo: nil)

        return [key, fill, rim]
    }
}

@MainActor
enum RegionMaterials {
    static func color(for availability: RegionAvailability) -> UIColor {
        switch availability {
        case .available: return UIColor(red: 0.18, green: 0.55, blue: 0.85, alpha: 1)
        case .recommended: return UIColor(red: 0.12, green: 0.66, blue: 0.42, alpha: 1)
        case .unavailable: return UIColor(red: 0.45, green: 0.45, blue: 0.48, alpha: 1)
        case .selected: return UIColor(red: 0.95, green: 0.55, blue: 0.10, alpha: 1)
        }
    }

    static func opacity(for availability: RegionAvailability) -> Float {
        switch availability {
        case .available: return 0.30
        case .recommended: return 0.50
        case .unavailable: return 0.12
        case .selected: return 0.55
        }
    }

    static func material(for availability: RegionAvailability) -> UnlitMaterial {
        var material = UnlitMaterial(color: color(for: availability))
        material.blending = .transparent(opacity: .init(floatLiteral: opacity(for: availability)))
        material.faceCulling = .back
        return material
    }
}
