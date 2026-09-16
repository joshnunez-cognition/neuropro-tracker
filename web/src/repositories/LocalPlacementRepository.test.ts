import { describe, expect, it } from 'vitest'
import { standardBody } from '../body/humanBodyModel'
import { demoPlacements } from '../data/demoPlacements'
import { LocalPlacementRepository, MemoryStore } from './LocalPlacementRepository'

describe('LocalPlacementRepository', () => {
  it('persists placements and settings across instances sharing a store', async () => {
    const store = new MemoryStore()
    const repo = new LocalPlacementRepository(store)
    const [p] = demoPlacements('2026-03-20')
    await repo.savePlacement(p)
    await repo.saveSettings({ cycleStartDate: '2026-03-15', sideRecommendationEnabled: false, reminderEnabled: false, reminderTime: '08:00', onboardingComplete: true })

    const reloaded = new LocalPlacementRepository(store)
    const list = await reloaded.getPlacements()
    expect(list).toHaveLength(1)
    expect(list[0].surfaceLocation).toEqual(p.surfaceLocation)
    expect((await reloaded.getSettings())?.sideRecommendationEnabled).toBe(false)
  })

  it('updates, deletes and clears', async () => {
    const repo = new LocalPlacementRepository(new MemoryStore())
    const all = demoPlacements('2026-03-20')
    for (const p of all) await repo.savePlacement(p)
    expect(await repo.getPlacements()).toHaveLength(5)
    await repo.updatePlacement({ ...all[0], regionName: 'Edited' })
    expect((await repo.getPlacements()).find((p) => p.id === all[0].id)?.regionName).toBe('Edited')
    await repo.deletePlacement(all[1].id)
    expect(await repo.getPlacements()).toHaveLength(4)
    await repo.clearHistory()
    expect(await repo.getPlacements()).toEqual([])
  })

  it('survives malformed storage', async () => {
    const store = new MemoryStore()
    store.setItem('neupro.placements.v1', '{not json')
    expect(await new LocalPlacementRepository(store).getPlacements()).toEqual([])
  })

  it('reconstructs a stored location at the same surface parameters', () => {
    const loc = standardBody.surfaceLocation('torso', 0.42, -35)!
    const roundTrip = JSON.parse(JSON.stringify(loc)) as typeof loc
    const part = standardBody.part('torso')!
    const params = part.surfaceParameters([roundTrip.x, roundTrip.y, roundTrip.z])
    expect(params.height).toBeCloseTo(0.42, 3)
    expect(params.angleDegrees).toBeCloseTo(-35, 2)
  })
})
