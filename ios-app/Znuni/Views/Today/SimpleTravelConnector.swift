import SwiftUI

/// Dashed line + travel chip between consecutive agenda slots.
struct SimpleTravelConnector: View {
    let estimate: TravelEstimate

    var body: some View {
        HStack(spacing: 8) {
            // Dashed vertical line
            dashedLine

            // Travel chip
            travelChip
        }
        .padding(.leading, 14)
    }

    // MARK: - Dashed Line

    private var dashedLine: some View {
        Line()
            .stroke(
                Color.znBorder,
                style: StrokeStyle(lineWidth: 2, dash: [3, 3])
            )
            .frame(width: 2, height: 32)
    }

    // MARK: - Travel Chip

    private var travelChip: some View {
        HStack(spacing: 4) {
            Image(systemName: estimate.mode == .walking ? "figure.walk" : "tram.fill")
                .font(.system(size: 10))

            Text("\(estimate.minutes) min \(modeLabel)")
                .font(.system(size: 11))
        }
        .foregroundStyle(.znMuted)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.znBorder.opacity(0.5))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.znBorder.opacity(0.2), lineWidth: 1)
        )
    }

    private var modeLabel: String {
        estimate.mode == .walking ? "walk" : "tram"
    }
}

// MARK: - Line Shape

/// A simple vertical line shape for the dashed connector.
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}
