import Foundation
import simd
import Testing
@testable import NeuproPatchTracker

struct BodyModelTests {
    let model = HumanBodyModel.standard
    let mapper = BodyRegionMapper()

    @Test func distanceIsEuclidean() {
        let a = SurfaceLocation(meshIdentifier: "torso", position: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        let b = SurfaceLocation(meshIdentifier: "torso", position: SIMD3(0.03, 0.04, 0), normal: SIMD3(0, 0, 1))
        #expect(abs(PlacementDistanceCalculator.distance(between: a, and: b) - 0.05) < 1e-6)
        #expect(PlacementDistanceCalculator.isWithinExclusionRadius(a, b, radius: 0.05))
        #expect(!PlacementDistanceCalculator.isWithinExclusionRadius(a, b, radius: 0.049))
    }

    @Test func surfaceParametersRoundTrip() {
        for part in model.parts where model.selectablePartIDs.contains(part.id) {
            for h: Float in [0.1, 0.5, 0.9] {
                for angle: Float in [-150, -90, -30, 0, 45, 90, 170] {
                    let p = part.surfacePoint(height: h, angleDegrees: angle)
                    let back = part.surfaceParameters(for: p.position)
                    #expect(abs(back.height - h) < 0.02, "height on \(part.id)")
                    var delta = back.angleDegrees - angle
                    if delta > 180 { delta -= 360 }
                    if delta < -180 { delta += 360 }
                    #expect(abs(delta) < 2, "angle on \(part.id)")
                }
            }
        }
    }

    @Test func everyRegionCenterMapsBackToItself() {
        for region in BodyRegionDefinitions.all {
            for patch in region.surfaceDefinition.patches {
                let h = (patch.heightRange.lowerBound + patch.heightRange.upperBound) / 2
                let a = (patch.angleRange.lowerBound + patch.angleRange.upperBound) / 2
                let location = model.surfaceLocation(onPart: patch.meshIdentifier, height: h, angleDegrees: a)!
                #expect(mapper.region(for: location)?.id == region.id, "\(region.id)")
            }
        }
    }

    @Test func regionsDoNotOverlap() {
        for part in model.parts where model.selectablePartIDs.contains(part.id) {
            for hi in stride(from: Float(0.02), through: 0.98, by: 0.04) {
                for angle in stride(from: Float(-179), through: 179, by: 6) {
                    let location = model.surfaceLocation(onPart: part.id, height: hi, angleDegrees: angle)!
                    let matches = BodyRegionDefinitions.all.filter { region in
                        region.surfaceDefinition.patches.contains {
                            $0.meshIdentifier == part.id && $0.contains(height: hi, angle: angle)
                        }
                    }
                    #expect(matches.count <= 1, "\(part.id) h=\(hi) a=\(angle) -> \(matches.map(\.id))")
                    if matches.count == 1 {
                        #expect(mapper.region(for: location)?.id == matches[0].id)
                    }
                }
            }
        }
    }

    @Test func nonSelectablePartsHaveNoRegion() {
        let location = model.surfaceLocation(onPart: BodyPartID.head, height: 0.5, angleDegrees: 0)!
        #expect(mapper.region(for: location) == nil)
    }

    @Test func torsoCenterFrontIsNotAnApprovedRegion() {
        // The midline (spine/navel) is left unshaded in the tracker artwork.
        let location = model.surfaceLocation(onPart: BodyPartID.torso, height: 0.5, angleDegrees: 0)!
        #expect(mapper.region(for: location) == nil)
    }

    @Test func sidesMatchCoordinateSystem() {
        // +X is the patient's left.
        let left = model.surfaceLocation(onPart: BodyPartID.leftUpperArm, height: 0.5, angleDegrees: 90)!
        let right = model.surfaceLocation(onPart: BodyPartID.rightUpperArm, height: 0.5, angleDegrees: -90)!
        #expect(left.position.x > 0)
        #expect(right.position.x < 0)
        #expect(mapper.region(for: left)?.side == .left)
        #expect(mapper.region(for: right)?.side == .right)
    }

    @Test func meshesAreWellFormed() {
        for part in model.parts {
            let mesh = LoftMeshBuilder.build(part)
            #expect(mesh.positions.count == mesh.normals.count)
            #expect(mesh.indices.count % 3 == 0)
            #expect(mesh.indices.allSatisfy { Int($0) < mesh.positions.count })
            #expect(mesh.indices.count > 0)

            // Side-wall normals must face outward (away from the section centre).
            for (i, p) in mesh.positions.enumerated() where i < part.sections.count * part.segments {
                let s = part.section(at: p.y)
                let outward = SIMD3<Float>(p.x - s.centerX, 0, p.z - s.centerZ)
                #expect(simd_dot(mesh.normals[i], outward) > 0, "inward normal in \(part.id)")
            }
        }
    }

    @Test func surfaceLocationCodableRoundTrip() throws {
        let original = SurfaceLocation(meshIdentifier: "torso", position: SIMD3(0.1, 1.2, 0.05), normal: SIMD3(0, 0, 1))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SurfaceLocation.self, from: data)
        #expect(decoded == original)
    }
}
