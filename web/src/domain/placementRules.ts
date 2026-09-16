import type {
  Placement, PlacementCandidate, PlacementRules, Recommendation, SurfaceLocation,
  ValidationReason, ValidationResult,
} from '../models'
import { defaultRules } from './config'
import { daysBetween, type DayString } from './dates'
import { isWithinExclusionRadius } from './distance'
import { getRecommendedSide } from './recommendations'

/**
 * Placement rules.
 *
 * HARD BLOCKS: exact location reused within the rotation window; broader region
 * used yesterday. SOFT RECOMMENDATION: alternate sides relative to yesterday.
 */

export const OUTSIDE_APPROVED_REGION: ValidationResult = {
  valid: false,
  blockingReasons: [{ code: 'outside_approved_region' }],
  recommendations: [],
}

export function getRecentPlacements(history: Placement[], date: DayString, rules = defaultRules): Placement[] {
  return history.filter((p) => {
    const d = daysBetween(p.date, date)
    return d >= 0 && d <= rules.rotationWindowDays
  })
}

export function findRecentPlacementNear(
  location: SurfaceLocation, history: Placement[], date: DayString, rules = defaultRules,
): Placement | undefined {
  return getRecentPlacements(history, date, rules)
    .filter((p) => p.surfaceLocation.meshId === location.meshId &&
      isWithinExclusionRadius(p.surfaceLocation, location, rules.exclusionRadius))
    .sort((a, b) => daysBetween(a.date, date) - daysBetween(b.date, date))[0]
}

export function wasLocationUsedWithin14Days(
  location: SurfaceLocation, history: Placement[], date: DayString, rules = defaultRules,
): boolean {
  return findRecentPlacementNear(location, history, date, rules) !== undefined
}

export function findYesterdayRegionPlacement(regionId: string, history: Placement[], date: DayString): Placement | undefined {
  return history.find((p) => daysBetween(p.date, date) === 1 && p.regionId === regionId)
}

export function wasRegionUsedYesterday(regionId: string, history: Placement[], date: DayString): boolean {
  return findYesterdayRegionPlacement(regionId, history, date) !== undefined
}

export function validatePlacement(
  candidate: PlacementCandidate,
  history: Placement[],
  date: DayString,
  options: { rules?: PlacementRules; excludeId?: string } = {},
): ValidationResult {
  const rules = options.rules ?? defaultRules
  const relevant = history.filter((p) => p.id !== options.excludeId)
  const blockingReasons: ValidationReason[] = []
  const recommendations: Recommendation[] = []

  const recent = findRecentPlacementNear(candidate.surfaceLocation, relevant, date, rules)
  if (recent) blockingReasons.push({ code: 'recently_used_location', daysAgo: daysBetween(recent.date, date) })

  const yesterday = findYesterdayRegionPlacement(candidate.region.id, relevant, date)
  if (yesterday) blockingReasons.push({ code: 'region_used_yesterday', regionName: yesterday.regionName })

  if (rules.sideRecommendationEnabled) {
    const preferred = getRecommendedSide(relevant, date)
    if (preferred && preferred !== candidate.region.side) recommendations.push({ code: 'alternate_side', preferred })
  }

  return { valid: blockingReasons.length === 0, blockingReasons, recommendations }
}
