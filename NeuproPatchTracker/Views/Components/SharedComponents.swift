import SwiftUI

struct SideBadge: View {
    let side: BodySide

    var body: some View {
        Text(side.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(side == .left ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15), in: Capsule())
            .foregroundStyle(side == .left ? .blue : .purple)
    }
}

struct PlacementRow: View {
    let placement: PlacementSnapshot
    var showDate = true

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.18))
                Text("\(placement.cycleDay)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.orange)
            }
            .frame(width: 40, height: 40)
            .accessibilityLabel("Day \(placement.cycleDay)")

            VStack(alignment: .leading, spacing: 2) {
                Text(placement.regionName).font(.body.weight(.medium))
                if showDate {
                    Text(placement.date, format: .dateTime.weekday(.wide).month().day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            SideBadge(side: placement.side)
        }
    }
}

struct InfoBanner: View {
    enum Kind { case info, warning, success, error }
    let kind: Kind
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .font(.title3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch kind {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    private var tint: Color {
        switch kind {
        case .info: return .blue
        case .warning: return .orange
        case .success: return .green
        case .error: return .red
        }
    }
}

struct MedicalDisclaimerFooter: View {
    var body: some View {
        Text("This app helps you remember where you placed your patch. It does not provide medical advice. Follow your prescriber's directions and the NEUPRO patient information.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }
}
