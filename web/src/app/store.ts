import { useCallback, useEffect, useMemo, useState } from 'react'
import { standardBody } from '../body/humanBodyModel'
import { regionMapper } from '../body/regionMapping'
import { bodyRegions } from '../data/bodyRegions'
import { DEMO_CYCLE_START_DAYS_AGO, demoPlacements } from '../data/demoPlacements'
import { defaultRules } from '../domain/config'
import { CycleManager } from '../domain/cycle'
import { addDays, today as todayString, type DayString } from '../domain/dates'
import { validatePlacement } from '../domain/placementRules'
import { getRegionAvailability, getRecommendedSide, getYesterdayPlacement } from '../domain/recommendations'
import type { Placement, PlacementCandidate, PlacementRules, TrackerSettings, ValidationResult } from '../models'
import type { PlacementRepository } from '../repositories/PlacementRepository'

export function defaultSettings(today: DayString): TrackerSettings {
  return {
    cycleStartDate: today,
    sideRecommendationEnabled: true,
    reminderEnabled: false,
    reminderTime: '08:00',
    onboardingComplete: false,
  }
}

export interface AppStore {
  ready: boolean
  today: DayString
  placements: Placement[]
  settings: TrackerSettings
  rules: PlacementRules
  cycle: CycleManager
  todayPlacement: Placement | undefined
  yesterdayPlacement: Placement | undefined
  recommendedSide: ReturnType<typeof getRecommendedSide>
  regionAvailability: (excludeId?: string) => Record<string, import('../models').RegionAvailability>
  validate: (candidate: PlacementCandidate, excludeId?: string) => ValidationResult
  confirm: (candidate: PlacementCandidate, replacingId?: string) => Promise<Placement>
  deletePlacement: (id: string) => Promise<void>
  clearHistory: () => Promise<void>
  loadDemoData: () => Promise<void>
  updateSettings: (patch: Partial<TrackerSettings>) => Promise<void>
  model: typeof standardBody
  mapper: typeof regionMapper
}

export function useAppStore(repository: PlacementRepository, options: { demo?: boolean } = {}): AppStore {
  const [ready, setReady] = useState(false)
  const [today, setToday] = useState(todayString)
  const [placements, setPlacements] = useState<Placement[]>([])
  const [settings, setSettings] = useState<TrackerSettings>(() => defaultSettings(todayString()))

  useEffect(() => {
    let cancelled = false
    ;(async () => {
      const [list, saved] = await Promise.all([repository.getPlacements(), repository.getSettings()])
      if (cancelled) return
      let s = saved ?? defaultSettings(todayString())
      let l = list
      if (options.demo) {
        s = { ...s, cycleStartDate: addDays(todayString(), -DEMO_CYCLE_START_DAYS_AGO) }
        l = demoPlacements(todayString())
        await repository.clearHistory()
        for (const p of l) await repository.savePlacement(p)
        await repository.saveSettings(s)
      }
      setSettings(s)
      setPlacements(l)
      setReady(true)
    })()
    return () => { cancelled = true }
  }, [repository, options.demo])

  // Roll "today" over at midnight or when returning to the tab.
  useEffect(() => {
    const tick = () => setToday(todayString())
    const id = setInterval(tick, 60_000)
    document.addEventListener('visibilitychange', tick)
    return () => { clearInterval(id); document.removeEventListener('visibilitychange', tick) }
  }, [])

  const rules = useMemo<PlacementRules>(
    () => ({ ...defaultRules, sideRecommendationEnabled: settings.sideRecommendationEnabled }),
    [settings.sideRecommendationEnabled],
  )
  const cycle = useMemo(() => new CycleManager(settings.cycleStartDate), [settings.cycleStartDate])

  const todayPlacement = useMemo(() => placements.find((p) => p.date === today), [placements, today])
  const yesterdayPlacement = useMemo(() => getYesterdayPlacement(placements, today), [placements, today])
  const recommendedSide = useMemo(
    () => (settings.sideRecommendationEnabled ? getRecommendedSide(placements, today) : undefined),
    [placements, today, settings.sideRecommendationEnabled],
  )

  const regionAvailability = useCallback(
    (excludeId?: string) => getRegionAvailability(bodyRegions, placements, today, {
      excludeId, sideRecommendationEnabled: settings.sideRecommendationEnabled,
    }),
    [placements, today, settings.sideRecommendationEnabled],
  )

  const validate = useCallback(
    (candidate: PlacementCandidate, excludeId?: string) => validatePlacement(candidate, placements, today, { rules, excludeId }),
    [placements, today, rules],
  )

  const confirm = useCallback(async (candidate: PlacementCandidate, replacingId?: string) => {
    const result = validatePlacement(candidate, placements, today, { rules, excludeId: replacingId })
    if (!result.valid) throw new Error('Placement is not valid')
    const placement: Placement = {
      id: replacingId ?? crypto.randomUUID(),
      date: today,
      timestamp: new Date().toISOString(),
      cycleId: cycle.cycleId(today),
      cycleDay: cycle.cycleDay(today),
      regionId: candidate.region.id,
      regionName: candidate.region.name,
      side: candidate.region.side,
      surfaceLocation: candidate.surfaceLocation,
    }
    if (replacingId) await repository.updatePlacement(placement)
    else await repository.savePlacement(placement)
    setPlacements(await repository.getPlacements())
    return placement
  }, [placements, today, rules, cycle, repository])

  const deletePlacement = useCallback(async (id: string) => {
    await repository.deletePlacement(id)
    setPlacements(await repository.getPlacements())
  }, [repository])

  const clearHistory = useCallback(async () => {
    await repository.clearHistory()
    setPlacements([])
  }, [repository])

  const loadDemoData = useCallback(async () => {
    const t = todayString()
    const s = { ...settings, cycleStartDate: addDays(t, -DEMO_CYCLE_START_DAYS_AGO) }
    await repository.clearHistory()
    for (const p of demoPlacements(t)) await repository.savePlacement(p)
    await repository.saveSettings(s)
    setSettings(s)
    setPlacements(await repository.getPlacements())
  }, [repository, settings])

  const updateSettings = useCallback(async (patch: Partial<TrackerSettings>) => {
    const next = { ...settings, ...patch }
    await repository.saveSettings(next)
    setSettings(next)
  }, [repository, settings])

  return {
    ready, today, placements, settings, rules, cycle, todayPlacement, yesterdayPlacement, recommendedSide,
    regionAvailability, validate, confirm, deletePlacement, clearHistory, loadDemoData, updateSettings,
    model: standardBody, mapper: regionMapper,
  }
}
