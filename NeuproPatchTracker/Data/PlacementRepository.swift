import Foundation
import SwiftData

protocol PlacementRepository {
    func placements() throws -> [Placement]
    func save(_ placement: Placement) throws
    func update(_ placement: Placement) throws
    func delete(_ placement: Placement) throws
    func clear() throws

    func settings() throws -> TrackerSettings
    func saveSettings() throws
}

final class SwiftDataPlacementRepository: PlacementRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func placements() throws -> [Placement] {
        let descriptor = FetchDescriptor<Placement>(sortBy: [SortDescriptor(\.date, order: .forward)])
        return try context.fetch(descriptor)
    }

    func save(_ placement: Placement) throws {
        context.insert(placement)
        try context.save()
    }

    func update(_ placement: Placement) throws {
        try context.save()
    }

    func delete(_ placement: Placement) throws {
        context.delete(placement)
        try context.save()
    }

    func clear() throws {
        // Deleting one by one keeps other live model instances (settings) valid;
        // `delete(model:)` performs a batch delete that resets the context.
        for placement in try placements() {
            context.delete(placement)
        }
        try context.save()
    }

    func settings() throws -> TrackerSettings {
        var descriptor = FetchDescriptor<TrackerSettings>()
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let created = TrackerSettings(cycleStartDate: Calendar.current.startOfDay(for: Date()))
        context.insert(created)
        try context.save()
        return created
    }

    func saveSettings() throws {
        try context.save()
    }
}
