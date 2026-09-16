import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var showClearConfirm = false
    @State private var showDemoConfirm = false
    @State private var reminderEnabled = false
    @State private var reminderTime = Date()
    @State private var reminderStatus: String?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Cycle") {
                    DatePicker(
                        "Cycle start date",
                        selection: Binding(
                            get: { appModel.settings?.cycleStartDate ?? appModel.today },
                            set: { newValue in
                                try? appModel.updateSettings { $0.cycleStartDate = Calendar.current.startOfDay(for: newValue) }
                            }),
                        displayedComponents: .date)
                    LabeledContent("Today", value: "Day \(appModel.cycleManager.cycleDay(for: appModel.today)) of 14")
                }

                Section {
                    Toggle(
                        "Suggest alternating sides",
                        isOn: Binding(
                            get: { appModel.settings?.sideRecommendationEnabled ?? true },
                            set: { newValue in try? appModel.updateSettings { $0.sideRecommendationEnabled = newValue } }))
                } header: {
                    Text("Guidance")
                } footer: {
                    Text("When on, the app suggests using the opposite side from yesterday. This is a reminder only and never blocks a valid placement.")
                }

                Section {
                    Toggle("Daily reminder", isOn: $reminderEnabled)
                        .onChange(of: reminderEnabled) { _, on in
                            Task { await updateReminder(enabled: on) }
                        }
                    if reminderEnabled {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .onChange(of: reminderTime) { _, _ in
                                Task { await updateReminder(enabled: true) }
                            }
                    }
                    if let reminderStatus {
                        Text(reminderStatus).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Reminder")
                } footer: {
                    Text("A local notification reminding you to log today's patch location.")
                }

                Section("Rules") {
                    LabeledContent("Look-back window", value: "\(PlacementConfiguration.rotationWindowDays) days")
                    LabeledContent("Exact-spot exclusion", value: String(format: "%.0f cm", PlacementConfiguration.exclusionRadius * 100))
                    Text("Approved areas and rule thresholds are configured centrally in the app and are based on the NEUPRO patch placement tracker. They are not a substitute for your prescriber's instructions.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Data") {
                    Button("Load sample history") { showDemoConfirm = true }
                    Button("Clear all history", role: .destructive) { showClearConfirm = true }
                        .accessibilityIdentifier("clearHistoryButton")
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    Link("NEUPRO patch placement tracker (PDF)", destination: URL(string: "https://www.neupro.com/neupro-patch-placement-tracker.pdf")!)
                    Text("All data stays on this device. This app does not provide medical advice.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Clear all placement history?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) {
                    do { try appModel.clearAllHistory() } catch { self.error = error.localizedDescription }
                }
            }
            .confirmationDialog("Replace history with sample data?", isPresented: $showDemoConfirm, titleVisibility: .visible) {
                Button("Load Sample History", role: .destructive) {
                    do { try appModel.loadDemoData() } catch { self.error = error.localizedDescription }
                }
            } message: {
                Text("This replaces your current history with five sample placements for exploring the app.")
            }
            .alert("Something went wrong", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(error ?? "") }
            .task { await loadReminderState() }
        }
    }

    private func loadReminderState() async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        reminderEnabled = requests.contains { $0.identifier == ReminderScheduler.identifier }
        if let settings = appModel.settings {
            var components = DateComponents()
            components.hour = settings.reminderHour
            components.minute = settings.reminderMinute
            reminderTime = Calendar.current.date(from: components) ?? Date()
        }
    }

    private func updateReminder(enabled: Bool) async {
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        try? appModel.updateSettings {
            $0.reminderHour = components.hour ?? 8
            $0.reminderMinute = components.minute ?? 0
        }
        do {
            if enabled {
                let granted = try await ReminderScheduler.schedule(hour: components.hour ?? 8, minute: components.minute ?? 0)
                reminderStatus = granted ? nil : "Notifications are not allowed. Enable them in iOS Settings."
                if !granted { reminderEnabled = false }
            } else {
                ReminderScheduler.cancel()
                reminderStatus = nil
            }
        } catch {
            reminderStatus = error.localizedDescription
        }
    }
}

enum ReminderScheduler {
    static let identifier = "neupro.daily.reminder"

    static func schedule(hour: Int, minute: Int) async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        guard granted else { return false }
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        let content = UNMutableNotificationContent()
        content.title = "Log today's patch"
        content.body = "Record where you placed your NEUPRO patch today."
        content.sound = .default
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        return true
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
