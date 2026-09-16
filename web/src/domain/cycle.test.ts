import { describe, expect, it } from 'vitest'
import { CycleManager } from './cycle'
import { addDays, daysBetween } from './dates'

describe('CycleManager', () => {
  const c = new CycleManager('2026-01-01')

  it('maps day 1 and day 14', () => {
    expect(c.cycleDay('2026-01-01')).toBe(1)
    expect(c.cycleDay('2026-01-14')).toBe(14)
    expect(c.cycleNumber('2026-01-14')).toBe(1)
  })

  it('rolls from day 14 to the next cycle day 1', () => {
    expect(c.cycleDay('2026-01-15')).toBe(1)
    expect(c.cycleNumber('2026-01-15')).toBe(2)
    expect(c.cycleId('2026-01-15')).not.toBe(c.cycleId('2026-01-14'))
    expect(c.startOfCycleContaining('2026-01-20')).toBe('2026-01-15')
  })

  it('handles dates before the start date', () => {
    expect(c.cycleDay('2025-12-31')).toBe(14)
    expect(c.cycleIndex('2025-12-31')).toBe(-1)
  })

  it('date helpers cross DST and month boundaries', () => {
    expect(addDays('2026-03-07', 1)).toBe('2026-03-08')
    expect(addDays('2026-01-31', 1)).toBe('2026-02-01')
    expect(daysBetween('2026-03-01', '2026-03-15')).toBe(14)
  })
})
