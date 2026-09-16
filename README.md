# NEUPRO Patch Placement Tracker (iPhone MVP)

A native iPhone app for remembering where a daily NEUPRO® (rotigotine) patch was
placed. The primary interface is an interactive 3D human body: rotate it with a
swipe, tap where the patch went, review the preview and validation feedback, then
confirm. The app runs fully on-device with no account, backend, or sync.

> This app helps remember patch locations. It does not provide medical advice,
> dosage guidance, or treatment recommendations. Follow the prescriber's
> directions and the official NEUPRO patient information.

## Stack

- Swift 5 / SwiftUI, iOS 18+
- RealityKit (`RealityView`) for the interactive body, hit testing, and markers
- SwiftData for local persistence
- Swift Testing for unit tests
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project from `project.yml`

## Getting started

```sh
brew install xcodegen          # once
xcodegen generate              # produces NeuproPatchTracker.xcodeproj
open NeuproPatchTracker.xcodeproj
```

Pick an iPhone simulator and Run. Command line equivalents:

```sh
# Build + unit tests
xcodebuild -project NeuproPatchTracker.xcodeproj -scheme NeuproPatchTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' test

# Launch with sample history (6 days into a cycle) or with an in-memory store
xcrun simctl launch booted com.neupro.tracker.NeuproPatchTracker -demo-data
xcrun simctl launch booted com.neupro.tracker.NeuproPatchTracker -ui-testing
```

If `xcodebuild` cannot find a simulator destination because the installed runtime
build differs from the SDK's expected build, map it once:
`xcrun simctl runtime match set iphoneos<version> <installed-runtime-build>`.

## Architecture

```
NeuproPatchTracker/
  App/        NeuproPatchTrackerApp, AppModel (observable app state), RootView (tabs)
  Models/     Placement (SwiftData), TrackerSettings, BodyRegion, BodySide,
              SurfaceLocation, PlacementValidationResult
  Domain/     PlacementValidator, PlacementRecommendationEngine,
              PlacementDistanceCalculator, CycleManager, PlacementConfiguration
  Data/       PlacementRepository (+ SwiftData implementation),
              BodyRegionDefinitions (single source of approved regions), DemoData
  Body/       HumanBodyModel (procedural geometry + surface parameterization),
              BodyRegionMapper (surface point -> region)
  Body/RealityKit/  HumanBodyScene, BodyInteractionController, BodyViewer,
              PatchMarkerRenderer
  Views/      Onboarding, Today, Placement flow, Tracker, History, Settings
NeuproPatchTrackerTests/   validator, cycle, body model, persistence tests
```

Domain rules never import RealityKit or SwiftUI; the 3D layer only produces
`SurfaceLocation`s and renders state it is handed.

### Placement rules (see `PlacementConfiguration`)

| Rule | Behaviour | Source |
| --- | --- | --- |
| Same exact spot within 14 days | **Blocked** (exclusion radius around stored point) | NEUPRO tracker PDF: "do not use the same spot for 14 days" |
| Same broad region as yesterday | **Blocked** | Product requirement |
| Same side as yesterday | Allowed, opposite-side **recommendation** shown | Product requirement |
| Outside an approved region | Rejected | NEUPRO tracker PDF shaded areas |

The exclusion radius (`0.05` body units ≈ 5 cm) and the region boundaries in
`BodyRegionDefinitions.swift` are engineering estimates eyeballed against the
official artwork and **require clinical/product validation** before real-world use.

### Stable coordinates

A placement stores a `SurfaceLocation`: the body part id plus the tapped point and
surface normal in body space. All parts share the body root's frame, so distances
between placements are plain Euclidean distances and historical markers can be
re-attached to the surface on any launch.

## Body model

The body is generated procedurally (`HumanBodyProportions`): each part is a stack of
elliptical cross-sections lofted into a mesh (~1.75 m adult, neutral build). This
was chosen over an external asset because:

- there is no licensing ambiguity (no third-party mesh is shipped),
- every point on the surface has a deterministic `(height, angle)` parameter, which
  makes region definitions and tests simple and reviewable,
- it is tiny and fast on iPhone.

Selectable parts are the torso, upper arms, and upper legs; head, neck, forearms,
hands, lower legs, and feet are rendered but not selectable.

### Replacing it with a licensed USDZ

1. Load the asset with `Entity(named:)`/`ModelEntity.load` in `HumanBodyScene.build`
   and add it under `built.body` at the identity transform, scaled to metres.
2. Give each selectable mesh a `BodyPartComponent(partID:)` and a collision shape
   (`ShapeResource.generateStaticMesh`).
3. Provide a `HumanBodyModel` whose `BodyPart`s approximate each selectable mesh
   (sections along the limb axis) so `surfaceParameters(for:)` and
   `BodyRegionMapper` keep working, or implement a new mapper that classifies hit
   points directly (e.g. by vertex colour/material id).
4. Record source, license, and any modifications here.

## Testing

`xcodebuild ... test` runs 33 unit tests covering the validator (14-day exact spot,
exclusion radius, yesterday-region block, side recommendation), cycle math
(Day 14 → Day 1), body surface round-trips and mesh orientation, and SwiftData
persistence (save/reload, edit, delete, clear, demo data, settings).

Accessibility identifiers (`logTodayButton`, `bodyViewer`, `confirmPlacementButton`,
`savePlacementButton`, `trackerDay1`…`trackerDay14`, …) are in place for UI tests.

## Out of scope

Authentication, backend/cloud sync, clinician dashboards, EHR or pharmacy
integrations, dosage/symptom tracking, analytics, and any medical recommendation.
This project makes no HIPAA compliance claims.
