import Foundation
import simd

/// Identifiers of the body parts that make up the procedural human model.
enum BodyPartID {
    static let head = "head"
    static let neck = "neck"
    static let torso = "torso"
    static let leftUpperArm = "leftUpperArm"
    static let rightUpperArm = "rightUpperArm"
    static let leftLowerArm = "leftLowerArm"
    static let rightLowerArm = "rightLowerArm"
    static let leftHand = "leftHand"
    static let rightHand = "rightHand"
    static let leftUpperLeg = "leftUpperLeg"
    static let rightUpperLeg = "rightUpperLeg"
    static let leftLowerLeg = "leftLowerLeg"
    static let rightLowerLeg = "rightLowerLeg"
    static let leftFoot = "leftFoot"
    static let rightFoot = "rightFoot"
}

/// One elliptical cross-section of a lofted body part, in body space (metres).
struct LoftSection: Hashable, Sendable {
    var y: Float
    var centerX: Float
    var centerZ: Float
    var radiusX: Float
    var radiusZ: Float
}

/// A body part described as a stack of elliptical cross-sections.
///
/// Body space: origin between the feet, +Y up, +Z toward the front of the body,
/// +X toward the patient's LEFT (the body faces the viewer).
struct BodyPart: Identifiable, Hashable, Sendable {
    let id: String
    var sections: [LoftSection]
    var segments: Int = 40

    var minY: Float { sections.first?.y ?? 0 }
    var maxY: Float { sections.last?.y ?? 0 }

    /// Interpolated cross-section at height `y` (clamped to the part).
    func section(at y: Float) -> LoftSection {
        guard let first = sections.first, let last = sections.last else {
            return LoftSection(y: y, centerX: 0, centerZ: 0, radiusX: 0, radiusZ: 0)
        }
        if y <= first.y { return first }
        if y >= last.y { return last }
        for i in 1..<sections.count where y <= sections[i].y {
            let a = sections[i - 1], b = sections[i]
            let t = (b.y - a.y) > 0 ? (y - a.y) / (b.y - a.y) : 0
            return LoftSection(
                y: y,
                centerX: a.centerX + (b.centerX - a.centerX) * t,
                centerZ: a.centerZ + (b.centerZ - a.centerZ) * t,
                radiusX: a.radiusX + (b.radiusX - a.radiusX) * t,
                radiusZ: a.radiusZ + (b.radiusZ - a.radiusZ) * t)
        }
        return last
    }

    /// Normalized height (0 bottom ... 1 top) and angle in degrees around the
    /// part's axis (0 = front, +90 = patient's left, ±180 = back).
    func surfaceParameters(for point: SIMD3<Float>) -> (height: Float, angleDegrees: Float) {
        let span = max(maxY - minY, 0.0001)
        let height = (point.y - minY) / span
        let s = section(at: point.y)
        let angle = atan2(point.x - s.centerX, point.z - s.centerZ) * 180 / .pi
        return (height, angle)
    }

    /// Point and outward normal on the loft surface for given parameters.
    func surfacePoint(height: Float, angleDegrees: Float) -> (position: SIMD3<Float>, normal: SIMD3<Float>) {
        let y = minY + (maxY - minY) * min(max(height, 0), 1)
        let s = section(at: y)
        let phi = angleDegrees * .pi / 180
        let rx = max(s.radiusX, 0.0001), rz = max(s.radiusZ, 0.0001)
        // Convert the geometric angle (what `surfaceParameters` measures) to the
        // ellipse's parametric angle so the two functions are exact inverses.
        let theta = atan2(rz * sin(phi), rx * cos(phi))
        let position = SIMD3<Float>(
            s.centerX + rx * sin(theta), y, s.centerZ + rz * cos(theta))
        let normal = simd_normalize(SIMD3<Float>(sin(theta) / rx, 0, cos(theta) / rz))
        return (position, normal)
    }
}

/// Triangle mesh data for a lofted part (no RealityKit dependency).
struct LoftMesh: Sendable {
    var positions: [SIMD3<Float>]
    var normals: [SIMD3<Float>]
    var indices: [UInt32]

