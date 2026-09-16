import type { Placement, TrackerSettings } from '../models'

export interface PlacementRepository {
  getPlacements(): Promise<Placement[]>
  savePlacement(placement: Placement): Promise<void>
  updatePlacement(placement: Placement): Promise<void>
  deletePlacement(id: string): Promise<void>
  clearHistory(): Promise<void>
  getSettings(): Promise<TrackerSettings | undefined>
  saveSettings(settings: TrackerSettings): Promise<void>
}
