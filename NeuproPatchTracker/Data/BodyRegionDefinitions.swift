import Foundation

/// Approved NEUPRO placement areas mapped onto the procedural body.
///
/// The shaded areas on the official NEUPRO Patch Placement Tracker
/// (https://www.neupro.com/neupro-patch-placement-tracker.pdf) are:
/// shoulder/upper arm, abdomen (a band around the waist), hip/flank (seen from
/// the side and back) and the front of the thigh, each on the left and right.
///
/// Boundaries below are expressed in each body part's parameter space
/// (normalized height + angle around the part axis, see `SurfacePatch`). They were
/// eyeballed against the tracker artwork and REQUIRE CLINICAL/PRODUCT VALIDATION
/// before real-world use. Adjust the numbers here; nothing else needs to change.
enum BodyRegionDefinitions {
    static let all: [BodyRegion] = [
        BodyRegion(
            id: "left_upper_arm", name: "Left upper arm", side: .left,
            surfaceDefinition: RegionSurfaceDefinition(patches: [
                SurfacePatch(meshIdentifier: BodyPartID.leftUpperArm, heightRange: 0.08...1.0, angleRange: -180...180),
            ])),
        BodyRegion(
            id: "right_upper_arm", name: "Right upper arm", side: .right,
            surfaceDefinition: RegionSurfaceDefinition(patches: [
                SurfacePatch(meshIdentifier: BodyPartID.rightUpperArm, heightRange: 0.08...1.0, angleRange: -180...180),
            ])),
        BodyRegion(
            id: "left_abdomen", name: "Left abdomen", side: .left,
            surfaceDefinition: RegionSurfaceDefinition(patches: [
                SurfacePatch(meshIdentifier: BodyPartID.torso, heightRange: 0.26...0.52, angleRange: 8...105),
            ])),
        BodyRegion(
            id: "right_abdomen", name: "Right abdomen", side: .right,
            surfaceDefinition: RegionSurfaceDefinition(patches: [
                SurfacePatch(meshIdentifier: BodyPartID.torso, heightRange: 0.26...0.52, angleRange: -105...(-8)),
            ])),
        BodyRegion(
            id: "left_hip", name: "Left hip", side: .left,
            surfaceDefinition: RegionSurfaceDefinition(patches: [
                SurfacePatch(meshIdentifier: BodyPartID.torso, heightRange: 0.04...0.24, angleRange: 95...180),
            ])),
        BodyRegion(
            id: "right_hip", name: "Right hip", side: .right,
            surfaceDefinition: RegionSurfaceDefinition(patches: [
                SurfacePatch(meshIdentifier: BodyPartID.torso, heightRange: 0.04...0.24, angleRange: -180...(-95)),
            ])),
        BodyRegion(
            id: "left_thigh", name: "Left thigh", side: .left,
            surfaceDefinition: RegionSurfaceDefinition(patches: [
                SurfacePatch(meshIdentifier: BodyPartID.leftUpperLeg, heightRange: 0.3...0.92, angleRange: -75...75),
            ])),
        BodyRegion(
            id: "right_thigh", name: "Right thigh", side: .right,
            surfaceDefinition: RegionSurfaceDefinition(patches: [
                SurfacePatch(meshIdentifier: BodyPartID.rightUpperLeg, heightRange: 0.3...0.92, angleRange: -75...75),
            ])),
    ]

    static func region(withID id: String) -> BodyRegion? {
        all.first { $0.id == id }
    }
}
