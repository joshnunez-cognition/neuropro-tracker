import { CheckCircle2, ChevronRight, Lightbulb, Settings } from 'lucide-react'
import { useApp } from '../app/AppContext'
import { Button, Card, Disclaimer, SideBadge } from '../components/ui'
import { formatDay, formatTime } from '../domain/dates'
import { sideLabel } from '../models'

export function TodayPage({ onLog, onEdit, onViewTracker, onSettings }: { onLog: () => void; onEdit: () => void; onViewTracker: () => void; onSettings: () => void }) {
  const app = useApp()
  const day = app.cycle.cycleDay(app.today)
  const hour = new Date().getHours()
  const greeting = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening'
  const loggedDays = new Set(
    app.placements.filter((p) => app.cycle.cycleIndex(p.date) === app.cycle.cycleIndex(app.today)).map((p) => p.cycleDay),
  )

  return (
    <div className="mx-auto flex h-full max-w-md flex-col gap-4 overflow-y-auto px-4 pb-4 pt-[max(1rem,env(safe-area-inset-top))]">
      <header className="flex items-start justify-between">
        <div>
          <p className="text-slate-500">{greeting}</p>
          <h1 className="text-3xl font-bold tracking-tight">Today</h1>
        </div>
        <button onClick={onSettings} aria-label="Settings" className="rounded-full p-3 text-slate-500 hover:bg-white"><Settings size={22} /></button>
      </header>

      <Card data-testid="cycle-card">
        <div className="flex items-end justify-between">
          <div>
            <p className="text-sm font-semibold uppercase tracking-wide text-slate-500">Cycle {app.cycle.cycleNumber(app.today)}</p>
            <p className="text-4xl font-bold">Day {day} <span className="text-xl font-medium text-slate-400">of {app.cycle.cycleLength}</span></p>
          </div>
          <p className="text-slate-500">{formatDay(app.today, { weekday: 'short', month: 'short', day: 'numeric' })}</p>
        </div>
        <button onClick={onViewTracker} className="mt-4 flex w-full items-center justify-center gap-1" aria-label="Open 14-day tracker">
          {Array.from({ length: app.cycle.cycleLength }, (_, i) => i + 1).map((d) => (
            <span
              key={d}
              className={`h-3 flex-1 rounded-full ${loggedDays.has(d) ? 'bg-brand' : d === day ? 'bg-brand/30 ring-2 ring-brand' : 'bg-slate-200'}`}
            />
          ))}
        </button>
      </Card>

      {app.todayPlacement ? (
        <Card>
          <div className="flex items-center gap-3">
            <CheckCircle2 className="text-emerald-600" size={28} />
            <div>
              <p className="text-sm font-semibold uppercase tracking-wide text-slate-500">Today's patch</p>
              <p className="text-2xl font-bold">{app.todayPlacement.regionName}</p>
              <p className="text-sm text-slate-500">Logged at {formatTime(app.todayPlacement.timestamp)}</p>
            </div>
          </div>
          <p className="mt-4 text-slate-600">Day {day} complete. Tomorrow we'll help you choose another location.</p>
          <Button variant="secondary" className="mt-4 w-full" onClick={onEdit} data-testid="change-today">Change today's location</Button>
        </Card>
      ) : (
        <>
          <Card>
            <p className="text-sm font-semibold uppercase tracking-wide text-slate-500">Yesterday</p>
            {app.yesterdayPlacement ? (
              <div className="mt-1 flex items-center gap-2">
                <p className="text-xl font-semibold">{app.yesterdayPlacement.regionName}</p>
                <SideBadge side={app.yesterdayPlacement.side} />
              </div>
            ) : (
              <p className="mt-1 text-lg text-slate-500">No patch logged yesterday</p>
            )}
            {app.recommendedSide && (
              <div className="mt-3 flex items-start gap-2 rounded-2xl bg-amber-50 p-3 text-amber-900">
                <Lightbulb size={18} className="mt-0.5 shrink-0" />
                <p className="text-sm"><span className="font-semibold">Recommended today:</span> {sideLabel(app.recommendedSide)} side, to alternate from yesterday.</p>
              </div>
            )}
          </Card>
          <Button className="w-full py-5 text-xl" onClick={onLog} data-testid="log-today">
            Log today's patch <ChevronRight size={22} />
          </Button>
        </>
      )}

      <div className="flex-1" />
      <Disclaimer />
    </div>
  )
}