    /// Ring index (section) for each vertex; caps use the nearest section.
    var sectionIndex: [Int]
}

enum LoftMeshBuilder {
    static func build(_ part: BodyPart) -> LoftMesh {
        let m = part.segments
        var positions: [SIMD3<Float>] = []
        var sectionIndex: [Int] = []
        for (si, s) in part.sections.enumerated() {
            for j in 0..<m {
                let theta = Float(j) / Float(m) * 2 * .pi
                positions.append(SIMD3(
                    s.centerX + s.radiusX * sin(theta), s.y, s.centerZ + s.radiusZ * cos(theta)))
                sectionIndex.append(si)
            }
        }
        // Cap centres.
        let bottom = part.sections.first!
        let top = part.sections.last!
        let bottomCenter = UInt32(positions.count)
        positions.append(SIMD3(bottom.centerX, bottom.y, bottom.centerZ))
        sectionIndex.append(0)
        let topCenter = UInt32(positions.count)
        positions.append(SIMD3(top.centerX, top.y, top.centerZ))
        sectionIndex.append(part.sections.count - 1)

        var indices: [UInt32] = []
        for si in 0..<(part.sections.count - 1) {
            for j in 0..<m {
                let jn = (j + 1) % m
                let a = UInt32(si * m + j)
                let b = UInt32(si * m + jn)
                let c = UInt32((si + 1) * m + j)
                let d = UInt32((si + 1) * m + jn)
                // Counter-clockwise when viewed from outside.
                indices += [a, b, c]
                indices += [b, d, c]
            }
        }
        for j in 0..<m {
            let jn = (j + 1) % m
            indices += [bottomCenter, UInt32(jn), UInt32(j)]
            let base = (part.sections.count - 1) * m
            indices += [topCenter, UInt32(base + j), UInt32(base + jn)]
        }

        var normals = [SIMD3<Float>](repeating: .zero, count: positions.count)
        var i = 0
        while i + 2 < indices.count {
            let ia = Int(indices[i]), ib = Int(indices[i + 1]), ic = Int(indices[i + 2])
            let n = simd_cross(positions[ib] - positions[ia], positions[ic] - positions[ia])
            normals[ia] += n
            normals[ib] += n
            normals[ic] += n
            i += 3
        }
        normals = normals.map { simd_length($0) > 0 ? simd_normalize($0) : SIMD3(0, 1, 0) }
        return LoftMesh(positions: positions, normals: normals, indices: indices, sectionIndex: sectionIndex)
    }
}

/// The procedural, anatomically proportioned human body used by the app.
///
/// Every part is positioned in body space and rendered at the identity transform
/// under a single root entity, so `SurfaceLocation` local coordinates are body-space
/// coordinates. Replace this with a licensed USDZ by providing a different
/// `HumanBodyModel` (parts + parameterization) – see README "Body Model".
struct HumanBodyModel: Sendable {
    let parts: [BodyPart]
    /// Parts that may be hit-tested for placement (regions are defined on these).
    let selectablePartIDs: Set<String>

    /// Approximate overall height in metres.
    var height: Float { parts.map(\.maxY).max() ?? 1.75 }

    func part(withID id: String) -> BodyPart? {
        parts.first { $0.id == id }
    }

    func surfaceLocation(onPart partID: String, height: Float, angleDegrees: Float) -> SurfaceLocation? {
        guard let part = part(withID: partID) else { return nil }
        let p = part.surfacePoint(height: height, angleDegrees: angleDegrees)
        return SurfaceLocation(meshIdentifier: partID, position: p.position, normal: p.normal)
    }

    /// Body-space position for a stored location. Parts are at identity relative to the
    /// body root, so this is a direct read; kept as the single conversion point.
    func bodySpacePosition(for location: SurfaceLocation) -> SIMD3<Float> {
        location.position
    }

    static let standard = HumanBodyModel(parts: HumanBodyProportions.parts, selectablePartIDs: [
        BodyPartID.torso, BodyPartID.leftUpperArm, BodyPartID.rightUpperArm,
        BodyPartID.leftUpperLeg, BodyPartID.rightUpperLeg,
    ])
}

