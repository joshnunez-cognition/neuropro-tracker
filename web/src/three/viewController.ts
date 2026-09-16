import type * as THREE from 'three'
import type { SurfaceLocation } from '../models'
import { yawFacing } from './bodyGeometry'

export type Orientation = 'front' | 'left' | 'back' | 'right'

export const ORIENTATION_YAW: Record<Orientation, number> = {
  front: 0,
  // Body +X is the patient's left; rotating the body by -90° brings it toward the camera.
  left: -Math.PI / 2,
  back: Math.PI,
  right: Math.PI / 2,
}

export interface RaycastBridge {
  raycast(clientX: number, clientY: number): THREE.Intersection[]
  bodyGroup: THREE.Group
}

/**
 * Framework-agnostic view state for the body: yaw (rotation about the vertical
 * axis), zoom and vertical look target. Smoothed toward targets each frame.
 */
export class BodyViewController {
  yaw = 0
  targetYaw = 0
  zoom = 1
  targetZoom = 1
  lookY: number
  targetLookY: number
  readonly baseDistance: number
  bridge: RaycastBridge | null = null
  onInteract?: () => void

  constructor(readonly bodyHeight: number) {
    this.lookY = this.targetLookY = bodyHeight * 0.52
    this.baseDistance = bodyHeight * 1.55
  }

  get distance(): number { return this.baseDistance / this.zoom }

  rotateBy(radians: number) { this.targetYaw += radians; this.onInteract?.() }

  rotateTo(orientation: Orientation) {
    const desired = ORIENTATION_YAW[orientation]
    this.targetYaw = nearestEquivalent(this.targetYaw, desired)
  }

  zoomBy(factor: number) {
    this.targetZoom = Math.min(3.5, Math.max(1, this.targetZoom * factor))
    if (this.targetZoom === 1) this.targetLookY = this.bodyHeight * 0.52
  }

  panY(delta: number) {
    if (this.targetZoom <= 1.05) return
    this.targetLookY = Math.min(this.bodyHeight * 0.95, Math.max(this.bodyHeight * 0.1, this.targetLookY + delta))
  }

  reset() {
    this.targetYaw = nearestEquivalent(this.targetYaw, 0)
    this.targetZoom = 1
    this.targetLookY = this.bodyHeight * 0.52
  }

  /** Rotate so `loc` faces the camera and zoom in slightly on it. */
  focus(loc: SurfaceLocation) {
    this.targetYaw = nearestEquivalent(this.targetYaw, yawFacing(loc))
    this.targetZoom = 1.6
    this.targetLookY = loc.y
  }

  /** Advance smoothing; returns true while still animating. */
  step(dt: number): boolean {
    const k = 1 - Math.exp(-dt * 10)
    this.yaw += (this.targetYaw - this.yaw) * k
    this.zoom += (this.targetZoom - this.zoom) * k
    this.lookY += (this.targetLookY - this.lookY) * k
    return Math.abs(this.targetYaw - this.yaw) > 1e-3 || Math.abs(this.targetZoom - this.zoom) > 1e-3
      || Math.abs(this.targetLookY - this.lookY) > 1e-4
  }

  /** Current orientation label for accessibility / UI. */
  get orientation(): Orientation {
    const a = ((this.targetYaw % (2 * Math.PI)) + 2 * Math.PI) % (2 * Math.PI)
    const q = Math.round(a / (Math.PI / 2)) % 4
    return (['front', 'right', 'back', 'left'] as Orientation[])[q]
  }
}

function nearestEquivalent(current: number, desired: number): number {
  const twoPi = 2 * Math.PI
  let d = desired
  while (d - current > Math.PI) d -= twoPi
  while (current - d > Math.PI) d += twoPi
  return d
}
