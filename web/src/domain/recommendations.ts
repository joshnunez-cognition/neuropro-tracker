import { oppositeSide, type BodySide, type Placement, type Region, type RegionAvailability } from '../models'
import { daysBetween, type DayString } from './dates'

export function getYesterdayPlacement(history: Placement[], date: DayString): Placement | undefined {
  return history.find((p) => daysBetween(p.date, date) === 1)
}

/** Side opposite yesterday's placement, or undefined when there is no yesterday. */
export function getRecommendedSide(history: Placement[], date: DayString): BodySide | undefined {
  const y = getYesterdayPlacement(history, date)
  return y ? oppositeSide(y.side) : undefined
}

export function getRegionAvailability(
  regions: Region[],
  history: Placement[],
  date: DayString,
  options: { excludeId?: string; sideRecommendationEnabled?: boolean } = {},
): Record<string, RegionAvailability> {
  const relevant = history.filter((p) => p.id !== options.excludeId)
  const yesterday = getYesterdayPlacement(relevant, date)
  const preferred = (options.sideRecommendationEnabled ?? true) && yesterday ? oppositeSide(yesterday.side) : undefined
  const out: Record<string, RegionAvailability> = {}
  for (const r of regions) {
    if (yesterday && yesterday.regionId === r.id) out[r.id] = 'unavailable'
    else if (preferred && r.side === preferred) out[r.id] = 'recommended'
    else out[r.id] = 'available'
  }
  return out
}
