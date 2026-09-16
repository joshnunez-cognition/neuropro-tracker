import Foundation

/// Seed placements for demonstrating the app. Today becomes Day 6 of the cycle.
///
/// Yesterday (Day 5) is the left upper arm, so today the left upper arm is
/// blocked, the right side is recommended, and each earlier location has an
/// exclusion halo around it.
enum DemoData {
    struct Seed {
        var daysAgo: Int
        var regionID: String
        /// Parameter-space location inside the region (normalized height, angle in degrees).
        var height: Float
        var angle: Float
    }

    static let seeds: [Seed] = [
        Seed(daysAgo: 5, regionID: "left_upper_arm", height: 0.75, angle: 60),
        Seed(daysAgo: 4, regionID: "right_abdomen", height: 0.42, angle: -35),
        Seed(daysAgo: 3, regionID: "left_thigh", height: 0.75, angle: 10),
        Seed(daysAgo: 2, regionID: "right_hip", height: 0.15, angle: -140),
        Seed(daysAgo: 1, regionID: "left_upper_arm", height: 0.45, angle: -20),
    ]

    static let cycleStartDaysAgo = 5

    static func placements(
        today: Date, model: HumanBodyModel, cycleManager: CycleManager, calendar: Calendar = .current
    ) -> [Placement] {
        seeds.compactMap { seed in
            guard let region = BodyRegionDefinitions.region(withID: seed.regionID),
                  let patch = region.surfaceDefinition.patches.first,
                  let location = model.surfaceLocation(
                    onPart: patch.meshIdentifier, height: seed.height, angleDegrees: seed.angle),
                  let date = calendar.date(byAdding: .day, value: -seed.daysAgo, to: today)
            else { return nil }
            let stamped = calendar.date(bySettingHour: 8, minute: 3, second: 0, of: date) ?? date
            return Placement(
                date: stamped,
                cycleID: cycleManager.cycleID(for: stamped),
                cycleDay: cycleManager.cycleDay(for: stamped),
                regionID: region.id,
                regionName: region.name,
                side: region.side,
                surfaceLocation: location)
        }
    }
}
