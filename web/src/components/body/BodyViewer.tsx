import { Canvas, useFrame, useThree } from '@react-three/fiber'
import { useEffect, useMemo, useRef, useState, type PointerEvent as ReactPointerEvent, type WheelEvent } from 'react'
import * as THREE from 'three'
import type { HumanBodyModel } from '../../body/humanBodyModel'
import type { RegionMapper } from '../../body/regionMapping'
import type { Placement, Region, RegionAvailability, SurfaceLocation } from '../../models'
import { buildBodyGeometries, buildRegionGeometry } from '../../three/bodyGeometry'
import { surfaceLocationFromIntersection } from '../../three/surfaceCoordinates'
import type { BodyViewController } from '../../three/viewController'
import { PatchMarker, type MarkerStyle } from './PatchMarker'
import { RegionOverlay } from './RegionOverlay'

export type BodyTapResult =
  | { kind: 'surface'; location: SurfaceLocation }
  | { kind: 'marker'; placementId: string }
  | { kind: 'miss' }

export interface BodyViewerProps {
  model: HumanBodyModel
  mapper: RegionMapper
  regions: Region[]
  controller: BodyViewController
  availability: Record<string, RegionAvailability>
  placements: Placement[]
  focusedPlacementId?: string
  preview?: { location: SurfaceLocation; blocked: boolean }
  exclusionRadius?: number
  interactive?: boolean
  onTap?: (result: BodyTapResult) => void
  className?: string
}

const TAP_MAX_MOVE = 8
const TAP_MAX_MS = 500

export function BodyViewer(props: BodyViewerProps) {
  const { controller, interactive = true, onTap } = props
  const pointers = useRef(new Map<number, { x: number; y: number }>())
  const gesture = useRef<{ startX: number; startY: number; lastX: number; lastY: number; t: number; moved: boolean; pinchDist?: number } | null>(null)
  const wrapper = useRef<HTMLDivElement>(null)
  const [orientation, setOrientation] = useState(controller.orientation)

  const onPointerDown = (e: ReactPointerEvent) => {
    wrapper.current?.setPointerCapture(e.pointerId)
    pointers.current.set(e.pointerId, { x: e.clientX, y: e.clientY })
    if (pointers.current.size === 1) {
      gesture.current = { startX: e.clientX, startY: e.clientY, lastX: e.clientX, lastY: e.clientY, t: performance.now(), moved: false }
    } else if (pointers.current.size === 2 && gesture.current) {
      gesture.current.pinchDist = pinchDistance()
      gesture.current.moved = true
    }
  }

  const pinchDistance = () => {
    const [a, b] = [...pointers.current.values()]
    return Math.hypot(a.x - b.x, a.y - b.y)
  }

  const onPointerMove = (e: ReactPointerEvent) => {
    if (!pointers.current.has(e.pointerId) || !gesture.current) return
    pointers.current.set(e.pointerId, { x: e.clientX, y: e.clientY })
    const g = gesture.current
    if (pointers.current.size >= 2 && g.pinchDist) {
      const d = pinchDistance()
      controller.zoomBy(d / g.pinchDist)
      g.pinchDist = d
      return
    }
    const dx = e.clientX - g.lastX, dy = e.clientY - g.lastY
    g.lastX = e.clientX; g.lastY = e.clientY
    if (Math.hypot(e.clientX - g.startX, e.clientY - g.startY) > TAP_MAX_MOVE) g.moved = true
    if (!g.moved) return
    const width = wrapper.current?.clientWidth ?? 400
    controller.rotateBy((dx / width) * Math.PI * 1.6)
    controller.panY((dy / width) * controller.bodyHeight * 0.8 / controller.zoom)
  }

  const onPointerUp = (e: ReactPointerEvent) => {
    pointers.current.delete(e.pointerId)
    const g = gesture.current
    if (!g || pointers.current.size > 0) return
    gesture.current = null
    setOrientation(controller.orientation)
    const isTap = !g.moved && performance.now() - g.t < TAP_MAX_MS
    if (!isTap || !interactive || !onTap) return
    const bridge = controller.bridge
    if (!bridge) return
    const hits = bridge.raycast(e.clientX, e.clientY)
    for (const hit of hits) {
      const markerId = findMarkerId(hit.object)
      if (markerId) { onTap({ kind: 'marker', placementId: markerId }); return }
      if (hit.object.userData.partId) {
        const loc = surfaceLocationFromIntersection(hit, bridge.bodyGroup)
        onTap(loc ? { kind: 'surface', location: loc } : { kind: 'miss' })
        return
      }
    }
    onTap({ kind: 'miss' })
  }

  const onWheel = (e: WheelEvent) => {
    controller.zoomBy(Math.exp(-e.deltaY * 0.0015))
  }

  return (
    <div
      ref={wrapper}
      className={`relative isolate select-none ${props.className ?? ''}`}
      style={{ touchAction: 'none' }}
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      onPointerCancel={onPointerUp}
      onWheel={onWheel}
      role="img"
      aria-label={`Interactive human body, ${orientation} view. Swipe to rotate, tap a highlighted area to place your patch.`}
      data-testid="body-viewer"
    >
      <Canvas
        dpr={[1, 2]}
        camera={{ fov: 32, near: 0.05, far: 20, position: [0, controller.lookY, controller.distance] }}
        gl={{ antialias: true, alpha: true, powerPreference: 'high-performance' }}
        style={{ background: 'transparent' }}
      >
        <Scene {...props} />
      </Canvas>
    </div>
  )
}

