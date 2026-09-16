import type { Placement, TrackerSettings } from '../models'
import type { PlacementRepository } from './PlacementRepository'

const PLACEMENTS_KEY = 'neupro.placements.v1'
const SETTINGS_KEY = 'neupro.settings.v1'

export interface KeyValueStore {
  getItem(key: string): string | null
  setItem(key: string, value: string): void
  removeItem(key: string): void
}

export class MemoryStore implements KeyValueStore {
  private map = new Map<string, string>()
  getItem(k: string) { return this.map.get(k) ?? null }
  setItem(k: string, v: string) { this.map.set(k, v) }
  removeItem(k: string) { this.map.delete(k) }
}

/** localStorage-backed repository (swap `store` for IndexedDB/remote later). */
export class LocalPlacementRepository implements PlacementRepository {
  constructor(private readonly store: KeyValueStore = globalThis.localStorage) {}

  private read(): Placement[] {
    const raw = this.store.getItem(PLACEMENTS_KEY)
    if (!raw) return []
    try {
      const parsed: unknown = JSON.parse(raw)
      return Array.isArray(parsed) ? (parsed as Placement[]) : []
    } catch {
      return []
    }
  }

  private write(list: Placement[]) {
    this.store.setItem(PLACEMENTS_KEY, JSON.stringify(list))
  }

  async getPlacements(): Promise<Placement[]> {
    return this.read().sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : 0))
  }

  async savePlacement(p: Placement): Promise<void> {
    this.write([...this.read().filter((x) => x.id !== p.id), p])
  }

  async updatePlacement(p: Placement): Promise<void> {
    return this.savePlacement(p)
  }

  async deletePlacement(id: string): Promise<void> {
    this.write(this.read().filter((x) => x.id !== id))
  }

  async clearHistory(): Promise<void> {
    this.store.removeItem(PLACEMENTS_KEY)
  }

  async getSettings(): Promise<TrackerSettings | undefined> {
    const raw = this.store.getItem(SETTINGS_KEY)
    if (!raw) return undefined
    try { return JSON.parse(raw) as TrackerSettings } catch { return undefined }
  }

  async saveSettings(s: TrackerSettings): Promise<void> {
    this.store.setItem(SETTINGS_KEY, JSON.stringify(s))
  }
}
