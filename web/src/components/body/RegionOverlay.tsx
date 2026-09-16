import { useMemo } from 'react'
import * as THREE from 'three'
import type { RegionAvailability } from '../../models'

/** Colour + opacity + outline treatment per availability state (not colour-only: outline density differs). */
const STYLE: Record<RegionAvailability, { color: string; opacity: number; wire: boolean }> = {
  available: { color: '#2f6fd6', opacity: 0.28, wire: false },
  recommended: { color: '#1d9a6c', opacity: 0.42, wire: true },
  unavailable: { color: '#8a8f9a', opacity: 0.22, wire: false },
  selected: { color: '#2f6fd6', opacity: 0.45, wire: true },
}

export function RegionOverlay({ geometry, availability }: { geometry: THREE.BufferGeometry; availability: RegionAvailability }) {
  const s = STYLE[availability]
  const fill = useMemo(
    () => new THREE.MeshStandardMaterial({
      color: s.color, transparent: true, opacity: s.opacity, roughness: 0.9,
      polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2, depthWrite: false,
    }),
    [s.color, s.opacity],
  )
  const wire = useMemo(
    () => new THREE.MeshBasicMaterial({ color: s.color, wireframe: true, transparent: true, opacity: 0.35, depthWrite: false }),
    [s.color],
  )
  return (
    <>
      <mesh geometry={geometry} material={fill} userData={{ overlay: true }} scale={[1.006, 1.0, 1.006]} />
      {s.wire && <mesh geometry={geometry} material={wire} userData={{ overlay: true }} scale={[1.008, 1.0, 1.008]} />}
      {availability === 'unavailable' && (
        <mesh geometry={geometry} userData={{ overlay: true }} scale={[1.007, 1.0, 1.007]}>
          <meshBasicMaterial color="#5b6170" wireframe transparent opacity={0.25} depthWrite={false} />
        </mesh>
      )}
    </>
  )
}
