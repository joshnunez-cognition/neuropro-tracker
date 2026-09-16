import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var appModel
    @State private var pendingDelete: PlacementSnapshot?
    @State private var error: String?

    private var grouped: [(cycleID: String, number: Int, items: [PlacementSnapshot])] {
        let manager = appModel.cycleManager
        let groups = Dictionary(grouping: appModel.placements, by: \.cycleID)
        return groups.map { key, items in
            let number = items.first.map { manager.cycleNumber(for: $0.date) } ?? 0
            return (cycleID: key, number: number, items: items.sorted { $0.date > $1.date })
        }
        .sorted { $0.number > $1.number }
    }

    var body: some View {
        NavigationStack {
            Group {
                if appModel.placements.isEmpty {
                    ContentUnavailableView(
                        "No placements yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Placements you log will appear here, grouped by 14-day cycle."))
                } else {
                    List {
                        ForEach(grouped, id: \.cycleID) { group in
                            Section("Cycle \(group.number)") {
                                ForEach(group.items) { placement in
                                    PlacementRow(placement: placement)
                                        .swipeActions {
                                            Button(role: .destructive) {
                                                pendingDelete = placement
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .confirmationDialog(
                "Delete this placement?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let pendingDelete {
                        do { try appModel.delete(placementID: pendingDelete.id) } catch { self.error = error.localizedDescription }
                    }
                    pendingDelete = nil
                }
            } message: {
                Text("Removing a placement means the app will no longer warn you about that spot.")
            }
            .alert("Couldn't delete", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(error ?? "") }
        }
    }
}
