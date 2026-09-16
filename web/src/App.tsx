import { CalendarDays, Clock, Home, Settings as SettingsIcon } from 'lucide-react'
import { useMemo, useState } from 'react'
import { AppContext } from './app/AppContext'
import { useAppStore } from './app/store'
import type { Placement } from './models'
import { HistoryPage } from './pages/History'
import { OnboardingPage } from './pages/Onboarding'
import { PlacementPage } from './pages/Placement'
import { SettingsPage } from './pages/Settings'
import { TodayPage } from './pages/Today'
import { TrackerPage } from './pages/Tracker'
import { LocalPlacementRepository } from './repositories/LocalPlacementRepository'

type Tab = 'today' | 'tracker' | 'history' | 'settings'
type Screen = { kind: 'tabs'; tab: Tab; trackerFocus?: Placement } | { kind: 'placement'; editing?: Placement }

// `?demo` seeds sample data once, then is removed so a reload keeps the user's saves.
const demo = new URLSearchParams(window.location.search).has('demo')
if (demo) window.history.replaceState(null, '', window.location.pathname)

export default function App() {
  const repository = useMemo(() => new LocalPlacementRepository(), [])
  const app = useAppStore(repository, { demo })
  const [screen, setScreen] = useState<Screen>({ kind: 'tabs', tab: 'today' })

  if (!app.ready) return <div className="flex h-full items-center justify-center text-slate-400">Loading…</div>

  return (
    <AppContext.Provider value={app}>
      <div className="mx-auto flex h-full max-w-md flex-col">
        {!app.settings.onboardingComplete ? (
          <OnboardingPage />
        ) : screen.kind === 'placement' ? (
          <PlacementPage
            editing={screen.editing}
            onDone={() => setScreen({ kind: 'tabs', tab: 'today' })}
            onCancel={() => setScreen({ kind: 'tabs', tab: 'today' })}
          />
        ) : (
          <>
            <main className="min-h-0 flex-1">
              {screen.tab === 'today' && (
                <TodayPage
                  onLog={() => setScreen({ kind: 'placement' })}
                  onEdit={() => setScreen({ kind: 'placement', editing: app.todayPlacement })}
                  onViewTracker={() => setScreen({ kind: 'tabs', tab: 'tracker' })}
                  onSettings={() => setScreen({ kind: 'tabs', tab: 'settings' })}
                />
              )}
              {screen.tab === 'tracker' && <TrackerPage initialFocus={screen.trackerFocus} />}
              {screen.tab === 'history' && <HistoryPage onOpenInTracker={(p) => setScreen({ kind: 'tabs', tab: 'tracker', trackerFocus: p })} />}
              {screen.tab === 'settings' && <SettingsPage />}
            </main>
            <TabBar tab={screen.tab} onChange={(tab) => setScreen({ kind: 'tabs', tab })} />
          </>
        )}
      </div>
    </AppContext.Provider>
  )
}

function TabBar({ tab, onChange }: { tab: Tab; onChange: (t: Tab) => void }) {
  const items: { id: Tab; label: string; icon: typeof Home }[] = [
    { id: 'today', label: 'Today', icon: Home },
    { id: 'tracker', label: 'Tracker', icon: CalendarDays },
    { id: 'history', label: 'History', icon: Clock },
    { id: 'settings', label: 'Settings', icon: SettingsIcon },
  ]
  return (
    <nav className="flex border-t border-slate-200 bg-white/90 pb-[env(safe-area-inset-bottom)] backdrop-blur" aria-label="Main">
      {items.map(({ id, label, icon: Icon }) => (
        <button
          key={id}
          onClick={() => onChange(id)}
          aria-current={tab === id ? 'page' : undefined}
          data-testid={`tab-${id}`}
          className={`flex min-h-16 flex-1 flex-col items-center justify-center gap-1 text-xs font-medium ${tab === id ? 'text-brand' : 'text-slate-500'}`}
        >
          <Icon size={22} />
          {label}
        </button>
      ))}
    </nav>
  )
}
