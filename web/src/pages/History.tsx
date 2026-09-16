import { Trash2 } from 'lucide-react'
import { useState } from 'react'
import { useApp } from '../app/AppContext'
import { Button, Card, Sheet, SideBadge } from '../components/ui'
import { formatDay, formatTime } from '../domain/dates'
import type { Placement } from '../models'

export function HistoryPage({ onOpenInTracker }: { onOpenInTracker: (p: Placement) => void }) {
  const app = useApp()
  const [pendingDelete, setPendingDelete] = useState<Placement>()
  const sorted = [...app.placements].sort((a, b) => (a.date < b.date ? 1 : -1))

  return (
    <div className="mx-auto flex h-full max-w-md flex-col px-4 pt-[max(1rem,env(safe-area-inset-top))]">
      <h1 className="text-3xl font-bold tracking-tight">History</h1>
      <p className="text-slate-500">{sorted.length} placement{sorted.length === 1 ? '' : 's'}</p>
      {sorted.length === 0 ? (
        <Card className="mt-4 text-center text-slate-500">No placements logged yet.</Card>
      ) : (
        <Card className="mt-3 min-h-0 flex-1 overflow-y-auto p-2">
          <ul className="divide-y divide-slate-100">
            {sorted.map((p) => (
              <li key={p.id} className="flex items-center gap-2 px-2 py-3">
                <button className="flex-1 text-left" onClick={() => onOpenInTracker(p)}>
                  <p className="font-semibold">{p.regionName} <SideBadge side={p.side} /></p>
                  <p className="text-sm text-slate-500">{formatDay(p.date, { weekday: 'short', month: 'short', day: 'numeric' })} · {formatTime(p.timestamp)} · Cycle day {p.cycleDay}</p>
                </button>
                <button aria-label={`Delete placement on ${formatDay(p.date)}`} onClick={() => setPendingDelete(p)} className="rounded-full p-3 text-slate-400 hover:bg-red-50 hover:text-red-600">
                  <Trash2 size={18} />
                </button>
              </li>
            ))}
          </ul>
        </Card>
      )}
      <Sheet open={!!pendingDelete} onClose={() => setPendingDelete(undefined)} title="Delete placement">
        <h2 className="text-xl font-bold">Delete this placement?</h2>
        <p className="mt-1 text-slate-600">{pendingDelete?.regionName} on {pendingDelete && formatDay(pendingDelete.date)}. This can't be undone.</p>
        <div className="mt-6 flex flex-col gap-3">
          <Button variant="danger" onClick={async () => { if (pendingDelete) await app.deletePlacement(pendingDelete.id); setPendingDelete(undefined) }}>Delete</Button>
          <Button variant="ghost" onClick={() => setPendingDelete(undefined)}>Cancel</Button>
        </div>
      </Sheet>
    </div>
  )
}
