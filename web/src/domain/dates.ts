/** Local-calendar day helpers. Days are represented as 'YYYY-MM-DD' strings. */

export type DayString = string

export function toDayString(d: Date): DayString {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

export function parseDay(s: DayString): Date {
  const [y, m, d] = s.split('-').map(Number)
  return new Date(y, m - 1, d)
}

export function today(): DayString {
  return toDayString(new Date())
}

export function addDays(s: DayString, n: number): DayString {
  const d = parseDay(s)
  d.setDate(d.getDate() + n)
  return toDayString(d)
}

/** Whole calendar days from `from` to `to` (positive when `to` is later). */
export function daysBetween(from: DayString, to: DayString): number {
  const a = Date.UTC(...ymd(from))
  const b = Date.UTC(...ymd(to))
  return Math.round((b - a) / 86_400_000)
}

function ymd(s: DayString): [number, number, number] {
  const [y, m, d] = s.split('-').map(Number)
  return [y, m - 1, d]
}

export function formatDay(s: DayString, opts: Intl.DateTimeFormatOptions = { month: 'short', day: 'numeric' }): string {
  return parseDay(s).toLocaleDateString(undefined, opts)
}

export function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })
}