/// Default proportions (~1.75 m adult, neutral build).
enum HumanBodyProportions {
    static var parts: [BodyPart] {
        var result: [BodyPart] = [torso, neck, head]
        for side in BodySide.allCases {
            let sx: Float = side == .left ? 1 : -1
            result += [
                upperArm(side: side, sx: sx),
                lowerArm(side: side, sx: sx),
                hand(side: side, sx: sx),
                upperLeg(side: side, sx: sx),
                lowerLeg(side: side, sx: sx),
                foot(side: side, sx: sx),
            ]
        }
        return result
    }

    static let torso = BodyPart(id: BodyPartID.torso, sections: [
        LoftSection(y: 0.790, centerX: 0, centerZ: 0.000, radiusX: 0.120, radiusZ: 0.080),
        LoftSection(y: 0.815, centerX: 0, centerZ: 0.000, radiusX: 0.160, radiusZ: 0.105),
        LoftSection(y: 0.860, centerX: 0, centerZ: 0.000, radiusX: 0.175, radiusZ: 0.118),
        LoftSection(y: 0.920, centerX: 0, centerZ: 0.000, radiusX: 0.172, radiusZ: 0.115),
        LoftSection(y: 0.980, centerX: 0, centerZ: 0.000, radiusX: 0.158, radiusZ: 0.105),
        LoftSection(y: 1.060, centerX: 0, centerZ: 0.000, radiusX: 0.148, radiusZ: 0.100),
        LoftSection(y: 1.150, centerX: 0, centerZ: 0.002, radiusX: 0.160, radiusZ: 0.108),
        LoftSection(y: 1.250, centerX: 0, centerZ: 0.006, radiusX: 0.176, radiusZ: 0.120),
        LoftSection(y: 1.340, centerX: 0, centerZ: 0.002, radiusX: 0.186, radiusZ: 0.112),
        LoftSection(y: 1.410, centerX: 0, centerZ: 0.000, radiusX: 0.192, radiusZ: 0.100),
        LoftSection(y: 1.445, centerX: 0, centerZ: 0.000, radiusX: 0.160, radiusZ: 0.085),
        LoftSection(y: 1.470, centerX: 0, centerZ: 0.000, radiusX: 0.105, radiusZ: 0.070),
        LoftSection(y: 1.490, centerX: 0, centerZ: 0.000, radiusX: 0.062, radiusZ: 0.056),
    ], segments: 56)

    static let neck = BodyPart(id: BodyPartID.neck, sections: [
        LoftSection(y: 1.470, centerX: 0, centerZ: -0.005, radiusX: 0.058, radiusZ: 0.055),
        LoftSection(y: 1.560, centerX: 0, centerZ: -0.005, radiusX: 0.052, radiusZ: 0.050),
    ], segments: 32)

    static var head: BodyPart {
        let cy: Float = 1.665, ry: Float = 0.118, rx: Float = 0.083, rz: Float = 0.098
        var sections: [LoftSection] = []
        let n = 12
        for i in 0...n {
            let phi = -Float.pi / 2 + Float.pi * Float(i) / Float(n)
            let scale = max(cos(phi), 0.02)
            // Slightly narrower toward the chin.
            let chin: Float = phi < 0 ? 0.92 + 0.08 * (1 + sin(phi)) : 1
            sections.append(LoftSection(
                y: cy + ry * sin(phi), centerX: 0, centerZ: 0.0,
                radiusX: rx * scale * chin, radiusZ: rz * scale))
        }
        return BodyPart(id: BodyPartID.head, sections: sections, segments: 40)
    }

