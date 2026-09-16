export type BodySide = 'left' | 'right'

export function oppositeSide(side: BodySide): BodySide {
  return side === 'left' ? 'right' : 'left'
}

export function sideLabel(side: BodySide): string {
  return side === 'left' ? 'Left' : 'Right'
}

/** Body-space point + outward normal on a named mesh (metres, ~1.75 m body). */
export interface SurfaceLocation {
  meshId: string
  x: number
  y: number
  z: number
  nx: number
  ny: number
  nz: number
}

/**
 * A rectangular patch of a body part's surface in the part's cylindrical
 * parameter space: normalized height (0 bottom..1 top) and angle in degrees
 * (0 front, +90 patient's left, ±180 back, -90 patient's right).
 */
export interface SurfacePatch {
  meshId: string
  heightRange: [number, number]
  angleRange: [number, number]
}

export function patchContains(p: SurfacePatch, height: number, angle: number): boolean {
  return (
    height >= p.heightRange[0] && height <= p.heightRange[1] &&
    angle >= p.angleRange[0] && angle <= p.angleRange[1]
  )
}

export interface Region {
  id: string
  name: string
  side: BodySide
  surfaceDefinition: { patches: SurfacePatch[] }
}

export type RegionAvailability = 'available' | 'recommended' | 'unavailable' | 'selected'

export const availabilityLabel: Record<RegionAvailability, string> = {
  available: 'Available',
  recommended: 'Recommended',
  unavailable: 'Used yesterday',
  selected: 'Selected',
}

export interface Placement {
  id: string
  /** Calendar day, YYYY-MM-DD (local). */
  date: string
  /** ISO timestamp of when it was logged. */
  timestamp: string
  cycleId: string
  cycleDay: number
  regionId: string
  regionName: string
  side: BodySide
  surfaceLocation: SurfaceLocation
}

export interface PlacementCandidate {
  region: Region
  surfaceLocation: SurfaceLocation
}

export type ValidationReason =
  | { code: 'outside_approved_region' }
  | { code: 'recently_used_location'; daysAgo: number }
  | { code: 'region_used_yesterday'; regionName: string }

export type Recommendation = { code: 'alternate_side'; preferred: BodySide }

export interface ValidationResult {
  valid: boolean
  blockingReasons: ValidationReason[]
  recommendations: Recommendation[]
}

export function reasonText(r: ValidationReason): { title: string; message: string } {
  switch (r.code) {
    case 'outside_approved_region':
      return { title: 'Not a placement area', message: 'Tap one of the highlighted areas to place your patch.' }
    case 'recently_used_location':
      return { title: 'Recently used spot', message: 'You recently used this spot. Choose another location.' }
    case 'region_used_yesterday':
      return { title: 'Choose another area', message: 'You used this area yesterday. Choose a different area today.' }
  }
}

export function recommendationText(r: Recommendation): { title: string; message: string } {
  switch (r.code) {
    case 'alternate_side':
      return {
        title: 'Rotation suggestion',
        message: `Consider using your ${r.preferred} side today — the opposite side from yesterday — to help rotate your patch locations.`,
      }
  }
}

export interface PlacementRules {
  rotationWindowDays: number
  exclusionRadius: number
  sideRecommendationEnabled: boolean
}

export interface TrackerSettings {
  /** YYYY-MM-DD */
  cycleStartDate: string
  sideRecommendationEnabled: boolean
  reminderEnabled: boolean
  /** HH:MM */
  reminderTime: string
  onboardingComplete: boolean
}
