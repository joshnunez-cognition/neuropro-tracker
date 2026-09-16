import { useState } from 'react'
import { useApp } from '../app/AppContext'
import { Button, Card, Sheet } from '../components/ui'
import { ROTATION_WINDOW_DAYS } from '../domain/config'

export function SettingsPage() {
  const app = useApp()
  const [confirmClear, setConfirmClear] = useState(false)
  const [confirmDemo, setConfirmDemo] = useState(false)

  return (
    <div className="mx-auto flex h-full max-w-md flex-col gap-4 overflow-y-auto px-4 pb-6 pt-[max(1rem,env(safe-area-inset-top))]">
      <h1 className="text-3xl font-bold tracking-tight">Settings</h1>

      <Card className="space-y-4">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-slate-500">Cycle</h2>
        <label className="flex items-center justify-between gap-4">
          <span className="font-medium">Cycle start date</span>
          <input
            type="date"
            value={app.settings.cycleStartDate}
            onChange={(e) => e.target.value && app.updateSettings({ cycleStartDate: e.target.value })}
            className="min-h-12 rounded-xl border border-slate-200 px-3 text-base"
          />
        </label>
        <p className="text-sm text-slate-500">Each cycle is {ROTATION_WINDOW_DAYS} days. Today is Day {app.cycle.cycleDay(app.today)}.</p>
      </Card>

      <Card className="space-y-4">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-slate-500">Placement guidance</h2>
        <Toggle
          label="Recommend alternating sides"
          description="Suggest the opposite side from yesterday. Same-side placements stay allowed."
          checked={app.settings.sideRecommendationEnabled}
          onChange={(v) => app.updateSettings({ sideRecommendationEnabled: v })}
        />
      </Card>

      <Card className="space-y-4">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-slate-500">Reminder</h2>
        <Toggle
          label="Daily reminder"
          description="Reminder time is stored here; web notifications aren't scheduled by this app."
          checked={app.settings.reminderEnabled}
          onChange={(v) => app.updateSettings({ reminderEnabled: v })}
        />
        {app.settings.reminderEnabled && (
          <label className="flex items-center justify-between gap-4">
            <span className="font-medium">Time</span>
            <input type="time" value={app.settings.reminderTime} onChange={(e) => app.updateSettings({ reminderTime: e.target.value })} className="min-h-12 rounded-xl border border-slate-200 px-3 text-base" />
          </label>
        )}
      </Card>

      <Card className="space-y-3">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-slate-500">Data</h2>
        <p className="text-sm text-slate-500">Everything is stored only on this device in your browser. {app.placements.length} placement{app.placements.length === 1 ? '' : 's'} saved.</p>
        <Button variant="secondary" className="w-full" onClick={() => setConfirmDemo(true)} data-testid="load-demo">Load demo data</Button>
        <Button variant="danger" className="w-full" onClick={() => setConfirmClear(true)} data-testid="clear-history">Clear history</Button>
      </Card>

      <Card>
        <h2 className="text-sm font-semibold uppercase tracking-wide text-slate-500">About</h2>
        <p className="mt-2 text-sm leading-relaxed text-slate-600">
          NEUPRO Patch Tracker helps you remember where you placed each patch so you can rotate sites. It is not medical advice and does not replace the instructions that came with your medication. Approved areas and spacing rules in this app are engineering estimates pending clinical review.
        </p>
      </Card>

      <Sheet open={confirmClear} onClose={() => setConfirmClear(false)} title="Clear history">
        <h2 className="text-xl font-bold">Clear all placements?</h2>
        <p className="mt-1 text-slate-600">This removes every logged placement from this device.</p>
        <div className="mt-6 flex flex-col gap-3">
          <Button variant="danger" onClick={async () => { await app.clearHistory(); setConfirmClear(false) }} data-testid="confirm-clear">Clear history</Button>
          <Button variant="ghost" onClick={() => setConfirmClear(false)}>Cancel</Button>
        </div>
      </Sheet>
      <Sheet open={confirmDemo} onClose={() => setConfirmDemo(false)} title="Load demo data">
        <h2 className="text-xl font-bold">Replace with demo data?</h2>
        <p className="mt-1 text-slate-600">Your current history will be replaced with five sample placements so today is Day 6.</p>
        <div className="mt-6 flex flex-col gap-3">
          <Button onClick={async () => { await app.loadDemoData(); setConfirmDemo(false) }} data-testid="confirm-demo">Load demo data</Button>
          <Button variant="ghost" onClick={() => setConfirmDemo(false)}>Cancel</Button>
        </div>
      </Sheet>
    </div>
  )
}

function Toggle({ label, description, checked, onChange }: { label: string; description?: string; checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <button role="switch" aria-checked={checked} onClick={() => onChange(!checked)} className="flex w-full items-center justify-between gap-4 text-left">
      <span>
        <span className="block font-medium">{label}</span>
        {description && <span className="block text-sm text-slate-500">{description}</span>}
      </span>
      <span className={`relative h-8 w-14 shrink-0 rounded-full transition ${checked ? 'bg-brand' : 'bg-slate-300'}`}>
        <span className={`absolute top-1 h-6 w-6 rounded-full bg-white shadow transition ${checked ? 'left-7' : 'left-1'}`} />
        <span className="sr-only">{checked ? 'On' : 'Off'}</span>
      </span>
    </button>
  )
}
