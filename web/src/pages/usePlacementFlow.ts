import { useCallback, useMemo, useState } from 'react'
import type { AppStore } from '../app/store'
import type { BodyTapResult } from '../components/body/BodyViewer'
import { OUTSIDE_APPROVED_REGION } from '../domain/placementRules'
import { reasonText, recommendationText, type Placement, type PlacementCandidate, type Region, type SurfaceLocation, type ValidationResult } from '../models'

export type Feedback =
  | { kind: 'none' }
  | { kind: 'blocked'; title: string; message: string }
  | { kind: 'recommendation'; title: string; message: string }
  | { kind: 'ready'; regionName: string; side: Placement['side'] }

export interface PlacementFlow {
  editingId?: string
  candidate?: PlacementCandidate
  preview?: { location: SurfaceLocation; blocked: boolean }
  validation?: ValidationResult
  feedback: Feedback
  inspected?: Placement
  history: Placement[]
  canConfirm: boolean
  handleTap: (r: BodyTapResult) => void
  select: (loc: SurfaceLocation) => void
  selectRegionCenter: (region: Region) => void
  clear: () => void
  dismissInspection: () => void
  confirm: () => Promise<Placement>
}

/** Non-UI placement state machine: tap → map region → validate → preview → confirm. */
export function usePlacementFlow(app: AppStore, editing?: Placement): PlacementFlow {
  const [candidate, setCandidate] = useState<PlacementCandidate>()
  const [validation, setValidation] = useState<ValidationResult>()
  const [preview, setPreview] = useState<{ location: SurfaceLocation; blocked: boolean }>()
  const [inspected, setInspected] = useState<Placement>()

  const editingId = editing?.id
  const history = useMemo(() => app.placements.filter((p) => p.id !== editingId), [app.placements, editingId])

  const select = useCallback((location: SurfaceLocation) => {
    setInspected(undefined)
    const region = app.mapper.regionFor(location)
    if (!region) {
      setCandidate(undefined)
      setValidation(OUTSIDE_APPROVED_REGION)
      setPreview({ location, blocked: true })
      return
    }
    const c = { region, surfaceLocation: location }
    const v = app.validate(c, editingId)
    setCandidate(c)
    setValidation(v)
    setPreview({ location, blocked: !v.valid })
  }, [app, editingId])

  const handleTap = useCallback((r: BodyTapResult) => {
    if (r.kind === 'surface') select(r.location)
    else if (r.kind === 'marker') setInspected(app.placements.find((p) => p.id === r.placementId))
  }, [select, app.placements])

  const selectRegionCenter = useCallback((region: Region) => {
    const loc = app.mapper.regionCenter(region)
    if (loc) select(loc)
  }, [app.mapper, select])

  const clear = useCallback(() => {
    setCandidate(undefined); setValidation(undefined); setPreview(undefined)
  }, [])

  const confirm = useCallback(async () => {
    if (!candidate) throw new Error('Nothing selected')
    return app.confirm(candidate, editingId)
  }, [app, candidate, editingId])

  const feedback = useMemo<Feedback>(() => {
    if (!validation) return { kind: 'none' }
    if (validation.blockingReasons.length > 0) {
      const t = reasonText(validation.blockingReasons[0])
      return { kind: 'blocked', ...t }
    }
    if (validation.recommendations.length > 0) {
      const t = recommendationText(validation.recommendations[0])
      return { kind: 'recommendation', ...t }
    }
    if (candidate) return { kind: 'ready', regionName: candidate.region.name, side: candidate.region.side }
    return { kind: 'none' }
  }, [validation, candidate])

  return {
    editingId, candidate, preview, validation, feedback, inspected, history,
    canConfirm: !!candidate && !!validation?.valid,
    handleTap, select, selectRegionCenter, clear, dismissInspection: () => setInspected(undefined), confirm,
  }
}
