import type { BodySide, SurfaceLocation } from '../models'

/**
 * Procedural, anatomically proportioned human body built from lofted elliptical
 * cross-sections. Body space: origin between the feet, +Y up, +Z toward the
 * front, +X toward the patient's LEFT (the body faces the viewer). Units: metres.
 *
 * Pure math — no Three.js dependency — so the same code drives geometry,
 * region mapping and tests.
 */

export const BodyPartId = {
  head: 'head', neck: 'neck', torso: 'torso',
  leftUpperArm: 'leftUpperArm', rightUpperArm: 'rightUpperArm',
  leftLowerArm: 'leftLowerArm', rightLowerArm: 'rightLowerArm',
  leftHand: 'leftHand', rightHand: 'rightHand',
  leftUpperLeg: 'leftUpperLeg', rightUpperLeg: 'rightUpperLeg',
  leftLowerLeg: 'leftLowerLeg', rightLowerLeg: 'rightLowerLeg',
  leftFoot: 'leftFoot', rightFoot: 'rightFoot',
} as const

export type Vec3 = [number, number, number]

export interface LoftSection {
  y: number
  centerX: number
  centerZ: number
  radiusX: number
  radiusZ: number
}

export interface LoftMesh {
  positions: Float32Array
  normals: Float32Array
  indices: Uint32Array
  /** Number of ring vertices (sections × segments); the two cap centres follow. */
  ringVertexCount: number
}

export class BodyPart {
  constructor(
    readonly id: string,
    readonly sections: LoftSection[],
    readonly segments: number = 40,
  ) {}

  get minY(): number { return this.sections[0].y }
  get maxY(): number { return this.sections[this.sections.length - 1].y }

  sectionAt(y: number): LoftSection {
    const s = this.sections
    if (y <= s[0].y) return s[0]
    if (y >= s[s.length - 1].y) return s[s.length - 1]
    for (let i = 1; i < s.length; i++) {
      if (y <= s[i].y) {
        const a = s[i - 1], b = s[i]
        const t = b.y - a.y > 0 ? (y - a.y) / (b.y - a.y) : 0
        return {
          y,
          centerX: a.centerX + (b.centerX - a.centerX) * t,
          centerZ: a.centerZ + (b.centerZ - a.centerZ) * t,
          radiusX: a.radiusX + (b.radiusX - a.radiusX) * t,
          radiusZ: a.radiusZ + (b.radiusZ - a.radiusZ) * t,
        }
      }
    }
    return s[s.length - 1]
  }

  /** Normalized height (0..1) and geometric angle in degrees (0 front, +90 patient's left). */
  surfaceParameters(p: Vec3): { height: number; angleDegrees: number } {
    const span = Math.max(this.maxY - this.minY, 1e-4)
    const height = (p[1] - this.minY) / span
    const s = this.sectionAt(p[1])
    const angleDegrees = (Math.atan2(p[0] - s.centerX, p[2] - s.centerZ) * 180) / Math.PI
    return { height, angleDegrees }
  }

  /** Exact inverse of `surfaceParameters` (accounts for elliptical sections). */
  surfacePoint(height: number, angleDegrees: number): { position: Vec3; normal: Vec3 } {
    const y = this.minY + (this.maxY - this.minY) * Math.min(Math.max(height, 0), 1)
    const s = this.sectionAt(y)
    const phi = (angleDegrees * Math.PI) / 180
    const rx = Math.max(s.radiusX, 1e-4), rz = Math.max(s.radiusZ, 1e-4)
    const theta = Math.atan2(rz * Math.sin(phi), rx * Math.cos(phi))
    const position: Vec3 = [s.centerX + rx * Math.sin(theta), y, s.centerZ + rz * Math.cos(theta)]
    const n: Vec3 = [Math.sin(theta) / rx, 0, Math.cos(theta) / rz]
    const len = Math.hypot(n[0], n[1], n[2])
    return { position, normal: [n[0] / len, n[1] / len, n[2] / len] }
  }
}