function findMarkerId(obj: THREE.Object3D): string | undefined {
  let o: THREE.Object3D | null = obj
  while (o) {
    if (o.userData.placementId) return o.userData.placementId as string
    o = o.parent
  }
  return undefined
}

function Scene({ model, mapper, regions, controller, availability, placements, focusedPlacementId, preview, exclusionRadius }: BodyViewerProps) {
  const group = useRef<THREE.Group>(null)
  const { camera, gl, scene } = useThree()
  const parts = useMemo(() => buildBodyGeometries(model), [model])
  const regionGeometries = useMemo(
    () => regions.map((r) => ({ region: r, geometry: buildRegionGeometry(mapper, r, parts) })),
    [regions, mapper, parts],
  )
  const raycaster = useMemo(() => new THREE.Raycaster(), [])

  useEffect(() => {
    if (!group.current) return
    const g = group.current
    controller.bridge = {
      bodyGroup: g,
      raycast(clientX, clientY) {
        const rect = gl.domElement.getBoundingClientRect()
        const ndc = new THREE.Vector2(((clientX - rect.left) / rect.width) * 2 - 1, -((clientY - rect.top) / rect.height) * 2 + 1)
        raycaster.setFromCamera(ndc, camera)
        return raycaster.intersectObjects(scene.children, true).filter((h) => h.object.visible && !h.object.userData.overlay)
      },
    }
    return () => { controller.bridge = null }
  }, [controller, camera, gl, scene, raycaster])

  useFrame((_, dt) => {
    controller.step(Math.min(dt, 0.05))
    if (group.current) group.current.rotation.y = controller.yaw
    camera.position.set(0, controller.lookY + 0.05, controller.distance)
    camera.lookAt(0, controller.lookY, 0)
  })

  const skin = useMemo(() => new THREE.MeshStandardMaterial({ color: '#d9c4b1', roughness: 0.75, metalness: 0 }), [])

  return (
    <>
      <ambientLight intensity={0.9} />
      <directionalLight position={[2, 4, 3]} intensity={1.6} />
      <directionalLight position={[-3, 2, -2]} intensity={0.5} />
      <group ref={group}>
        {parts.map(({ part, geometry }) => (
          <mesh key={part.id} geometry={geometry} material={skin} userData={{ partId: part.id }} />
        ))}
        {regionGeometries.map(({ region, geometry }) =>
          geometry ? (
            <RegionOverlay key={region.id} geometry={geometry} availability={availability[region.id] ?? 'available'} />
          ) : null,
        )}
        {placements.map((p) => (
          <PatchMarker
            key={p.id}
            location={p.surfaceLocation}
            style={p.id === focusedPlacementId ? 'focused' : 'history'}
            placementId={p.id}
            label={`Day ${p.cycleDay}`}
            exclusionRadius={exclusionRadius}
          />
        ))}
        {preview && (
          <PatchMarker location={preview.location} style={preview.blocked ? 'blocked' : 'today'} />
        )}
      </group>
    </>
  )
}

export type { MarkerStyle }
