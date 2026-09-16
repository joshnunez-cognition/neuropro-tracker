import { useState } from 'react'
import { useApp } from '../app/AppContext'
import { Button, Disclaimer } from '../components/ui'
import { ROTATION_WINDOW_DAYS } from '../domain/config'

const STEPS = [
  {
    title: 'Your body is the tracker',
    body: `Each day, rotate the 3D body, tap exactly where you placed your NEUPRO patch, and confirm. That's it.`,
  },
  {
    title: 'Rotate sites automatically',
    body: `The app blocks the same spot for ${ROTATION_WINDOW_DAYS} days and the same broad area as yesterday, and suggests alternating left and right sides.`,
  },
  {
    title: 'Private by design',
    body: 'Everything stays on this device in your browser. No account, no upload. Add this page to your home screen for quick access.',
  },
]

export function OnboardingPage() {
  const app = useApp()
  const [i, setI] = useState(0)
  const [start, setStart] = useState(app.settings.cycleStartDate)
  const last = i === STEPS.length - 1

  return (
    <div className="mx-auto flex h-full max-w-md flex-col px-6 pb-[max(1.5rem,env(safe-area-inset-bottom))] pt-[max(3rem,env(safe-area-inset-top))]">
      <p className="text-sm font-semibold uppercase tracking-wide text-brand">NEUPRO Patch Tracker</p>
      <div className="mt-8 flex-1">
        <h1 className="text-4xl font-bold leading-tight tracking-tight">{STEPS[i].title}</h1>
        <p className="mt-4 text-lg leading-relaxed text-slate-600">{STEPS[i].body}</p>
        {last && (
          <label className="mt-8 block">
            <span className="font-medium">When did your current {ROTATION_WINDOW_DAYS}-day cycle start?</span>
            <input type="date" value={start} onChange={(e) => e.target.value && setStart(e.target.value)} className="mt-2 block min-h-14 w-full rounded-2xl border border-slate-200 bg-white px-4 text-lg" />
            <span className="mt-1 block text-sm text-slate-500">Leave today if you're not sure.</span>
          </label>
        )}
      </div>
      <div className="mb-6 flex justify-center gap-2" aria-hidden>
        {STEPS.map((_, k) => <span key={k} className={`h-2 rounded-full transition-all ${k === i ? 'w-6 bg-brand' : 'w-2 bg-slate-300'}`} />)}
      </div>
      <Button
        className="w-full"
        data-testid="onboarding-next"
        onClick={() => last ? app.updateSettings({ onboardingComplete: true, cycleStartDate: start }) : setI(i + 1)}
      >
        {last ? 'Get started' : 'Continue'}
      </Button>
      {!last && <Button variant="ghost" className="mt-2 w-full" onClick={() => setI(STEPS.length - 1)}>Skip</Button>}
      <Disclaimer />
    </div>
  )
}
