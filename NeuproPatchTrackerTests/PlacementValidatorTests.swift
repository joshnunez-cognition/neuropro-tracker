import Foundation
import Testing
@testable import NeuproPatchTracker

struct PlacementValidatorTests {
    let calendar = Calendar(identifier: .gregorian)
    let model = HumanBodyModel.standard
    let today = Calendar(identifier: .gregorian).startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))

    private func region(_ id: String) -> BodyRegion { BodyRegionDefinitions.region(withID: id)! }

    private func location(_ regionID: String, height: Float? = nil, angle: Float? = nil) -> SurfaceLocation {
        let patch = region(regionID).surfaceDefinition.patches.first!
        let h = height ?? (patch.heightRange.lowerBound + patch.heightRange.upperBound) / 2
        let a = angle ?? (patch.angleRange.lowerBound + patch.angleRange.upperBound) / 2
        return model.surfaceLocation(onPart: patch.meshIdentifier, height: h, angleDegrees: a)!
    }

    private func snapshot(_ regionID: String, daysAgo: Int, location: SurfaceLocation? = nil) -> PlacementSnapshot {
        let r = region(regionID)
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
        return PlacementSnapshot(
            id: UUID(), date: date, cycleID: "c", cycleDay: 1, regionID: r.id, regionName: r.name, side: r.side,
            surfaceLocation: location ?? self.location(regionID))
    }

    private var validator: PlacementValidator {
        PlacementValidator(rules: PlacementConfiguration.defaultRules, calendar: calendar)
    }

    @Test func emptyHistoryIsValid() {
        let candidate = PlacementCandidate(region: region("left_abdomen"), surfaceLocation: location("left_abdomen"))
        let result = validator.validate(candidate: candidate, history: [], on: today)
        #expect(result.isValid)
        #expect(result.recommendations.isEmpty)
    }

    @Test func exactLocationWithin14DaysIsBlocked() {
        let history = [snapshot("left_abdomen", daysAgo: 9)]
        let candidate = PlacementCandidate(region: region("left_abdomen"), surfaceLocation: location("left_abdomen"))
        let result = validator.validate(candidate: candidate, history: history, on: today)
        #expect(!result.isValid)
        #expect(result.blockingReasons.contains(.recentlyUsedLocation(daysAgo: 9)))
    }

    @Test func nearbyLocationWithinRadiusIsBlocked() {
        let used = location("left_abdomen")
        // Nudge by less than the exclusion radius.
        let nudged = SurfaceLocation(
            meshIdentifier: used.meshIdentifier,
            position: used.position + SIMD3<Float>(0, PlacementConfiguration.exclusionRadius * 0.5, 0),
            normal: used.normal)
        let history = [snapshot("left_abdomen", daysAgo: 5, location: used)]
        let candidate = PlacementCandidate(region: region("left_abdomen"), surfaceLocation: nudged)
        #expect(!validator.validate(candidate: candidate, history: history, on: today).isValid)
    }

    @Test func sameRegionDifferentSpotIsAllowedAfterYesterday() {
        // Same broad area used 3 days ago: allowed as long as the exact spot differs.
        let used = location("left_abdomen", height: 0.35)
        let other = location("left_abdomen", height: 0.9)
        #expect(PlacementDistanceCalculator.distance(between: used, and: other) > PlacementConfiguration.exclusionRadius)
        let history = [snapshot("left_abdomen", daysAgo: 3, location: used)]
        let candidate = PlacementCandidate(region: region("left_abdomen"), surfaceLocation: other)
        #expect(validator.validate(candidate: candidate, history: history, on: today).isValid)
    }

    @Test func locationOlderThan14DaysIsAllowed() {
        let history = [snapshot("left_abdomen", daysAgo: 15)]
        let candidate = PlacementCandidate(region: region("left_abdomen"), surfaceLocation: location("left_abdomen"))
        #expect(validator.validate(candidate: candidate, history: history, on: today).isValid)
    }

    @Test func locationExactly14DaysAgoIsStillBlocked() {
        let history = [snapshot("left_abdomen", daysAgo: 14)]
        let candidate = PlacementCandidate(region: region("left_abdomen"), surfaceLocation: location("left_abdomen"))
        #expect(!validator.validate(candidate: candidate, history: history, on: today).isValid)
    }

    @Test func regionUsedYesterdayIsBlockedEvenAtDifferentSpot() {
        let history = [snapshot("right_thigh", daysAgo: 1, location: location("right_thigh", height: 0.3))]
        let candidate = PlacementCandidate(region: region("right_thigh"), surfaceLocation: location("right_thigh", height: 0.9))
        let result = validator.validate(candidate: candidate, history: history, on: today)
        #expect(!result.isValid)
        #expect(result.blockingReasons.contains(.regionUsedYesterday(regionName: "Right thigh")))
    }

    @Test func regionUsedTwoDaysAgoIsNotBlockedByRegionRule() {
        let history = [snapshot("right_thigh", daysAgo: 2, location: location("right_thigh", height: 0.3))]
        let candidate = PlacementCandidate(region: region("right_thigh"), surfaceLocation: location("right_thigh", height: 0.9))
        #expect(validator.validate(candidate: candidate, history: history, on: today).isValid)
    }

    @Test func sameSideAsYesterdayProducesRecommendationOnly() {
        let history = [snapshot("left_upper_arm", daysAgo: 1)]
        let candidate = PlacementCandidate(region: region("left_thigh"), surfaceLocation: location("left_thigh"))
        let result = validator.validate(candidate: candidate, history: history, on: today)
        #expect(result.isValid)
        #expect(result.recommendations == [.alternateSide(preferred: .right)])
    }

    @Test func oppositeSideHasNoRecommendation() {
        let history = [snapshot("left_upper_arm", daysAgo: 1)]
        let candidate = PlacementCandidate(region: region("right_thigh"), surfaceLocation: location("right_thigh"))
        let result = validator.validate(candidate: candidate, history: history, on: today)
        #expect(result.isValid)
        #expect(result.recommendations.isEmpty)
    }

    @Test func sideRecommendationCanBeDisabled() {
        var rules = PlacementConfiguration.defaultRules
        rules.sideRecommendationEnabled = false
        let v = PlacementValidator(rules: rules, calendar: calendar)
        let history = [snapshot("left_upper_arm", daysAgo: 1)]
        let candidate = PlacementCandidate(region: region("left_thigh"), surfaceLocation: location("left_thigh"))
        #expect(v.validate(candidate: candidate, history: history, on: today).recommendations.isEmpty)
    }

    @Test func editingExcludesOwnPlacement() {
        let mine = snapshot("left_abdomen", daysAgo: 0)
        let candidate = PlacementCandidate(region: region("left_abdomen"), surfaceLocation: mine.surfaceLocation)
        #expect(!validator.validate(candidate: candidate, history: [mine], on: today).isValid)
        #expect(validator.validate(candidate: candidate, history: [mine], on: today, excluding: mine.id).isValid)
    }

    @Test func regionAvailabilityClassification() {
        let engine = PlacementRecommendationEngine(calendar: calendar)
        let history = [snapshot("left_upper_arm", daysAgo: 1)]
        let availability = engine.regionAvailability(
            regions: BodyRegionDefinitions.all, history: history, on: today, excluding: nil,
            sideRecommendationEnabled: true)
        #expect(availability["left_upper_arm"] == .unavailable)
        #expect(availability["right_upper_arm"] == .recommended)
        #expect(availability["right_thigh"] == .recommended)
        #expect(availability["left_thigh"] == .available)
    }
}