export function buildLoftMesh(part: BodyPart): LoftMesh {
  const m = part.segments
  const secs = part.sections
  const ringVertexCount = secs.length * m
  const vertexCount = ringVertexCount + 2
  const positions = new Float32Array(vertexCount * 3)
  let v = 0
  for (const s of secs) {
    for (let j = 0; j < m; j++) {
      const th = (j / m) * 2 * Math.PI
      positions[v++] = s.centerX + s.radiusX * Math.sin(th)
      positions[v++] = s.y
      positions[v++] = s.centerZ + s.radiusZ * Math.cos(th)
    }
  }
  const bottom = secs[0], top = secs[secs.length - 1]
  const bottomCenter = ringVertexCount, topCenter = ringVertexCount + 1
  positions.set([bottom.centerX, bottom.y, bottom.centerZ], bottomCenter * 3)
  positions.set([top.centerX, top.y, top.centerZ], topCenter * 3)

  const idx: number[] = []
  for (let si = 0; si < secs.length - 1; si++) {
    for (let j = 0; j < m; j++) {
      const jn = (j + 1) % m
      const a = si * m + j, b = si * m + jn, c = (si + 1) * m + j, d = (si + 1) * m + jn
      // Counter-clockwise when viewed from outside.
      idx.push(a, b, c, b, d, c)
    }
  }
  const base = (secs.length - 1) * m
  for (let j = 0; j < m; j++) {
    const jn = (j + 1) % m
    idx.push(bottomCenter, jn, j)
    idx.push(topCenter, base + j, base + jn)
  }
  const indices = Uint32Array.from(idx)

  const normals = new Float32Array(vertexCount * 3)
  for (let i = 0; i + 2 < indices.length; i += 3) {
    const ia = indices[i] * 3, ib = indices[i + 1] * 3, ic = indices[i + 2] * 3
    const abx = positions[ib] - positions[ia], aby = positions[ib + 1] - positions[ia + 1], abz = positions[ib + 2] - positions[ia + 2]
    const acx = positions[ic] - positions[ia], acy = positions[ic + 1] - positions[ia + 1], acz = positions[ic + 2] - positions[ia + 2]
    const nx = aby * acz - abz * acy, ny = abz * acx - abx * acz, nz = abx * acy - aby * acx
    for (const k of [ia, ib, ic]) { normals[k] += nx; normals[k + 1] += ny; normals[k + 2] += nz }
  }
  for (let i = 0; i < vertexCount; i++) {
    const o = i * 3
    const l = Math.hypot(normals[o], normals[o + 1], normals[o + 2])
    if (l > 0) { normals[o] /= l; normals[o + 1] /= l; normals[o + 2] /= l } else normals[o + 1] = 1
  }
  return { positions, normals, indices, ringVertexCount }
}

export class HumanBodyModel {
  constructor(readonly parts: BodyPart[], readonly selectablePartIds: ReadonlySet<string>) {}

  get height(): number { return Math.max(...this.parts.map((p) => p.maxY)) }

  part(id: string): BodyPart | undefined {
    return this.parts.find((p) => p.id === id)
  }

  surfaceLocation(partId: string, height: number, angleDegrees: number): SurfaceLocation | undefined {
    const part = this.part(partId)
    if (!part) return undefined
    const { position: [x, y, z], normal: [nx, ny, nz] } = part.surfacePoint(height, angleDegrees)
    return { meshId: partId, x, y, z, nx, ny, nz }
  }
}

// ---------------------------------------------------------------------------
// Default proportions (~1.75 m adult, neutral build).

function sec(y: number, centerX: number, centerZ: number, radiusX: number, radiusZ: number): LoftSection {
  return { y, centerX, centerZ, radiusX, radiusZ }
}

const torso = new BodyPart(BodyPartId.torso, [
  sec(0.790, 0, 0.000, 0.120, 0.080),
  sec(0.815, 0, 0.000, 0.160, 0.105),
  sec(0.860, 0, 0.000, 0.175, 0.118),
  sec(0.920, 0, 0.000, 0.172, 0.115),
  sec(0.980, 0, 0.000, 0.158, 0.105),
  sec(1.060, 0, 0.000, 0.148, 0.100),
  sec(1.150, 0, 0.002, 0.160, 0.108),
  sec(1.250, 0, 0.006, 0.176, 0.120),
  sec(1.340, 0, 0.002, 0.186, 0.112),
  sec(1.410, 0, 0.000, 0.192, 0.100),
  sec(1.445, 0, 0.000, 0.160, 0.085),
  sec(1.470, 0, 0.000, 0.105, 0.070),
  sec(1.490, 0, 0.000, 0.062, 0.056),
], 56)

const neck = new BodyPart(BodyPartId.neck, [
  sec(1.470, 0, -0.005, 0.058, 0.055),
  sec(1.560, 0, -0.005, 0.052, 0.050),
], 32)

