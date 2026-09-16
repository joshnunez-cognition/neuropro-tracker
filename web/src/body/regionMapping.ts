import { patchContains, type Region, type SurfaceLocation } from '../models'
import { bodyRegions } from '../data/bodyRegions'
import { standardBody, type BodyPart, type HumanBodyModel, type LoftMesh } from './humanBodyModel'

/** Resolves surface locations to approved regions and classifies mesh triangles for overlays. */
export class RegionMapper {
  constructor(
    readonly model: HumanBodyModel = standardBody,
    readonly regions: Region[] = bodyRegions,
  ) {}

  regionFor(location: SurfaceLocation): Region | undefined {
    if (!this.model.selectablePartIds.has(location.meshId)) return undefined
    const part = this.model.part(location.meshId)
    if (!part) return undefined
    const { height, angleDegrees } = part.surfaceParameters([location.x, location.y, location.z])
    return this.regions.find((r) =>
      r.surfaceDefinition.patches.some((p) => p.meshId === location.meshId && patchContains(p, height, angleDegrees)),
    )
  }

  /** Index triples of `part`'s triangles whose vertices all lie inside `region`. */
  triangleIndices(region: Region, part: BodyPart, mesh: LoftMesh): Uint32Array {
    const patches = region.surfaceDefinition.patches.filter((p) => p.meshId === part.id)
    if (patches.length === 0) return new Uint32Array()
    const inside = new Uint8Array(mesh.positions.length / 3)
    for (let i = 0; i < mesh.ringVertexCount; i++) {
      const o = i * 3
      const { height, angleDegrees } = part.surfaceParameters([mesh.positions[o], mesh.positions[o + 1], mesh.positions[o + 2]])
      if (patches.some((p) => patchContains(p, height, angleDegrees))) inside[i] = 1
    }
    const out: number[] = []
    const idx = mesh.indices
    for (let i = 0; i + 2 < idx.length; i += 3) {
      if (inside[idx[i]] && inside[idx[i + 1]] && inside[idx[i + 2]]) out.push(idx[i], idx[i + 1], idx[i + 2])
    }
    return Uint32Array.from(out)
  }

  regionCenter(region: Region): SurfaceLocation | undefined {
    const p = region.surfaceDefinition.patches[0]
    if (!p) return undefined
    return this.model.surfaceLocation(
      p.meshId, (p.heightRange[0] + p.heightRange[1]) / 2, (p.angleRange[0] + p.angleRange[1]) / 2)
  }
}

export const regionMapper = new RegionMapper()
