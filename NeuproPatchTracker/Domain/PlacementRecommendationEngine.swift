import Foundation

/// Non-blocking guidance derived from placement history.
struct PlacementRecommendationEngine: Sendable {
    var calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func yesterdayPlacement(history: [PlacementSnapshot], on date: Date) -> PlacementSnapshot? {
        history.first { CycleManager.daysBetween($0.date, date, calendar: calendar) == 1 }
    }

    /// The side opposite yesterday's placement, or nil when there is no yesterday.
    func recommendedSide(history: [PlacementSnapshot], on date: Date) -> BodySide? {
        yesterdayPlacement(history: history, on: date)?.side.opposite
    }

    /// Availability of each approved region for `date`, for visualising the body.
    func regionAvailability(
        regions: [BodyRegion],
        history: [PlacementSnapshot],
        on date: Date,
        excluding excludedID: UUID? = nil,
        sideRecommendationEnabled: Bool = true
    ) -> [String: RegionAvailability] {
        let relevant = history.filter { $0.id != excludedID }
        let yesterday = yesterdayPlacement(history: relevant, on: date)
        let preferredSide = sideRecommendationEnabled ? yesterday?.side.opposite : nil

        var result: [String: RegionAvailability] = [:]
        for region in regions {
            if let yesterday, yesterday.regionID == region.id {
                result[region.id] = .unavailable
            } else if let preferredSide, region.side == preferredSide {
                result[region.id] = .recommended
            } else {
                result[region.id] = .available
            }
        }
        return result
    }
}
