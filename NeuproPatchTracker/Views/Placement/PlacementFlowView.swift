import SwiftUI

/// Full-screen body interaction: rotate → tap → validate → preview → confirm.
struct PlacementFlowView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    let editing: PlacementSnapshot?

    @State private var flow: PlacementFlowModel?
    @State private var controller = BodyInteractionController()
    @State private var sceneReady = false
    @State private var showConfirmation = false
    @State private var showManualPicker = false
    @State private var saveError: String?
    @State private var saved = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()

                if let flow {
                    BodyViewer(controller: controller, onTap: { result in
                        flow.handleTap(result)
                        syncScene(flow)
                        if case .marker = result { } else if flow.candidate != nil {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } else {
                            UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        }
                    }, onReady: {
                        sceneReady = true
                        syncScene(flow)
                        if let editing {
                            controller.focus(on: editing.surfaceLocation, animated: false)
                        }
                    })
                    .ignoresSafeArea(edges: .bottom)
                    .accessibilityIdentifier("bodyViewer")

                    VStack(spacing: 0) {
                        topOverlay(flow)
                        Spacer()
                        bottomPanel(flow)
                    }

                    if !sceneReady {
                        ProgressView("Preparing body model…")
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .navigationTitle(editing == nil ? "Log Today's Patch" : "Change Today's Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancelPlacement")
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Front view") { controller.rotate(toYawDegrees: 0) }
                        Button("Right side") { controller.rotate(toYawDegrees: 90) }
                        Button("Back view") { controller.rotate(toYawDegrees: 180) }
                        Button("Left side") { controller.rotate(toYawDegrees: -90) }
                        Divider()
                        Button("Reset zoom") { controller.resetView() }
                        Button("Choose area manually…") { showManualPicker = true }
                    } label: {
                        Image(systemName: "rotate.3d")
                            .accessibilityLabel("View options")
                    }
                    .accessibilityIdentifier("viewOptionsMenu")
                }
            }
        }
        .task {
            if flow == nil {
                flow = PlacementFlowModel(appModel: appModel, editing: editing)
            }
        }
        .sheet(isPresented: $showManualPicker) {
            if let flow {
                ManualRegionPickerView(flow: flow) { region in
                    flow.selectRegionCenter(region)
                    syncScene(flow)
                    if let candidate = flow.candidate {
                        controller.focus(on: candidate.surfaceLocation)
                    }
                }
            }
        }
        .sheet(isPresented: $showConfirmation) {
            if let flow {
                ConfirmPlacementSheet(flow: flow) {
                    do {
                        _ = try flow.confirm()
                        saved = true
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        showConfirmation = false
                        dismiss()
                    } catch {
                        saveError = error.localizedDescription
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .alert("Couldn't save", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: - Overlays

    @ViewBuilder
    private func topOverlay(_ flow: PlacementFlowModel) -> some View {
        VStack(spacing: 8) {
            if flow.candidate == nil && !controller.hasRotated {
                Label("Swipe to rotate • Tap where you placed the patch", systemImage: "hand.draw")
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .transition(.opacity)
            }
            legend(flow)
        }
        .padding(.top, 8)
        .animation(.easeInOut, value: controller.hasRotated)
    }

    private func legend(_ flow: PlacementFlowModel) -> some View {
        HStack(spacing: 12) {
            legendDot(.available, "Available")
            if appModel.recommendedSide != nil { legendDot(.recommended, "Suggested") }
            legendDot(.unavailable, "Yesterday")
        }
        .font(.caption2)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private func legendDot(_ state: RegionAvailability, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(Color(RegionMaterials.color(for: state))).frame(width: 8, height: 8)
            Text(label)
        }
    }

    @ViewBuilder
    private func bottomPanel(_ flow: PlacementFlowModel) -> some View {
        VStack(spacing: 12) {
            if let inspected = flow.inspectedPlacement {
                inspectedCard(inspected, flow: flow)
            } else {
                feedbackView(flow)
            }

            HStack(spacing: 12) {
                if flow.candidate != nil {
                    Button("Clear") {
                        flow.clearSelection()
                        syncScene(flow)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("clearSelection")
                }
                Button {
                    showConfirmation = true
                } label: {
                    Text("Confirm Placement")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.orange)
                .disabled(!flow.canConfirm)
                .accessibilityIdentifier("confirmPlacementButton")
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
        .padding(.bottom, 8)
        .animation(.snappy, value: flow.feedback)
    }

    @ViewBuilder
    private func feedbackView(_ flow: PlacementFlowModel) -> some View {
        switch flow.feedback {
        case .none:
            HStack(spacing: 10) {
                Image(systemName: "hand.tap").font(.title3).foregroundStyle(.secondary)
                Text("Tap a highlighted area on the body where you applied today's patch.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .accessibilityIdentifier("feedbackNone")
        case .blocked(let title, let message):
            InfoBanner(kind: .error, title: title, message: message)
                .accessibilityIdentifier("feedbackBlocked")
        case .recommendation(let title, let message):
            VStack(alignment: .leading, spacing: 8) {
                if let candidate = flow.candidate {
                    selectedHeader(candidate)
                }
                InfoBanner(kind: .info, title: title, message: message)
            }
            .accessibilityIdentifier("feedbackRecommendation")
        case .ready(let regionName, let side):
            HStack {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title3)
                Text(regionName).font(.headline)
                SideBadge(side: side)
                Spacer()
            }
            .accessibilityIdentifier("feedbackReady")
        }
    }

    private func selectedHeader(_ candidate: PlacementCandidate) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title3)
            Text(candidate.region.name).font(.headline)
            SideBadge(side: candidate.region.side)
            Spacer()
        }
    }

    private func inspectedCard(_ placement: PlacementSnapshot, flow: PlacementFlowModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Previous placement").font(.caption).foregroundStyle(.secondary)
                Text(placement.regionName).font(.headline)
                Text(placement.date, format: .dateTime.weekday(.wide).month().day())
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            SideBadge(side: placement.side)
            Button {
                flow.dismissInspection()
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .accessibilityLabel("Dismiss")
        }
    }

    // MARK: - Scene sync

    private func syncScene(_ flow: PlacementFlowModel) {
        guard sceneReady else { return }
        controller.setRegionAvailability(flow.regionAvailability)
        controller.showPlacements(
            flow.historyForScene, focused: flow.inspectedPlacement?.id,
            exclusionRadius: appModel.rules.exclusionRadius)
        controller.showPreview(at: flow.candidate?.surfaceLocation, blocked: flow.previewIsBlocked)
    }
}

// MARK: - Confirmation

struct ConfirmPlacementSheet: View {
    let flow: PlacementFlowModel
    var onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if let candidate = flow.candidate {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Location").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Text(candidate.region.name).font(.title2.bold())
                            SideBadge(side: candidate.region.side)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Date").font(.caption).foregroundStyle(.secondary)
                        Text(Date(), format: .dateTime.weekday(.wide).month().day())
                            .font(.body)
                        Text("Cycle day \(flow.appModel.cycleManager.cycleDay(for: flow.appModel.today))")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if let recommendation = flow.validation?.recommendations.first {
                        InfoBanner(kind: .info, title: recommendation.title, message: recommendation.message)
                    }
                }
                Spacer()
                Button {
                    onConfirm()
                } label: {
                    Text(flow.editing == nil ? "Save Placement" : "Update Placement")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.orange)
                .accessibilityIdentifier("savePlacementButton")
            }
            .padding()
            .navigationTitle("Confirm Placement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Accessibility fallback

struct ManualRegionPickerView: View {
    let flow: PlacementFlowModel
    var onSelect: (BodyRegion) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Choosing an area here places the patch marker at the center of that area. For an exact location, tap the body directly.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(BodyRegionDefinitions.all) { region in
                    let state = flow.regionAvailability[region.id] ?? .available
                    Button {
                        onSelect(region)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: state.symbolName)
                                .foregroundStyle(Color(RegionMaterials.color(for: state)))
                            Text(region.name)
                            Spacer()
                            Text(state.label).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .disabled(state == .unavailable)
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Choose Area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
