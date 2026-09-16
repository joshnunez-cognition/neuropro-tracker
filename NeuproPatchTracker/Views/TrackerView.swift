import SwiftUI

/// 14-day grid for the current cycle plus a read-only body showing the cycle's markers.
struct TrackerView: View {
    @Environment(AppModel.self) private var appModel
    @State private var selectedDay: Int?
    @State private var controller = BodyInteractionController()
    @State private var sceneReady = false

    private var manager: CycleManager { appModel.cycleManager }
    private var cyclePlacements: [PlacementSnapshot] { appModel.placements(inCycleContaining: appModel.today) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    grid
                    bodyPreview
                    if let selectedDay, let placement = placement(forDay: selectedDay) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Day \(selectedDay)").font(.headline)
                            PlacementRow(placement: placement)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("14-Day Tracker")
            .onAppear { syncScene() }
            .onChange(of: appModel.placements) { syncScene() }
            .onChange(of: selectedDay) { syncScene() }
        }
    }

    private var header: some View {
        let today = manager.cycleDay(for: appModel.today)
        return VStack(alignment: .leading, spacing: 4) {
            Text("Cycle \(manager.cycleNumber(for: appModel.today)) • Day \(today) of 14").font(.headline)
            Text("Started \(manager.startDate(ofCycleContaining: appModel.today), format: .dateTime.month().day())")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var grid: some View {
        let todayDay = manager.cycleDay(for: appModel.today)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
            ForEach(1...14, id: \.self) { day in
                let placement = placement(forDay: day)
                let isToday = day == todayDay
                let isFuture = day > todayDay
                Button {
                    selectedDay = selectedDay == day ? nil : day
                } label: {
                    VStack(spacing: 4) {
                        Text("\(day)")
                            .font(.subheadline.weight(isToday ? .bold : .regular).monospacedDigit())
                        if let placement {
                            Image(systemName: "bandage.fill")
                                .font(.caption)
                                .foregroundStyle(placement.side == .left ? .blue : .purple)
                        } else if isFuture {
                            Image(systemName: "circle.dotted").font(.caption).foregroundStyle(.tertiary)
                        } else {
                            Image(systemName: "minus").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedDay == day ? Color.orange.opacity(0.25) : Color(.secondarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isToday ? Color.orange : .clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(day: day, placement: placement, isToday: isToday))
                .accessibilityIdentifier("trackerDay\(day)")
            }
        }
    }

    private var bodyPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This cycle on the body").font(.headline)
            BodyViewer(controller: controller, onTap: { result in
                if case .marker(let id) = result,
                   let placement = appModel.placement(withID: id) {
                    selectedDay = placement.cycleDay
                }
            }, onReady: {
                sceneReady = true
                syncScene()
            })
            .frame(height: 360)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            Text("Swipe to rotate. Tap a marker to see its day.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func placement(forDay day: Int) -> PlacementSnapshot? {
        cyclePlacements.first { $0.cycleDay == day }
    }

    private func accessibilityLabel(day: Int, placement: PlacementSnapshot?, isToday: Bool) -> String {
        var label = "Day \(day)"
        if isToday { label += ", today" }
        if let placement { label += ", \(placement.regionName)" } else { label += ", not logged" }
        return label
    }

    private func syncScene() {
        guard sceneReady else { return }
        controller.setRegionAvailability([:])
        controller.showPlacements(
            cyclePlacements,
            focused: selectedDay.flatMap { placement(forDay: $0)?.id },
            exclusionRadius: nil)
        if let selectedDay, let placement = placement(forDay: selectedDay) {
            controller.focus(on: placement.surfaceLocation)
        }
    }
}
