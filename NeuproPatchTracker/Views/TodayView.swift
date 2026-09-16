import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var appModel
    @State private var showPlacementFlow = false
    @State private var editingPlacement: PlacementSnapshot?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    cycleCard
                    yesterdayCard
                    todayCard
                    MedicalDisclaimerFooter().padding(.top, 8)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
            .fullScreenCover(isPresented: $showPlacementFlow) {
                PlacementFlowView(editing: nil)
            }
            .fullScreenCover(item: $editingPlacement) { placement in
                PlacementFlowView(editing: placement)
            }
        }
    }

    private var cycleCard: some View {
        let manager = appModel.cycleManager
        let day = manager.cycleDay(for: appModel.today)
        let logged = appModel.placements(inCycleContaining: appModel.today).count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("14-day cycle").font(.headline)
                Spacer()
                Text("Cycle \(manager.cycleNumber(for: appModel.today))")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Day \(day)").font(.system(size: 40, weight: .bold, design: .rounded))
                Text("of 14").font(.title3).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(day), total: 14)
                .tint(.orange)
            Text("\(logged) of \(day) day\(day == 1 ? "" : "s") logged this cycle")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cycleCard")
    }

    @ViewBuilder
    private var yesterdayCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Yesterday").font(.headline)
            if let yesterday = appModel.yesterdayPlacement {
                PlacementRow(placement: yesterday, showDate: false)
                if let side = appModel.recommendedSide {
                    Label("Suggestion: use your \(side.displayName.lowercased()) side today", systemImage: "arrow.left.arrow.right")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                Text("No placement logged yesterday.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let todayPlacement = appModel.todayPlacement {
                Label("Today's patch is logged", systemImage: "checkmark.seal.fill")
                    .font(.headline).foregroundStyle(.green)
                PlacementRow(placement: todayPlacement, showDate: false)
                Button {
                    editingPlacement = todayPlacement
                } label: {
                    Label("Change today's location", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("changeTodayButton")
            } else {
                Text("Today's patch").font(.headline)
                Text("Apply your patch, then log where you placed it.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button {
                    showPlacementFlow = true
                } label: {
                    Label("Log Today's Patch", systemImage: "figure.stand")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.orange)
                .accessibilityIdentifier("logTodayButton")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
