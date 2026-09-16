import { standardBody, type HumanBodyModel } from '../body/humanBodyModel'
import { CycleManager } from '../domain/cycle'
import { addDays, parseDay, type DayString } from '../domain/dates'
import type { Placement } from '../models'
import { regionById } from './bodyRegions'

/**
 * Seed placements for demonstrating the app. Today becomes Day 6 of the cycle.
 * Yesterday (Day 5) is the left upper arm, so today that region is blocked,
 * the right side is recommended and each earlier spot has an exclusion halo.
 */
const seeds: { daysAgo: number; regionId: string; height: number; angle: number }[] = [
  { daysAgo: 5, regionId: 'left_upper_arm', height: 0.75, angle: 60 },
  { daysAgo: 4, regionId: 'right_abdomen', height: 0.42, angle: -35 },
  { daysAgo: 3, regionId: 'left_thigh', height: 0.75, angle: 10 },
  { daysAgo: 2, regionId: 'right_hip', height: 0.15, angle: -140 },
  { daysAgo: 1, regionId: 'left_upper_arm', height: 0.45, angle: -20 },
]

export const DEMO_CYCLE_START_DAYS_AGO = 5

export function demoPlacements(today: DayString, model: HumanBodyModel = standardBody): Placement[] {
  const cycle = new CycleManager(addDays(today, -DEMO_CYCLE_START_DAYS_AGO))
  const out: Placement[] = []
  for (const s of seeds) {
    const region = regionById(s.regionId)
    const patch = region?.surfaceDefinition.patches[0]
    if (!region || !patch) continue
    const loc = model.surfaceLocation(patch.meshId, s.height, s.angle)
    if (!loc) continue
    const date = addDays(today, -s.daysAgo)
    const stamp = parseDay(date)
    stamp.setHours(8, 3, 0, 0)
    out.push({
      id: `demo-${s.daysAgo}`,
      date,
      timestamp: stamp.toISOString(),
      cycleId: cycle.cycleId(date),
      cycleDay: cycle.cycleDay(date),
      regionId: region.id,
      regionName: region.name,
      side: region.side,
      surfaceLocation: loc,
    })
  }
  return out
}
