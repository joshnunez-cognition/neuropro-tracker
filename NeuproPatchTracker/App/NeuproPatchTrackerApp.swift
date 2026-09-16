import SwiftData
import SwiftUI

@main
struct NeuproPatchTrackerApp: App {
    private let container: ModelContainer
    @State private var appModel: AppModel

    init() {
        let inMemory = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        do {
            container = try AppModel.makeContainer(inMemory: inMemory)
        } catch {
            fatalError("Unable to create SwiftData container: \(error)")
        }
        let repository = SwiftDataPlacementRepository(context: container.mainContext)
        let model = AppModel(repository: repository)
        if ProcessInfo.processInfo.arguments.contains("-demo-data") {
            try? model.loadDemoData()
            model.hasCompletedOnboarding = true
        }
        _appModel = State(initialValue: model)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
        }
        .modelContainer(container)
    }
}
