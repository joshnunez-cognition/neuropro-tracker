import type { PlacementRules } from '../models'

/** Rotation cycle length and look-back window for the exact-location rule. */
export const ROTATION_WINDOW_DAYS = 14

/**
 * Radius (metres, body-model space; model is ~1.75 m tall) around a recent
 * placement that counts as "the same spot".
 *
 * MVP engineering parameter only — NOT clinically or product validated.
 * Calibrate before any real-world use.
 */
export const EXCLUSION_RADIUS = 0.05

export const defaultRules: PlacementRules = {
  rotationWindowDays: ROTATION_WINDOW_DAYS,
  exclusionRadius: EXCLUSION_RADIUS,
  sideRecommendationEnabled: true,
}
