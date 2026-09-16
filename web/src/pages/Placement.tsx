import { AlertCircle, Check, ChevronDown, Info, Lightbulb, RotateCcw, X } from 'lucide-react'
import { useEffect, useMemo, useRef, useState } from 'react'
import { useApp } from '../app/AppContext'
import { BodyViewer } from '../components/body/BodyViewer'
import { Banner, Button, Sheet, SideBadge } from '../components/ui'
import { bodyRegions } from '../data/bodyRegions'
import { formatDay } from '../domain/dates'
import { availabilityLabel, type Placement as PlacementModel, type RegionAvailability } from '../models'
import { BodyViewController, type Orientation } from '../three/viewController'
import { usePlacementFlow } from './usePlacementFlow'

const TUTORIAL_KEY = 'neupro.tutorialSeen'

export function PlacementPage({ editing, onDone, onCancel }: { editing?: PlacementModel; onDone: (p: PlacementModel) => void; onCancel: () => void }) {
  const app = useApp()
  const flow = usePlacementFlow(app, editing)
  const controller = useMemo(() => new BodyViewController(app.model.height), [app.model])
  const [showTutorial, setShowTutorial] = useState(() => !localStorage.getItem(TUTORIAL_KEY))
  const [confirming, setConfirming] = useState(false)
  const [menuOpen, setMenuOpen] = useState(false)
  const [manualOpen, setManualOpen] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string>()
  const focused = useRef(false)

  useEffect(() => {
    controller.onInteract = () => {
      if (showTutorial) { setShowTutorial(false); localStorage.setItem(TUTORIAL_KEY, '1') }
    }
  }, [controller, showTutorial])

  useEffect(() => {
    if (editing && !focused.current) { controller.focus(editing.surfaceLocation); focused.current = true }
  }, [editing, controller])

  const availability = useMemo(() => {
    const a: Record<string, RegionAvailability> = { ...app.regionAvailability(flow.editingId) }
    if (flow.candidate && flow.validation?.valid) a[flow.candidate.region.id] = 'selected'
    return a
  }, [app, flow.editingId, flow.candidate, flow.validation])

  const rotate = (o: Orientation) => { controller.rotateTo(o); setMenuOpen(false) }

  const save = async () => {
    setSaving(true)
    try {
      const p = await flow.confirm()
      setConfirming(false)
      onDone(p)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not save placement')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="flex h-full flex-col">
      <header className="flex items-center justify-between px-3 pt-[max(0.5rem,env(safe-area-inset-top))]">
        <button onClick={onCancel} className="flex min-h-12 items-center gap-1 rounded-xl px-3 text-base font-medium text-slate-600" data-testid="cancel-placement">
          <X size={20} /> Cancel
        </button>
        <h1 className="text-base font-semibold">{editing ? 'Change placement' : "Today's patch"}</h1>
        <div className="relative">
          <button onClick={() => setMenuOpen((v) => !v)} className="flex min-h-12 items-center gap-1 rounded-xl px-3 text-base font-medium text-brand" aria-haspopup="menu" aria-expanded={menuOpen} data-testid="view-options">
            View <ChevronDown size={18} />
          </button>
          {menuOpen && (
            <div role="menu" className="absolute right-0 z-20 mt-1 w-52 overflow-hidden rounded-2xl bg-white p-1 shadow-xl ring-1 ring-slate-200">
              {(['front', 'right', 'back', 'left'] as Orientation[]).map((o) => (
                <button key={o} role="menuitem" onClick={() => rotate(o)} className="block w-full rounded-xl px-4 py-3 text-left text-base capitalize hover:bg-slate-50">
                  {o === 'front' || o === 'back' ? `${o} view` : `${o} side`}
                </button>
              ))}
              <button role="menuitem" onClick={() => { controller.reset(); setMenuOpen(false) }} className="flex w-full items-center gap-2 rounded-xl px-4 py-3 text-left text-base hover:bg-slate-50">
                <RotateCcw size={16} /> Reset zoom
              </button>
              <button role="menuitem" onClick={() => { setManualOpen(true); setMenuOpen(false) }} className="block w-full rounded-xl px-4 py-3 text-left text-base hover:bg-slate-50" data-testid="choose-manually">
                Choose area manually
              </button>
            </div>
          )}
        </div>
      </header>

      <p className="px-5 pt-1 text-center text-lg font-medium text-slate-800">
        {flow.candidate && flow.validation?.valid ? 'Confirm this spot or tap another.' : "Tap where you're placing today's patch."}
      </p>

      <div className="relative min-h-0 flex-1">
        <BodyViewer
          model={app.model}
          mapper={app.mapper}
          regions={bodyRegions}
          controller={controller}
          availability={availability}
          placements={flow.history}
          preview={flow.preview}
          exclusionRadius={app.rules.exclusionRadius}
          onTap={flow.handleTap}
          className="h-full w-full"
        />
        {showTutorial && (
          <div className="pointer-events-none absolute inset-x-0 top-3 flex justify-center">
            <div className="rounded-2xl bg-slate-900/80 px-4 py-2 text-center text-sm font-medium text-white shadow">
              Swipe to rotate · Tap where you placed your patch
            </div>
          </div>
        )}
        <Legend />
      </div>

      <div className="space-y-3 px-4 pb-[max(1rem,env(safe-area-inset-bottom))] pt-2">
        <FeedbackView flow={flow} />
        {flow.inspected && (
          <div className="flex items-center justify-between rounded-2xl bg-slate-100 px-4 py-3">
            <div>
              <p className="font-semibold">Day {flow.inspected.cycleDay} — {formatDay(flow.inspected.date)}</p>
              <p className="text-sm text-slate-600">{flow.inspected.regionName}</p>
            </div>
            <button onClick={flow.dismissInspection} className="p-2 text-slate-500" aria-label="Dismiss"><X size={18} /></button>
          </div>
        )}
        <div className="flex gap-3">
          {flow.candidate && (
            <Button variant="secondary" className="flex-1" onClick={flow.clear} data-testid="clear-selection">Choose another spot</Button>
          )}
          <Button className="flex-1" disabled={!flow.canConfirm} onClick={() => setConfirming(true)} data-testid="confirm-placement">
            Confirm placement
          </Button>
        </div>
      </div>

      <Sheet open={confirming} onClose={() => setConfirming(false)} title="Confirm placement">
        <p className="text-sm font-semibold uppercase tracking-wide text-slate-500">{editing ? 'Update placement' : "Today's placement"}</p>
        <h2 className="mt-1 text-2xl font-bold">{flow.candidate?.region.name}</h2>
        <div className="mt-2 flex items-center gap-2 text-slate-600">
          {flow.candidate && <SideBadge side={flow.candidate.region.side} />}
          <span>Day {app.cycle.cycleDay(app.today)} of {app.cycle.cycleLength}</span>
        </div>
        {flow.feedback.kind === 'recommendation' && (
          <div className="mt-4"><Banner tone="warn" title={flow.feedback.title} icon={<Lightbulb size={18} />}>{flow.feedback.message}</Banner></div>
        )}
        {error && <div className="mt-4"><Banner tone="error" title="Could not save">{error}</Banner></div>}
        <div className="mt-6 flex flex-col gap-3">
          <Button onClick={save} disabled={saving} data-testid="save-placement"><Check size={20} /> {editing ? 'Update placement' : 'Confirm placement'}</Button>
          <Button variant="ghost" onClick={() => setConfirming(false)}>Cancel</Button>
        </div>
      </Sheet>

      <Sheet open={manualOpen} onClose={() => setManualOpen(false)} title="Choose area manually">
        <h2 className="text-xl font-bold">Choose an area</h2>
        <p className="mt-1 text-sm text-slate-600">Picks the centre of the area. Tapping the body gives a more exact spot.</p>
        <ul className="mt-4 max-h-[50vh] space-y-2 overflow-y-auto">
          {bodyRegions.map((r) => (
            <li key={r.id}>
              <button
                onClick={() => { flow.selectRegionCenter(r); controller.focus(app.mapper.regionCenter(r)!); setManualOpen(false) }}
                className="flex w-full items-center justify-between rounded-2xl border border-slate-200 px-4 py-3 text-left text-base hover:bg-slate-50"
              >
                <span className="font-medium">{r.name}</span>
                <span className="text-sm text-slate-500">{availabilityLabel[availability[r.id] ?? 'available']}</span>
              </button>
            </li>
          ))}
        </ul>
      </Sheet>
    </div>
  )
}

function FeedbackView({ flow }: { flow: ReturnType<typeof usePlacementFlow> }) {
  const f = flow.feedback
  switch (f.kind) {
    case 'none':
      return <Banner tone="info" title="Highlighted areas are approved placement areas" icon={<Info size={18} />} />
    case 'blocked':
      return <div data-testid="feedback-blocked"><Banner tone="error" title={f.title} icon={<AlertCircle size={18} />}>{f.message}</Banner></div>
    case 'recommendation':
      return <div data-testid="feedback-recommendation"><Banner tone="warn" title={f.title} icon={<Lightbulb size={18} />}>{f.message} You can still confirm this location.</Banner></div>
    case 'ready':
      return <div data-testid="feedback-ready"><Banner tone="success" title={`${f.regionName} selected`} icon={<Check size={18} />}>Patch preview shown on the body.</Banner></div>
  }
}

function Legend() {
  const items: { key: RegionAvailability; swatch: string }[] = [
    { key: 'recommended', swatch: 'bg-emerald-500/60 ring-2 ring-emerald-700/50' },
    { key: 'available', swatch: 'bg-blue-500/50' },
    { key: 'unavailable', swatch: 'bg-slate-400/60 [background-image:repeating-linear-gradient(45deg,transparent_0_2px,#5b6170_2px_3px)]' },
  ]
  return (
    <div className="pointer-events-none absolute bottom-2 left-3 flex flex-col gap-1 rounded-xl bg-white/85 px-2.5 py-2 text-xs text-slate-700 shadow backdrop-blur">
      {items.map((i) => (
        <div key={i.key} className="flex items-center gap-2">
          <span className={`inline-block h-3 w-4 rounded-sm ${i.swatch}`} />
          {availabilityLabel[i.key]}
        </div>
      ))}
    </div>
  )
}
