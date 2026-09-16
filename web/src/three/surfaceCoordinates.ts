import * as THREE from 'three'
import type { SurfaceLocation } from '../models'

/**
 * Converts a Three.js intersection on a body-part mesh to a stable, body-space
 * `SurfaceLocation`. Parts sit at identity under the rotating body group, so
 * transforming into the group's local frame yields body-space coordinates that
 * survive reload and rotation.
 */
export function surfaceLocationFromIntersection(hit: THREE.Intersection, bodyGroup: THREE.Object3D): SurfaceLocation | undefined {
  const partId = hit.object.userData.partId as string | undefined
  if (!partId) return undefined
  const local = bodyGroup.worldToLocal(hit.point.clone())
  const n = hit.face?.normal.clone() ?? new THREE.Vector3(0, 0, 1)
  // Face normal is in the mesh's local space; meshes are at identity inside the group.
  n.normalize()
  return { meshId: partId, x: local.x, y: local.y, z: local.z, nx: n.x, ny: n.y, nz: n.z }
}
