import Foundation
import Observation
import SwiftData

/// Application state shared by all screens. Loads history from the repository and
/// exposes derived, domain-computed values to the UI.
@MainActor
@Observable
final class AppModel {
    let repository: PlacementRepository
    let bodyModel: HumanBodyModel
    let mapper: BodyRegionMapper
    let calendar: Calendar

    private(set) var placements: [PlacementSnapshot] = []
    private(set) var settings: TrackerSettings?
    private(set) var loadError: String?

    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    init(
        repository: PlacementRepository,
        bodyModel: HumanBodyModel = .standard,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.bodyModel = bodyModel
        self.mapper = BodyRegionMapper(model: bodyModel, regions: BodyRegionDefinitions.all)
        self.calendar = calendar
        reload()
    }

    // MARK: - Derived domain services

    var rules: PlacementRules {
        var rules = PlacementConfiguration.defaultRules
        rules.sideRecommendationEnabled = settings?.sideRecommendationEnabled ?? true
        return rules
    }

    var validator: PlacementValidator { PlacementValidator(rules: rules, calendar: calendar) }
    var recommendationEngine: PlacementRecommendationEngine { PlacementRecommendationEngine(calendar: calendar) }

    var cycleManager: CycleManager {
        CycleManager(
            startDate: settings?.cycleStartDate ?? calendar.startOfDay(for: Date()),
            calendar: calendar)
    }

    var today: Date { calendar.startOfDay(for: Date()) }

    var todayPlacement: PlacementSnapshot? {
        placements.first { calendar.isDate($0.date, inSameDayAs: today) }
    }

    var yesterdayPlacement: PlacementSnapshot? {
        recommendationEngine.yesterdayPlacement(history: placements, on: today)
    }

    var recommendedSide: BodySide? {
        guard rules.sideRecommendationEnabled else { return nil }
        return recommendationEngine.recommendedSide(history: placements, on: today)
    }

    func placements(inCycleContaining date: Date) -> [PlacementSnapshot] {
        let id = cycleManager.cycleID(for: date)
        return placements.filter { $0.cycleID == id }
    }

    /// Placements that still affect validation today (rolling window).
    var activeWindowPlacements: [PlacementSnapshot] {
        validator.recentPlacements(history: placements, on: today)
    }

    func regionAvailability(excluding excludedID: UUID? = nil) -> [String: RegionAvailability] {
        recommendationEngine.regionAvailability(
            regions: mapper.regions, history: placements, on: today,
            excluding: excludedID, sideRecommendationEnabled: rules.sideRecommendationEnabled)
    }

    func placement(withID id: UUID) -> PlacementSnapshot? {
        placements.first { $0.id == id }
    }

    // MARK: - Mutations

    func reload() {
        do {
            settings = try repository.settings()
            placements = try repository.placements().map(\.snapshot).sorted { $0.date < $1.date }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    @discardableResult
    func confirm(candidate: PlacementCandidate, on date: Date = Date(), replacing existingID: UUID? = nil) throws -> PlacementSnapshot {
        let manager = cycleManager
        if let existingID, let existing = try repository.placements().first(where: { $0.id == existingID }) {
            existing.regionID = candidate.region.id
            existing.regionName = candidate.region.name
            existing.side = candidate.region.side
            existing.surfaceLocation = candidate.surfaceLocation
            try repository.update(existing)
            reload()
            return existing.snapshot
        }
        let placement = Placement(
            date: date,
            cycleID: manager.cycleID(for: date),
            cycleDay: manager.cycleDay(for: date),
            regionID: candidate.region.id,
            regionName: candidate.region.name,
            side: candidate.region.side,
            surfaceLocation: candidate.surfaceLocation)
        try repository.save(placement)
        reload()
        return placement.snapshot
    }

    func delete(placementID: UUID) throws {
        if let existing = try repository.placements().first(where: { $0.id == placementID }) {
            try repository.delete(existing)
        }
        reload()
    }

    func updateSettings(_ mutate: (TrackerSettings) -> Void) throws {
        guard let settings else { return }
        mutate(settings)
        try repository.saveSettings()
        reload()
    }

    func clearAllHistory() throws {
        try repository.clear()
        reload()
    }

    func loadDemoData() throws {
        try repository.clear()
        let start = calendar.date(byAdding: .day, value: -DemoData.cycleStartDaysAgo, to: today) ?? today
        try updateSettings { $0.cycleStartDate = start }
        for placement in DemoData.placements(today: today, model: bodyModel, cycleManager: cycleManager, calendar: calendar) {
            try repository.save(placement)
        }
        reload()
    }
}

extension AppModel {
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([Placement.self, TrackerSettings.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