function head(): BodyPart {
  const cy = 1.665, ry = 0.118, rx = 0.083, rz = 0.098, n = 12
  const sections: LoftSection[] = []
  for (let i = 0; i <= n; i++) {
    const phi = -Math.PI / 2 + (Math.PI * i) / n
    const scale = Math.max(Math.cos(phi), 0.02)
    const chin = phi < 0 ? 0.92 + 0.08 * (1 + Math.sin(phi)) : 1
    sections.push(sec(cy + ry * Math.sin(phi), 0, 0, rx * scale * chin, rz * scale))
  }
  return new BodyPart(BodyPartId.head, sections, 40)
}

function radiusAt(t: number, radii: [number, number][]): number {
  if (t <= radii[0][0]) return radii[0][1]
  const last = radii[radii.length - 1]
  if (t >= last[0]) return last[1]
  for (let i = 1; i < radii.length; i++) {
    if (t <= radii[i][0]) {
      const [ta, ra] = radii[i - 1], [tb, rb] = radii[i]
      return ra + (rb - ra) * ((t - ta) / Math.max(tb - ta, 1e-4))
    }
  }
  return last[1]
}

/** Tapered limb between two points with rounded ends. */
function limb(
  id: string, top: [number, number], bottom: [number, number],
  radii: [number, number][], opts: { z?: number; flattenZ?: number; segments?: number } = {},
): BodyPart {
  const { z = 0, flattenZ = 1, segments = 32 } = opts
  const steps = 14
  const sections: LoftSection[] = []
  for (let i = 0; i <= steps; i++) {
    const t = i / steps
    const x = bottom[0] + (top[0] - bottom[0]) * t
    const y = bottom[1] + (top[1] - bottom[1]) * t
    let r = radiusAt(t, radii)
    const edge = 0.08
    if (t < edge) r *= Math.sqrt(Math.max(0, 1 - ((edge - t) / edge) ** 2)) + 0.02
    if (t > 1 - edge) r *= Math.sqrt(Math.max(0, 1 - ((t - (1 - edge)) / edge) ** 2)) + 0.02
    sections.push(sec(y, x, z, r, r * flattenZ))
  }
  return new BodyPart(id, sections, segments)
}

function sideParts(side: BodySide): BodyPart[] {
  const sx = side === 'left' ? 1 : -1
  const L = side === 'left'
  return [
    limb(L ? BodyPartId.leftUpperArm : BodyPartId.rightUpperArm, [sx * 0.205, 1.425], [sx * 0.240, 1.120],
      [[0, 0.045], [0.3, 0.050], [0.75, 0.056], [1, 0.062]]),
    limb(L ? BodyPartId.leftLowerArm : BodyPartId.rightLowerArm, [sx * 0.242, 1.130], [sx * 0.268, 0.850],
      [[0, 0.032], [0.4, 0.040], [1, 0.048]]),
    limb(L ? BodyPartId.leftHand : BodyPartId.rightHand, [sx * 0.270, 0.855], [sx * 0.282, 0.680],
      [[0, 0.030], [0.5, 0.045], [1, 0.036]], { flattenZ: 0.45, segments: 24 }),
    limb(L ? BodyPartId.leftUpperLeg : BodyPartId.rightUpperLeg, [sx * 0.092, 0.880], [sx * 0.100, 0.470],
      [[0, 0.062], [0.15, 0.068], [0.6, 0.082], [1, 0.092]]),
    limb(L ? BodyPartId.leftLowerLeg : BodyPartId.rightLowerLeg, [sx * 0.100, 0.480], [sx * 0.100, 0.060],
      [[0, 0.038], [0.25, 0.048], [0.7, 0.062], [1, 0.058]], { z: -0.005 }),
    new BodyPart(L ? BodyPartId.leftFoot : BodyPartId.rightFoot, [
      sec(0.000, sx * 0.100, 0.045, 0.040, 0.115),
      sec(0.020, sx * 0.100, 0.045, 0.046, 0.125),
      sec(0.055, sx * 0.100, 0.025, 0.044, 0.095),
      sec(0.085, sx * 0.100, -0.005, 0.040, 0.060),
    ], 28),
  ]
}

export const standardBody = new HumanBodyModel(
  [torso, neck, head(), ...sideParts('left'), ...sideParts('right')],
  new Set([BodyPartId.torso, BodyPartId.leftUpperArm, BodyPartId.rightUpperArm, BodyPartId.leftUpperLeg, BodyPartId.rightUpperLeg]),
)
