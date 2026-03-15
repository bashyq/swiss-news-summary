import SwiftUI

/// State of a travel connector in execution mode.
enum ConnectorExecState {
    case browsing     // Default — normal dashed line + chip
    case done         // Completed — 40% opacity
    case upcoming     // Between done slot and active slot — urgent terracotta style
    case future       // Not yet reached — 50% opacity
}

/// Vertical dashed line + travel chip capsule between two agenda slots.
struct TravelConnectorView: View {
    let travelNote: String?
    let travelMinutes: Int?
    var execState: ConnectorExecState = .browsing
    var isTight: Bool = false
    var nextVenueName: String?

    var body: some View {
        HStack(spacing: 10) {
            // Vertical dashed line
            dashedLine
                .frame(width: 2, height: execState == .upcoming ? 40 : 32)
                .padding(.leading, 14) // align with slot card timeline dot

            // Travel chip
            if isTight, let minutes = travelMinutes {
                tightChip(minutes: minutes)
            } else if let note = travelNote, !note.isEmpty {
                travelChip(note)
            } else if let minutes = travelMinutes, execState == .upcoming {
                // In upcoming state, show travel time even without note
                travelChip("\(minutes) min")
            }

            Spacer()
        }
        .opacity(connectorOpacity)
    }

    private var connectorOpacity: Double {
        switch execState {
        case .browsing: return 1.0
        case .done: return 0.4
        case .upcoming: return 1.0
        case .future: return 0.5
        }
    }

    private func tightChip(minutes: Int) -> some View {
        HStack(spacing: 5) {
            Text("⚠️")
                .font(.system(size: 10))
            Text("Tight — \(minutes) min\(nextVenueName.map { " to \($0)" } ?? "")")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(Color.znNegative)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.znNegative.opacity(0.07))
        .overlay(
            Capsule()
                .stroke(Color.znNegative.opacity(0.2), lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func travelChip(_ text: String) -> some View {
        if execState == .upcoming {
            // Urgent style — terracotta bg with icon
            HStack(spacing: 5) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 10))
                Text(text)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(Color.znTerracotta)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.znTerracotta.opacity(0.1))
            .overlay(
                Capsule()
                    .stroke(Color.znTerracotta.opacity(0.2), lineWidth: 1)
            )
            .clipShape(Capsule())
        } else {
            // Default style
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(Color.znMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.znBorder.opacity(0.5))
                .clipShape(Capsule())
        }
    }

    private var dashedLine: some View {
        GeometryReader { geo in
            Path { path in
                let dashLength: CGFloat = 3
                let gapLength: CGFloat = 3
                var y: CGFloat = 0
                while y < geo.size.height {
                    path.move(to: CGPoint(x: 1, y: y))
                    path.addLine(to: CGPoint(x: 1, y: min(y + dashLength, geo.size.height)))
                    y += dashLength + gapLength
                }
            }
            .stroke(lineColor, lineWidth: 2)
        }
    }

    private var lineColor: Color {
        switch execState {
        case .upcoming: return Color.znTerracotta
        case .done: return Color.znPositive
        default: return Color.znBorder
        }
    }
}
