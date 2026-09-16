import type { SurfaceLocation } from '../models'

/** Straight-line distance in body space (metres). */
export function calculatePlacementDistance(a: SurfaceLocation, b: SurfaceLocation): number {
  const dx = a.x - b.x, dy = a.y - b.y, dz = a.z - b.z
  return Math.sqrt(dx * dx + dy * dy + dz * dz)
}

export function isWithinExclusionRadius(a: SurfaceLocation, b: SurfaceLocation, radius: number): boolean {
  return calculatePlacementDistance(a, b) <= radius + EPSILON
}

/** Absorbs floating-point noise so a placement exactly on the radius is blocked. */
const EPSILON = 1e-9