    /// Tapered limb between two points with rounded ends.
    private static func limb(
        id: String, from top: SIMD2<Float>, to bottom: SIMD2<Float>, z: Float = 0,
        radii: [(t: Float, r: Float)], flattenZ: Float = 1, segments: Int = 32
    ) -> BodyPart {
        var sections: [LoftSection] = []
        let steps = 14
        for i in 0...steps {
            let t = Float(i) / Float(steps)
            let x = bottom.x + (top.x - bottom.x) * t
            let y = bottom.y + (top.y - bottom.y) * t
            var r = radius(at: t, radii: radii)
            // Round the ends.
            let edge: Float = 0.08
            if t < edge { r *= sqrt(max(0, 1 - pow((edge - t) / edge, 2))) + 0.02 }
            if t > 1 - edge { r *= sqrt(max(0, 1 - pow((t - (1 - edge)) / edge, 2))) + 0.02 }
            sections.append(LoftSection(y: y, centerX: x, centerZ: z, radiusX: r, radiusZ: r * flattenZ))
        }
        return BodyPart(id: id, sections: sections, segments: segments)
    }

    private static func radius(at t: Float, radii: [(t: Float, r: Float)]) -> Float {
        guard let first = radii.first, let last = radii.last else { return 0.05 }
        if t <= first.t { return first.r }
        if t >= last.t { return last.r }
        for i in 1..<radii.count where t <= radii[i].t {
            let a = radii[i - 1], b = radii[i]
            let k = (t - a.t) / max(b.t - a.t, 0.0001)
            return a.r + (b.r - a.r) * k
        }
        return last.r
    }

    static func upperArm(side: BodySide, sx: Float) -> BodyPart {
        limb(id: side == .left ? BodyPartID.leftUpperArm : BodyPartID.rightUpperArm,
             from: SIMD2(sx * 0.205, 1.425), to: SIMD2(sx * 0.240, 1.120),
             radii: [(0, 0.045), (0.3, 0.050), (0.75, 0.056), (1.0, 0.062)])
    }

    static func lowerArm(side: BodySide, sx: Float) -> BodyPart {
        limb(id: side == .left ? BodyPartID.leftLowerArm : BodyPartID.rightLowerArm,
             from: SIMD2(sx * 0.242, 1.130), to: SIMD2(sx * 0.268, 0.850),
             radii: [(0, 0.032), (0.4, 0.040), (1.0, 0.048)])
    }

    static func hand(side: BodySide, sx: Float) -> BodyPart {
        limb(id: side == .left ? BodyPartID.leftHand : BodyPartID.rightHand,
             from: SIMD2(sx * 0.270, 0.855), to: SIMD2(sx * 0.282, 0.680),
             radii: [(0, 0.030), (0.5, 0.045), (1.0, 0.036)], flattenZ: 0.45, segments: 24)
    }

    static func upperLeg(side: BodySide, sx: Float) -> BodyPart {
        limb(id: side == .left ? BodyPartID.leftUpperLeg : BodyPartID.rightUpperLeg,
             from: SIMD2(sx * 0.092, 0.880), to: SIMD2(sx * 0.100, 0.470),
             radii: [(0, 0.062), (0.15, 0.068), (0.6, 0.082), (1.0, 0.092)])
    }

    static func lowerLeg(side: BodySide, sx: Float) -> BodyPart {
        limb(id: side == .left ? BodyPartID.leftLowerLeg : BodyPartID.rightLowerLeg,
             from: SIMD2(sx * 0.100, 0.480), to: SIMD2(sx * 0.100, 0.060), z: -0.005,
             radii: [(0, 0.038), (0.25, 0.048), (0.7, 0.062), (1.0, 0.058)])
    }

    static func foot(side: BodySide, sx: Float) -> BodyPart {
        // A short flattened loft; the foot extends forward via a shifted centre.
        let id = side == .left ? BodyPartID.leftFoot : BodyPartID.rightFoot
        return BodyPart(id: id, sections: [
            LoftSection(y: 0.000, centerX: sx * 0.100, centerZ: 0.045, radiusX: 0.040, radiusZ: 0.115),
            LoftSection(y: 0.020, centerX: sx * 0.100, centerZ: 0.045, radiusX: 0.046, radiusZ: 0.125),
            LoftSection(y: 0.055, centerX: sx * 0.100, centerZ: 0.025, radiusX: 0.044, radiusZ: 0.095),
            LoftSection(y: 0.085, centerX: sx * 0.100, centerZ: -0.005, radiusX: 0.040, radiusZ: 0.060),
        ], segments: 28)
    }
}
