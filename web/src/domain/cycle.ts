import { ROTATION_WINDOW_DAYS } from './config'
import { addDays, daysBetween, type DayString } from './dates'

/**
 * Rolling fixed-length cycles anchored at a start day. Day numbering is purely
 * date based: the day after Day 14 is Day 1 of the next cycle.
 */
export class CycleManager {
  constructor(
    readonly startDate: DayString,
    readonly cycleLength: number = ROTATION_WINDOW_DAYS,
  ) {}

  dayOffset(date: DayString): number {
    return daysBetween(this.startDate, date)
  }

  cycleIndex(date: DayString): number {
    return Math.floor(this.dayOffset(date) / this.cycleLength)
  }

  /** 1-based day within the cycle. */
  cycleDay(date: DayString): number {
    const o = this.dayOffset(date)
    return ((o % this.cycleLength) + this.cycleLength) % this.cycleLength + 1
  }

  cycleNumber(date: DayString): number {
    return this.cycleIndex(date) + 1
  }

  cycleId(date: DayString): string {
    return `cycle-${this.cycleNumber(date)}`
  }

  startOfCycleContaining(date: DayString): DayString {
    return addDays(this.startDate, this.cycleIndex(date) * this.cycleLength)
  }

  dateForCycleDay(day: number, reference: DayString): DayString {
    return addDays(this.startOfCycleContaining(reference), day - 1)
  }
}

export function getCurrentCycleDay(startDate: DayString, date: DayString): number {
  return new CycleManager(startDate).cycleDay(date)
}
