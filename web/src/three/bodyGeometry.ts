import * as THREE from 'three'
import { buildLoftMesh, type BodyPart, type HumanBodyModel, type LoftMesh } from '../body/humanBodyModel'
import type { RegionMapper } from '../body/regionMapping'
import type { Region, SurfaceLocation } from '../models'

export interface PartGeometry {
  part: BodyPart
  mesh: LoftMesh
  geometry: THREE.BufferGeometry
}

/** Three.js geometry for every body part (cached per model). */
export function buildBodyGeometries(model: HumanBodyModel): PartGeometry[] {
  return model.parts.map((part) => {
    const mesh = buildLoftMesh(part)
    const geometry = new THREE.BufferGeometry()
    geometry.setAttribute('position', new THREE.BufferAttribute(mesh.positions, 3))
    geometry.setAttribute('normal', new THREE.BufferAttribute(mesh.normals, 3))
    geometry.setIndex(new THREE.BufferAttribute(mesh.indices, 1))
    return { part, mesh, geometry }
  })
}

/** Sub-geometry (shared vertex buffers, region-only indices) for an approved region. */
export function buildRegionGeometry(mapper: RegionMapper, region: Region, parts: PartGeometry[]): THREE.BufferGeometry | undefined {
  for (const pg of parts) {
    const idx = mapper.triangleIndices(region, pg.part, pg.mesh)
    if (idx.length === 0) continue
    const g = new THREE.BufferGeometry()
    g.setAttribute('position', pg.geometry.getAttribute('position'))
    g.setAttribute('normal', pg.geometry.getAttribute('normal'))
    g.setIndex(new THREE.BufferAttribute(idx, 1))
    return g
  }
  return undefined
}

/** Body-space yaw (radians) that brings `loc` to face the camera (+Z). */
export function yawFacing(loc: SurfaceLocation): number {
  return -Math.atan2(loc.x, loc.z)
}

export function normalQuaternion(loc: SurfaceLocation): THREE.Quaternion {
  return new THREE.Quaternion().setFromUnitVectors(
    new THREE.Vector3(0, 0, 1),
    new THREE.Vector3(loc.nx, loc.ny, loc.nz).normalize(),
  )
}
