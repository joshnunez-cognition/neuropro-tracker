import { describe, expect, it } from 'vitest'
import { standardBody } from '../body/humanBodyModel'
import { regionMapper } from '../body/regionMapping'
import { regionById } from '../data/bodyRegions'
import type { Placement, SurfaceLocation } from '../models'
import { CycleManager } from './cycle'
import { addDays } from './dates'
import { calculatePlacementDistance, isWithinExclusionRadius } from './distance'
import { validatePlacement } from './placementRules'
import { getRecommendedSide, getRegionAvailability } from './recommendations'
import { bodyRegions } from '../data/bodyRegions'

const TODAY = '2026-03-20'
const cycle = new CycleManager('2026-03-15')

function loc(regionId: string, height: number, angle: number): SurfaceLocation {
  const region = regionById(regionId)!
  return standardBody.surfaceLocation(region.surfaceDefinition.patches[0].meshId, height, angle)!
}

function placement(regionId: string, daysAgo: number, location: SurfaceLocation): Placement {
  const region = regionById(regionId)!
  const date = addDays(TODAY, -daysAgo)
  return {
    id: `${regionId}-${daysAgo}`, date, timestamp: `${date}T08:00:00.000Z`,
    cycleId: cycle.cycleId(date), cycleDay: cycle.cycleDay(date),
    regionId, regionName: region.name, side: region.side, surfaceLocation: location,
  }
}

function candidate(regionId: string, height: number, angle: number) {
  const l = loc(regionId, height, angle)
  const region = regionMapper.regionFor(l)
  expect(region?.id).toBe(regionId)
  return { region: region!, surfaceLocation: l }
}

describe('validatePlacement', () => {
  it('allows a fresh location with empty history', () => {
    const r = validatePlacement(candidate('left_thigh', 0.7, 0), [], TODAY)
    expect(r.valid).toBe(true)
    expect(r.recommendations).toEqual([])
  })

  it('blocks the same exact location used within 14 days', () => {
    const l = loc('right_thigh', 0.7, 0)
    const r = validatePlacement(candidate('right_thigh', 0.7, 0), [placement('right_thigh', 10, l)], TODAY)
    expect(r.valid).toBe(false)
    expect(r.blockingReasons[0]).toEqual({ code: 'recently_used_location', daysAgo: 10 })
  })

  it('blocks exactly at the exclusion radius, allows just beyond', () => {
    const a = { ...loc('right_thigh', 0.7, 0), x: 0, y: 0.5, z: 0 }
    const b = { ...a, y: 0.55 }
    const c = { ...a, y: 0.5501 }
    expect(isWithinExclusionRadius(a, b, 0.05)).toBe(true)
    expect(isWithinExclusionRadius(a, c, 0.05)).toBe(false)
    expect(calculatePlacementDistance(a, b)).toBeCloseTo(0.05)
  })

  it('allows a location used more than 14 days ago', () => {
    const l = loc('right_thigh', 0.7, 0)
    const r = validatePlacement(candidate('right_thigh', 0.7, 0), [placement('right_thigh', 15, l)], TODAY)
    expect(r.valid).toBe(true)
  })

  it("blocks a different spot in yesterday's region", () => {
    const history = [placement('left_thigh', 1, loc('left_thigh', 0.6, 20))]
    const r = validatePlacement(candidate('left_thigh', 0.85, -20), history, TODAY)
    expect(r.valid).toBe(false)
    expect(r.blockingReasons).toEqual([{ code: 'region_used_yesterday', regionName: 'Left thigh' }])
  })

  it('recommends the opposite side but allows same side different region', () => {
    const history = [placement('left_thigh', 1, loc('left_thigh', 0.6, 20))]
    const r = validatePlacement(candidate('left_upper_arm', 0.6, 60), history, TODAY)
    expect(r.valid).toBe(true)
    expect(r.recommendations).toEqual([{ code: 'alternate_side', preferred: 'right' }])
    expect(getRecommendedSide(history, TODAY)).toBe('right')
  })

  it('allows the opposite side with no recommendation', () => {
    const history = [placement('left_thigh', 1, loc('left_thigh', 0.6, 20))]
    const r = validatePlacement(candidate('right_abdomen', 0.4, -40), history, TODAY)
    expect(r.valid).toBe(true)
    expect(r.recommendations).toEqual([])
  })

  it('ignores the placement being edited', () => {
    const l = loc('right_thigh', 0.7, 0)
    const existing = { ...placement('right_thigh', 0, l), id: 'today' }
    expect(validatePlacement(candidate('right_thigh', 0.7, 0), [existing], TODAY).valid).toBe(false)
    expect(validatePlacement(candidate('right_thigh', 0.7, 0), [existing], TODAY, { excludeId: 'today' }).valid).toBe(true)
  })

  it('maps the torso centre and head as outside approved regions', () => {
    expect(regionMapper.regionFor(standardBody.surfaceLocation('torso', 0.4, 0)!)).toBeUndefined()
    expect(regionMapper.regionFor(standardBody.surfaceLocation('head', 0.5, 0)!)).toBeUndefined()
  })

  it('computes region availability', () => {
    const history = [placement('left_thigh', 1, loc('left_thigh', 0.6, 20))]
    const a = getRegionAvailability(bodyRegions, history, TODAY)
    expect(a.left_thigh).toBe('unavailable')
    expect(a.right_thigh).toBe('recommended')
    expect(a.left_upper_arm).toBe('available')
  })
})
