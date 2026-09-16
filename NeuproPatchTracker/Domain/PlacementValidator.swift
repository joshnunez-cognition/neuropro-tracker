import Foundation

/// Applies the placement rules to a candidate.
///
/// Hard blocks:
/// 1. The effective exact location was used within the rotation window.
/// 2. The broader region was used yesterday.
///
/// Soft recommendation:
/// - Alternate sides relative to yesterday.
struct PlacementValidator: Sendable {
    var rules: PlacementRules
    var calendar: Calendar

    init(rules: PlacementRules = PlacementConfiguration.defaultRules, calendar: Calendar = .current) {
        self.rules = rules
        self.calendar = calendar
    }

    func validate(
        candidate: PlacementCandidate,
        history: [PlacementSnapshot],
        on date: Date,
        excluding excludedID: UUID? = nil
    ) -> PlacementValidationResult {
        let relevant = history.filter { $0.id != excludedID }

        var blocking: [PlacementValidationReason] = []
        var recommendations: [PlacementRecommendation] = []

        if let recent = recentPlacement(near: candidate.surfaceLocation, history: relevant, on: date) {
            blocking.append(.recentlyUsedLocation(daysAgo: daysAgo(recent.date, from: date)))
        }

        if let yesterday = placement(usedYesterday: candidate.region.id, history: relevant, on: date) {
            blocking.append(.regionUsedYesterday(regionName: yesterday.regionName))
        }

        if rules.sideRecommendationEnabled,
           let preferred = PlacementRecommendationEngine(calendar: calendar)
                .recommendedSide(history: relevant, on: date),
           preferred != candidate.region.side {
            recommendations.append(.alternateSide(preferred: preferred))
        }

        return PlacementValidationResult(blockingReasons: blocking, recommendations: recommendations)
    }

    // MARK: - Individual rules

    func wasLocationUsedWithin14Days(
        _ location: SurfaceLocation, history: [PlacementSnapshot], on date: Date
    ) -> Bool {
        recentPlacement(near: location, history: history, on: date) != nil
    }

    func wasRegionUsedYesterday(_ regionID: String, history: [PlacementSnapshot], on date: Date) -> Bool {
        placement(usedYesterday: regionID, history: history, on: date) != nil
    }

    /// Placements inside the rotation window (today through `rotationWindowDays` days ago).
    func recentPlacements(history: [PlacementSnapshot], on date: Date) -> [PlacementSnapshot] {
        history.filter { (0...rules.rotationWindowDays).contains(daysAgo($0.date, from: date)) }
    }

    func recentPlacement(
        near location: SurfaceLocation, history: [PlacementSnapshot], on date: Date
    ) -> PlacementSnapshot? {
        recentPlacements(history: history, on: date)
            .filter {
                $0.surfaceLocation.meshIdentifier == location.meshIdentifier
                    && PlacementDistanceCalculator.isWithinExclusionRadius(
                        $0.surfaceLocation, location, radius: rules.exclusionRadius)
            }
            .min { daysAgo($0.date, from: date) < daysAgo($1.date, from: date) }
    }

    func placement(usedYesterday regionID: String, history: [PlacementSnapshot], on date: Date) -> PlacementSnapshot? {
        history.first { daysAgo($0.date, from: date) == 1 && $0.regionID == regionID }
    }

    func daysAgo(_ past: Date, from date: Date) -> Int {
        CycleManager.daysBetween(past, date, calendar: calendar)
    }
}
