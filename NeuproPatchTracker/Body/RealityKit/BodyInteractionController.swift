import Foundation
import Observation
import RealityKit
import SwiftUI
import simd

/// What the viewer reports back to the owning screen after a tap.
enum BodyTapResult {
    case surface(SurfaceLocation)
    case marker(placementID: UUID)
    case miss
}

/// Owns the RealityKit scene for the body viewer: rotation, zoom, hit-testing and markers.
@MainActor
@Observable
final class BodyInteractionController {
    let model: HumanBodyModel
    let mapper: BodyRegionMapper

    private(set) var isReady = false

    private var content: RealityViewCameraContent?
    private var built: HumanBodyScene.Built?
    private var camera = PerspectiveCamera()
    private var markers: [Entity] = []
    private var previewMarker: Entity?

    // Interaction state
    private var yaw: Float = 0
    private var yawAtDragStart: Float = 0
    private var cameraDistance: Float = 2.9
    private var distanceAtPinchStart: Float = 2.9
    private var lookHeight: Float = 0.92
    private var lookHeightAtDragStart: Float = 0.92

    var hasRotated = false

    init(model: HumanBodyModel = .standard, mapper: BodyRegionMapper = BodyRegionMapper()) {
        self.model = model
        self.mapper = mapper
    }

    // MARK: - Scene setup

    func attach(to incoming: RealityViewCameraContent) async {
        var content = incoming
        guard built == nil else {
            self.content = content
            return
        }
        do {
            let built = try await HumanBodyScene.build(model: model, mapper: mapper)
            self.built = built
            content.add(built.root)
            for light in HumanBodyScene.makeLighting() {
                content.add(light)
            }
            content.camera = .virtual
            content.add(camera)
            updateCamera()
            self.content = content
            isReady = true
        } catch {
            assertionFailure("Body scene failed to build: \(error)")
        }
    }

    func refreshContent(_ content: RealityViewCameraContent) {
        self.content = content
    }

    private func updateCamera() {
        let position = SIMD3<Float>(0, lookHeight + 0.05, cameraDistance)
        camera.look(at: SIMD3(0, lookHeight, 0), from: position, relativeTo: nil)
        camera.camera.fieldOfViewInDegrees = 42
    }

    // MARK: - Gestures

    func dragBegan() {
        built?.root.stopAllAnimations()
        yawAtDragStart = yaw
        lookHeightAtDragStart = lookHeight
    }

    func dragChanged(translation: CGSize, viewWidth: CGFloat) {
        guard viewWidth > 0 else { return }
        // A full swipe across the view rotates ~ 300°.
        let radiansPerPoint = Float(2 * Double.pi * 0.85 / Double(viewWidth))
        yaw = yawAtDragStart + Float(translation.width) * radiansPerPoint
        applyYaw(animated: false)
        if abs(translation.width) > 12 { hasRotated = true }

        // Allow vertical inspection when zoomed in.
        if cameraDistance < 2.4 {
            let perPoint = Float(0.0012) * (cameraDistance / 2.9)
            lookHeight = clamp(lookHeightAtDragStart + Float(translation.height) * perPoint, 0.45, 1.5)
            updateCamera()
        }
    }

    func dragEnded(predictedTranslation: CGSize, translation: CGSize, viewWidth: CGFloat) {
        guard viewWidth > 0 else { return }
        let radiansPerPoint = Float(2 * Double.pi * 0.85 / Double(viewWidth))
        let extra = Float(predictedTranslation.width - translation.width) * radiansPerPoint * 0.35
        yaw += extra
        applyYaw(animated: true, duration: 0.45)
    }

    func pinchBegan() {
        distanceAtPinchStart = cameraDistance
    }

    func pinchChanged(magnification: CGFloat) {
        guard magnification > 0 else { return }
        cameraDistance = clamp(distanceAtPinchStart / Float(magnification), 1.3, 3.6)
        if cameraDistance >= 2.4 { lookHeight = 0.92 }
        updateCamera()
    }

