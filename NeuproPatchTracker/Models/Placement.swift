import Foundation
import SwiftData

@Model
final class Placement {
    @Attribute(.unique) var id: UUID

    var date: Date
    var cycleID: String
    var cycleDay: Int

    var regionID: String
    var regionName: String

    var side: BodySide

    var surfaceLocation: SurfaceLocation

    init(
        id: UUID = UUID(),
        date: Date,
        cycleID: String,
        cycleDay: Int,
        regionID: String,
        regionName: String,
        side: BodySide,
        surfaceLocation: SurfaceLocation
    ) {
        self.id = id
        self.date = date
        self.cycleID = cycleID
        self.cycleDay = cycleDay
        self.regionID = regionID
        self.regionName = regionName
        self.side = side
        self.surfaceLocation = surfaceLocation
    }

    var snapshot: PlacementSnapshot {
        PlacementSnapshot(
            id: id, date: date, cycleID: cycleID, cycleDay: cycleDay,
            regionID: regionID, regionName: regionName, side: side,
            surfaceLocation: surfaceLocation)
    }
}

/// Immutable value copy of a placement used by the domain layer so that rules
/// can be tested without SwiftData.
struct PlacementSnapshot: Identifiable, Hashable, Sendable {
    var id: UUID
    var date: Date
    var cycleID: String
    var cycleDay: Int
    var regionID: String
    var regionName: String
    var side: BodySide
    var surfaceLocation: SurfaceLocation
}

/// A proposed placement that has been resolved to a region but not yet validated or saved.
struct PlacementCandidate: Hashable, Sendable {
    var region: BodyRegion
    var surfaceLocation: SurfaceLocation
}

@Model
final class TrackerSettings {
    var cycleStartDate: Date
    var sideRecommendationEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int

    init(
        cycleStartDate: Date,
        sideRecommendationEnabled: Bool = true,
        reminderHour: Int = 8,
        reminderMinute: Int = 0
    ) {
        self.cycleStartDate = cycleStartDate
        self.sideRecommendationEnabled = sideRecommendationEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
    }
}
