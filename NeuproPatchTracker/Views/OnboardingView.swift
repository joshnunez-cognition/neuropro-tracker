import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void
    @State private var page = 0

    private let pages: [(symbol: String, title: String, body: String)] = [
        ("figure.stand", "Track where your patch goes",
         "This app helps you keep track of where you placed your NEUPRO patch each day, using an interactive body instead of a form."),
        ("hand.draw", "Rotate, tap, confirm",
         "Swipe to rotate the body, tap the spot where you applied today's patch, review the preview, then confirm."),
        ("arrow.triangle.2.circlepath", "14-day rotation",
         "Your history is kept for a rolling 14-day cycle. The app flags spots used in the last 14 days and areas used yesterday."),
        ("stethoscope", "Not medical advice",
         "Always follow the placement directions from your prescriber and the NEUPRO patient information. This app does not give dosing or treatment recommendations."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    VStack(spacing: 24) {
                        Spacer()
                        Image(systemName: pages[index].symbol)
                            .font(.system(size: 88, weight: .light))
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                        Text(pages[index].title)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                        Text(pages[index].body)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < pages.count - 1 ? "Continue" : "Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)

            if page < pages.count - 1 {
                Button("Skip") { onFinish() }
                    .padding(.bottom, 16)
            } else {
                Color.clear.frame(height: 44)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}
