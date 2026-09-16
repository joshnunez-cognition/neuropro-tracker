import { BodyPartId } from '../body/humanBodyModel'
import type { Region } from '../models'

/**
 * Approved NEUPRO placement areas mapped onto the procedural body.
 *
 * The shaded areas on the official NEUPRO Patch Placement Tracker
 * (https://www.neupro.com/neupro-patch-placement-tracker.pdf) are: shoulder /
 * upper arm, abdomen (a band around the waist), hip / flank (seen from the side
 * and back) and the front of the thigh, each on the left and right.
 *
 * Boundaries are expressed in each body part's parameter space (normalized
 * height + angle around the part axis, see `SurfacePatch`). They were eyeballed
 * against the tracker artwork and REQUIRE CLINICAL/PRODUCT VALIDATION before
 * real-world use. Adjust the numbers here; nothing else needs to change.
 */
export const bodyRegions: Region[] = [
  region('left_upper_arm', 'Left upper arm', 'left', BodyPartId.leftUpperArm, [0.08, 1.0], [-180, 180]),
  region('right_upper_arm', 'Right upper arm', 'right', BodyPartId.rightUpperArm, [0.08, 1.0], [-180, 180]),
  region('left_abdomen', 'Left abdomen', 'left', BodyPartId.torso, [0.26, 0.52], [8, 105]),
  region('right_abdomen', 'Right abdomen', 'right', BodyPartId.torso, [0.26, 0.52], [-105, -8]),
  region('left_hip', 'Left hip', 'left', BodyPartId.torso, [0.04, 0.24], [95, 180]),
  region('right_hip', 'Right hip', 'right', BodyPartId.torso, [0.04, 0.24], [-180, -95]),
  region('left_thigh', 'Left thigh', 'left', BodyPartId.leftUpperLeg, [0.3, 0.92], [-75, 75]),
  region('right_thigh', 'Right thigh', 'right', BodyPartId.rightUpperLeg, [0.3, 0.92], [-75, 75]),
]

function region(
  id: string, name: string, side: Region['side'], meshId: string,
  heightRange: [number, number], angleRange: [number, number],
): Region {
  return { id, name, side, surfaceDefinition: { patches: [{ meshId, heightRange, angleRange }] } }
}

export function regionById(id: string): Region | undefined {
  return bodyRegions.find((r) => r.id === id)
}
