import { Check } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useApp } from '../app/AppContext'
import { BodyViewer } from '../components/body/BodyViewer'
import { Card } from '../components/ui'
import { bodyRegions } from '../data/bodyRegions'
import { formatDay } from '../domain/dates'
import type { Placement } from '../models'
import { BodyViewController } from '../three/viewController'

export function TrackerPage({ initialFocus }: { initialFocus?: Placement }) {
  const app = useApp()
  const controller = useMemo(() => {
    const c = new BodyViewController(app.model.height)
    if (initialFocus) c.focus(initialFocus.surfaceLocation)
    return c
  }, [app.model, initialFocus])
  const [focusedId, setFocusedId] = useState<string | undefined>(initialFocus?.id)

  const cycleIdx = app.cycle.cycleIndex(app.today)
  const todayDay = app.cycle.cycleDay(app.today)
  const byDay = useMemo(() => {
    const m = new Map<number, Placement>()
    for (const p of app.placements) if (app.cycle.cycleIndex(p.date) === cycleIdx) m.set(p.cycleDay, p)
    return m
  }, [app.placements, app.cycle, cycleIdx])

  const focus = (p: Placement) => { setFocusedId(p.id); controller.focus(p.surfaceLocation) }
  const focused = app.placements.find((p) => p.id === focusedId)

  return (
    <div className="mx-auto flex h-full max-w-md flex-col px-4 pt-[max(1rem,env(safe-area-inset-top))]">
      <h1 className="text-3xl font-bold tracking-tight">Tracker</h1>
      <p className="text-slate-500">Cycle {app.cycle.cycleNumber(app.today)} · {byDay.size} of {app.cycle.cycleLength} days logged</p>

      <div className="relative mt-3 h-[38vh] shrink-0 overflow-hidden rounded-3xl bg-white shadow-[0_2px_16px_rgba(23,32,46,0.06)]">
        <BodyViewer
          model={app.model} mapper={app.mapper} regions={bodyRegions} controller={controller}
          availability={app.regionAvailability()} placements={app.placements}
          focusedPlacementId={focusedId} exclusionRadius={app.rules.exclusionRadius}
          onTap={(r) => { if (r.kind === 'marker') { const p = app.placements.find((x) => x.id === r.placementId); if (p) focus(p) } }}
          className="h-full w-full"
        />
        {focused && (
          <div className="absolute inset-x-3 bottom-3 rounded-2xl bg-white/90 px-4 py-2 shadow backdrop-blur">
            <p className="font-semibold">Day {focused.cycleDay} — {formatDay(focused.date)}</p>
            <p className="text-sm text-slate-600">{focused.regionName}</p>
          </div>
        )}
      </div>

      <Card className="mt-3 min-h-0 flex-1 overflow-y-auto p-2">
        <ul className="divide-y divide-slate-100">
          {Array.from({ length: app.cycle.cycleLength }, (_, i) => i + 1).map((d) => {
            const p = byDay.get(d)
            const isToday = d === todayDay
            return (
              <li key={d}>
                <button
                  disabled={!p}
                  onClick={() => p && focus(p)}
                  data-testid={`tracker-day-${d}`}
                  className={`flex w-full items-center gap-3 rounded-xl px-3 py-3 text-left ${p ? 'hover:bg-slate-50' : ''} ${focusedId && p?.id === focusedId ? 'bg-blue-50' : ''}`}
                >
                  <span className={`w-14 shrink-0 text-sm font-semibold ${isToday ? 'text-brand' : 'text-slate-500'}`}>Day {d}</span>
                  {p ? (
                    <>
                      <Check size={18} className="text-emerald-600" />
                      <span className="flex-1 font-medium">{p.regionName}</span>
                      <span className="text-sm text-slate-500">{formatDay(p.date)}</span>
                    </>
                  ) : (
                    <span className="flex-1 text-slate-400">{isToday ? 'Today — not logged yet' : d < todayDay ? 'Not logged' : '—'}</span>
                  )}
                </button>
              </li>
            )
          })}
        </ul>
      </Card>
    </div>
  )
}
