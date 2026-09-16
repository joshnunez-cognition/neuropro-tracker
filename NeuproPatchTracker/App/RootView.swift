import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @State private var showOnboarding = false

    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max.fill") {
                TodayView()
            }
            Tab("Tracker", systemImage: "calendar") {
                TrackerView()
            }
            Tab("History", systemImage: "clock.arrow.circlepath") {
                HistoryView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .onAppear {
            showOnboarding = !appModel.hasCompletedOnboarding
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                appModel.hasCompletedOnboarding = true
                showOnboarding = false
            }
        }
    }
}
