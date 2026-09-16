import { createContext, useContext } from 'react'
import type { AppStore } from './store'

export const AppContext = createContext<AppStore | null>(null)

export function useApp(): AppStore {
  const ctx = useContext(AppContext)
  if (!ctx) throw new Error('useApp must be used inside AppContext')
  return ctx
}
