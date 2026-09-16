import type { ButtonHTMLAttributes, ReactNode } from 'react'
import { sideLabel, type BodySide } from '../../models'

export function Button({
  variant = 'primary', className = '', ...rest
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: 'primary' | 'secondary' | 'ghost' | 'danger' }) {
  const base = 'inline-flex items-center justify-center gap-2 rounded-2xl px-5 font-semibold transition active:scale-[0.98] disabled:opacity-40 disabled:active:scale-100 min-h-14 text-lg'
  const styles = {
    primary: 'bg-brand text-white shadow-lg shadow-brand/25 hover:bg-brand-dark',
    secondary: 'bg-white text-slate-900 border border-slate-200 shadow-sm hover:bg-slate-50',
    ghost: 'bg-transparent text-brand hover:bg-brand/10 min-h-12 text-base',
    danger: 'bg-red-50 text-red-700 border border-red-200 hover:bg-red-100',
  }[variant]
  return <button className={`${base} ${styles} ${className}`} {...rest} />
}

export function Card({ children, className = '', ...rest }: { children: ReactNode; className?: string } & React.HTMLAttributes<HTMLDivElement>) {
  return <div className={`rounded-3xl bg-white p-5 shadow-[0_2px_16px_rgba(23,32,46,0.06)] ${className}`} {...rest}>{children}</div>
}

export function SideBadge({ side }: { side: BodySide }) {
  return (
    <span className="inline-flex items-center rounded-full bg-slate-100 px-2.5 py-0.5 text-xs font-semibold uppercase tracking-wide text-slate-600">
      {sideLabel(side)}
    </span>
  )
}

export function Banner({ tone, title, children, icon }: { tone: 'info' | 'warn' | 'error' | 'success'; title: string; children?: ReactNode; icon?: ReactNode }) {
  const styles = {
    info: 'bg-blue-50 text-blue-900 border-blue-100',
    warn: 'bg-amber-50 text-amber-900 border-amber-100',
    error: 'bg-red-50 text-red-900 border-red-100',
    success: 'bg-emerald-50 text-emerald-900 border-emerald-100',
  }[tone]
  return (
    <div role={tone === 'error' ? 'alert' : 'status'} className={`flex gap-3 rounded-2xl border p-4 ${styles}`}>
      {icon && <div className="mt-0.5 shrink-0">{icon}</div>}
      <div>
        <p className="font-semibold leading-tight">{title}</p>
        {children && <p className="mt-1 text-sm leading-snug opacity-90">{children}</p>}
      </div>
    </div>
  )
}

export function Disclaimer() {
  return (
    <p className="px-2 pb-4 text-center text-xs leading-relaxed text-slate-500">
      Follow the placement and use instructions provided with your medication. This app only records where you say you placed your patch.
    </p>
  )
}

export function Sheet({ open, onClose, children, title }: { open: boolean; onClose: () => void; children: ReactNode; title: string }) {
  if (!open) return null
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-slate-900/40" onClick={onClose} role="presentation">
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className="w-full max-w-md rounded-t-3xl bg-white p-6 pb-[max(1.5rem,env(safe-area-inset-bottom))] shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        {children}
      </div>
    </div>
  )
}
