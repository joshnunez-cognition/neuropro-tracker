import { Html } from '@react-three/drei'
import { useMemo } from 'react'
import type { SurfaceLocation } from '../../models'
import { normalQuaternion } from '../../three/bodyGeometry'

export type MarkerStyle = 'today' | 'history' | 'blocked' | 'focused'

const COLORS: Record<MarkerStyle, { fill: string; border: string }> = {
  today: { fill: '#fbe7c2', border: '#1f5fbf' },
  history: { fill: '#fff5e6', border: '#4a5568' },
  blocked: { fill: '#f6c7c7', border: '#c62828' },
  focused: { fill: '#fbe7c2', border: '#1d9a6c' },
}

const PATCH_SIZE = 0.048
const PATCH_THICKNESS = 0.004

/** A patch-shaped marker sitting flush on the body surface, oriented along the surface normal. */
export function PatchMarker({
  location, style, placementId, label, exclusionRadius,
}: {
  location: SurfaceLocation
  style: MarkerStyle
  placementId?: string
  label?: string
  exclusionRadius?: number
}) {
  const q = useMemo(() => normalQuaternion(location), [location])
  const c = COLORS[style]
  const isToday = style === 'today' || style === 'blocked'
  return (
    <group position={[location.x, location.y, location.z]} quaternion={q} userData={placementId ? { placementId } : {}}>
      <mesh position={[0, 0, PATCH_THICKNESS / 2]}>
        <boxGeometry args={[PATCH_SIZE, PATCH_SIZE, PATCH_THICKNESS]} />
        <meshStandardMaterial color={c.fill} roughness={0.6} />
      </mesh>
      <mesh position={[0, 0, PATCH_THICKNESS + 0.0005]}>
        <ringGeometry args={[PATCH_SIZE * 0.62, PATCH_SIZE * 0.72, 4, 1, Math.PI / 4]} />
        <meshBasicMaterial color={c.border} />
      </mesh>
      {exclusionRadius && !isToday && (
        <mesh position={[0, 0, 0.001]}>
          <ringGeometry args={[exclusionRadius * 0.9, exclusionRadius, 40]} />
          <meshBasicMaterial color={c.border} transparent opacity={0.35} depthWrite={false} />
        </mesh>
      )}
      {label && (
        <Html position={[0, PATCH_SIZE * 0.95, 0.02]} center occlude zIndexRange={[10, 0]} style={{ pointerEvents: 'none' }}>
          <div className="rounded-full bg-white/90 px-1.5 py-0.5 text-[10px] font-semibold text-slate-700 shadow whitespace-nowrap">{label}</div>
        </Html>
      )}
      {isToday && (
        <mesh position={[0, 0, PATCH_THICKNESS + 0.001]}>
          <ringGeometry args={[PATCH_SIZE * 0.85, PATCH_SIZE * 0.95, 32]} />
          <meshBasicMaterial color={c.border} />
        </mesh>
      )}
    </group>
  )
}
