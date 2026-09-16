import Foundation
import SwiftData
import Testing
@testable import NeuproPatchTracker

@MainActor
struct PersistenceTests {
    private func makeModel() throws -> (AppModel, ModelContainer) {
        let container = try AppModel.makeContainer(inMemory: true)
        let repository = SwiftDataPlacementRepository(context: container.mainContext)
        return (AppModel(repository: repository), container)
    }

    private func candidate(_ regionID: String) -> PlacementCandidate {
        let region = BodyRegionDefinitions.region(withID: regionID)!
        let patch = region.surfaceDefinition.patches.first!
        let location = HumanBodyModel.standard.surfaceLocation(
            onPart: patch.meshIdentifier,
            height: (patch.heightRange.lowerBound + patch.heightRange.upperBound) / 2,
            angleDegrees: (patch.angleRange.lowerBound + patch.angleRange.upperBound) / 2)!
        return PlacementCandidate(region: region, surfaceLocation: location)
    }

    @Test func savedPlacementSurvivesReloadFromSameStore() throws {
        let (appModel, container) = try makeModel()
        let saved = try appModel.confirm(candidate: candidate("left_abdomen"))
        #expect(appModel.todayPlacement?.id == saved.id)
        #expect(appModel.todayPlacement?.surfaceLocation == saved.surfaceLocation)

        // A second AppModel on the same container simulates relaunch.
        let again = AppModel(repository: SwiftDataPlacementRepository(context: container.mainContext))
        #expect(again.placements.count == 1)
        #expect(again.placements.first?.regionID == "left_abdomen")
        #expect(again.placements.first?.surfaceLocation == saved.surfaceLocation)
    }

    @Test func editReplacesInsteadOfDuplicating() throws {
        let (appModel, container) = try makeModel()
        defer { withExtendedLifetime(container) {} }
        let first = try appModel.confirm(candidate: candidate("left_abdomen"))
        let edited = try appModel.confirm(candidate: candidate("right_thigh"), replacing: first.id)
        #expect(edited.id == first.id)
        #expect(appModel.placements.count == 1)
        #expect(appModel.todayPlacement?.regionID == "right_thigh")
    }

    @Test func deleteAndClear() throws {
        let (appModel, container) = try makeModel()
        defer { withExtendedLifetime(container) {} }
        let saved = try appModel.confirm(candidate: candidate("left_abdomen"))
        try appModel.delete(placementID: saved.id)
        #expect(appModel.placements.isEmpty)
        try appModel.loadDemoData()
        #expect(appModel.placements.count == DemoData.seeds.count)
        try appModel.clearAllHistory()
        #expect(appModel.placements.isEmpty)
    }

    @Test func demoDataProducesExpectedTodayState() throws {
        let (appModel, container) = try makeModel()
        defer { withExtendedLifetime(container) {} }
        try appModel.loadDemoData()
        #expect(appModel.cycleManager.cycleDay(for: appModel.today) == DemoData.cycleStartDaysAgo + 1)
        #expect(appModel.yesterdayPlacement?.regionID == "left_upper_arm")
        #expect(appModel.recommendedSide == .right)
        #expect(appModel.regionAvailability()["left_upper_arm"] == .unavailable)
    }

    @Test func settingsPersistToggle() throws {
        let (appModel, container) = try makeModel()
        try appModel.updateSettings { $0.sideRecommendationEnabled = false }
        let again = AppModel(repository: SwiftDataPlacementRepository(context: container.mainContext))
        #expect(again.settings?.sideRecommendationEnabled == false)
        #expect(again.rules.sideRecommendationEnabled == false)
    }
}
