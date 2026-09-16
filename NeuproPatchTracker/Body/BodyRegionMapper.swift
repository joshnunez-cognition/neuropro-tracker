import Foundation
import simd

/// Resolves surface locations to approved regions and classifies mesh triangles for overlays.
struct BodyRegionMapper: Sendable {
    var model: HumanBodyModel
    var regions: [BodyRegion]

    init(model: HumanBodyModel = .standard, regions: [BodyRegion] = BodyRegionDefinitions.all) {
        self.model = model
        self.regions = regions
    }

    func region(for location: SurfaceLocation) -> BodyRegion? {
        guard model.selectablePartIDs.contains(location.meshIdentifier),
              let part = model.part(withID: location.meshIdentifier)
        else { return nil }
        let params = part.surfaceParameters(for: location.position)
        return regions.first { region in
            region.surfaceDefinition.patches.contains {
                $0.meshIdentifier == location.meshIdentifier
                    && $0.contains(height: params.height, angle: params.angleDegrees)
            }
        }
    }

    /// Triangles of `part`'s mesh whose vertices all lie inside `region`, as index
    /// triples into `mesh.positions`.
    func triangleIndices(of region: BodyRegion, part: BodyPart, mesh: LoftMesh) -> [UInt32] {
        let patches = region.surfaceDefinition.patches.filter { $0.meshIdentifier == part.id }
        guard !patches.isEmpty else { return [] }

        let inside: [Bool] = mesh.positions.enumerated().map { index, p in
            // Cap centre vertices are never part of a region.
            if index >= part.sections.count * part.segments { return false }
            let params = part.surfaceParameters(for: p)
            return patches.contains { $0.contains(height: params.height, angle: params.angleDegrees) }
        }

        var result: [UInt32] = []
        var i = 0
        while i + 2 < mesh.indices.count {
            let a = mesh.indices[i], b = mesh.indices[i + 1], c = mesh.indices[i + 2]
            if inside[Int(a)] && inside[Int(b)] && inside[Int(c)] {
                result += [a, b, c]
            }
            i += 3
        }
        return result
    }
}
