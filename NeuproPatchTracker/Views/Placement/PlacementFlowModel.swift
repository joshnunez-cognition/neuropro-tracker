import Foundation
import Observation

/// Drives the body-based placement flow: selection → validation → preview → confirmation.
/// Contains no SwiftUI or RealityKit code so it can be unit tested.
@MainActor
@Observable
final class PlacementFlowModel {
    enum Feedback: Equatable {
        case none
        case blocked(title: String, message: String)
        case recommendation(title: String, message: String)
        case ready(regionName: String, side: BodySide)
    }

    let appModel: AppModel
    let editing: PlacementSnapshot?

    private(set) var candidate: PlacementCandidate?
    private(set) var validation: PlacementValidationResult?
    private(set) var feedback: Feedback = .none
    private(set) var inspectedPlacement: PlacementSnapshot?

    init(appModel: AppModel, editing: PlacementSnapshot?) {
        self.appModel = appModel
        self.editing = editing
        if let editing {
            candidate = BodyRegionDefinitions.region(withID: editing.regionID).map {
                PlacementCandidate(region: $0, surfaceLocation: editing.surfaceLocation)
            }
            if let candidate {
                validation = appModel.validator.validate(
                    candidate: candidate, history: appModel.placements, on: appModel.today, excluding: editing.id)
                feedback = .ready(regionName: candidate.region.name, side: candidate.region.side)
            }
        }
    }

    var excludedID: UUID? { editing?.id }

    var canConfirm: Bool {
        guard let validation, candidate != nil else { return false }
        return validation.isValid
    }

    var previewIsBlocked: Bool {
        guard let validation else { return false }
        return !validation.isValid
    }

    /// Everything shown as a historical marker in the scene (excludes the placement being edited).
    var historyForScene: [PlacementSnapshot] {
        appModel.activeWindowPlacements.filter { $0.id != excludedID }
    }

    var regionAvailability: [String: RegionAvailability] {
        var availability = appModel.regionAvailability(excluding: excludedID)
        if let candidate, validation?.isValid == true {
            availability[candidate.region.id] = .selected
        }
        return availability
    }

    // MARK: - Interaction

    func handleTap(_ result: BodyTapResult) {
        inspectedPlacement = nil
        switch result {
        case .miss:
            reject(.outsideApprovedRegion)
        case .marker(let id):
            inspectedPlacement = appModel.placement(withID: id)
        case .surface(let location):
            select(location: location)
        }
    }

    func select(location: SurfaceLocation) {
        guard let region = appModel.mapper.region(for: location) else {
            reject(.outsideApprovedRegion)
            return
        }
        let newCandidate = PlacementCandidate(region: region, surfaceLocation: location)
        let result = appModel.validator.validate(
            candidate: newCandidate, history: appModel.placements, on: appModel.today, excluding: excludedID)
        candidate = newCandidate
        validation = result

        if let block = result.blockingReasons.first {
            feedback = .blocked(title: block.title, message: block.message)
        } else if let recommendation = result.recommendations.first {
            feedback = .recommendation(title: recommendation.title, message: recommendation.message)
        } else {
            feedback = .ready(regionName: region.name, side: region.side)
        }
    }

    /// Fallback for users who cannot use the 3D body: pick a representative point in a region.
    func selectRegionCenter(_ region: BodyRegion) {
        guard let patch = region.surfaceDefinition.patches.first,
              let location = appModel.bodyModel.surfaceLocation(
                onPart: patch.meshIdentifier,
                height: (patch.heightRange.lowerBound + patch.heightRange.upperBound) / 2,
                angleDegrees: (patch.angleRange.lowerBound + patch.angleRange.upperBound) / 2)
        else { return }
        select(location: location)
    }

    private func reject(_ reason: PlacementValidationReason) {
        candidate = nil
        validation = nil
        feedback = .blocked(title: reason.title, message: reason.message)
    }

    func clearSelection() {
        candidate = nil
        validation = nil
        feedback = .none
    }

    func dismissInspection() {
        inspectedPlacement = nil
    }

    func confirm() throws -> PlacementSnapshot {
        guard let candidate, canConfirm else {
            throw ConfirmationError.invalidCandidate
        }
        return try appModel.confirm(candidate: candidate, on: Date(), replacing: excludedID)
    }

    enum ConfirmationError: Error {
        case invalidCandidate
    }
}