    func resetView(animated: Bool = true) {
        cameraDistance = 2.9
        lookHeight = 0.92
        updateCamera()
        yaw = 0
        applyYaw(animated: animated)
    }

    /// Rotate to a canonical view. 0 = front, +90 shows the patient's right side.
    func rotate(toYawDegrees degrees: Float) {
        yaw = degrees * .pi / 180
        applyYaw(animated: true)
    }

    private func applyYaw(animated: Bool, duration: TimeInterval = 0.6) {
        guard let root = built?.root else { return }
        let target = Transform(scale: .one, rotation: simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0)), translation: .zero)
        if animated {
            root.move(to: target, relativeTo: root.parent, duration: duration, timingFunction: .easeOut)
        } else {
            root.transform = target
        }
    }

    /// Rotate so `location` faces the camera.
    func focus(on location: SurfaceLocation, animated: Bool = true) {
        let p = model.bodySpacePosition(for: location)
        let n = location.normal
        // Direction to present: mostly the surface normal, biased by the position around the axis.
        let dir = simd_normalize(SIMD3<Float>(n.x, 0, n.z) * 0.7 + simd_normalize(SIMD3<Float>(p.x, 0, p.z) + SIMD3(0, 0, 0.0001)) * 0.3)
        // The camera looks down -Z, so we want dir rotated to +Z: yaw = -atan2(dir.x, dir.z).
        yaw = -atan2(dir.x, dir.z)
        applyYaw(animated: animated)
    }

    // MARK: - Hit testing

    func tap(at point: CGPoint) -> BodyTapResult {
        guard let content, let built else { return .miss }
        let hits = content.hitTest(point: point, in: .local, query: .all, mask: .all)
        guard !hits.isEmpty else { return .miss }

        // Prefer markers so historical placements can be inspected.
        for hit in hits {
            if let marker = hit.entity.components[PlacementMarkerComponent.self] {
                return .marker(placementID: marker.placementID)
            }
        }
        for hit in hits.sorted(by: { $0.distance < $1.distance }) {
            guard let part = hit.entity.components[BodyPartComponent.self] else { continue }
            let local = built.body.convert(position: hit.position, from: nil)
            let normal = built.body.convert(normal: hit.normal, from: nil)
            return .surface(SurfaceLocation(meshIdentifier: part.partID, position: local, normal: normal))
        }
        return .miss
    }

    // MARK: - Visual state

    func setRegionAvailability(_ availability: [String: RegionAvailability]) {
        guard let built else { return }
        for (regionID, overlay) in built.overlays {
            let state = availability[regionID] ?? .available
            overlay.model?.materials = [RegionMaterials.material(for: state)]
        }
    }

    func showPlacements(_ placements: [PlacementSnapshot], focused focusedID: UUID? = nil, exclusionRadius: Float?) {
        guard let built else { return }
        markers.forEach { $0.removeFromParent() }
        markers.removeAll()
        for placement in placements {
            let style: PatchMarkerStyle = placement.id == focusedID ? .focused : .history
            let marker = PatchMarkerRenderer.makeMarker(
                at: placement.surfaceLocation, style: style, placementID: placement.id,
                exclusionRadius: exclusionRadius)
            built.body.addChild(marker)
            markers.append(marker)
        }
    }

    func showPreview(at location: SurfaceLocation?, blocked: Bool = false) {
        previewMarker?.removeFromParent()
        previewMarker = nil
        guard let location, let built else { return }
        let marker = PatchMarkerRenderer.makeMarker(
            at: location, style: blocked ? .blocked : .today, placementID: nil, exclusionRadius: nil)
        built.body.addChild(marker)
        previewMarker = marker
    }

    private func clamp(_ v: Float, _ lo: Float, _ hi: Float) -> Float { min(max(v, lo), hi) }
}
