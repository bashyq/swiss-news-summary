import SwiftUI

/// Visual timeline showing sunny hours from 6am to 8pm.
///
/// Displays a horizontal bar divided into hour segments (6-20).
/// Sunny hours are shown in gold, non-sunny hours in gray.
/// Hour labels appear below at regular intervals.
struct HourlyTimelineView: View {
    /// Array of hour integers (6-20) that have predicted sunshine
    let sunnyHours: [Int]?

    /// Hour range to display
    private let startHour = 6
    private let endHour = 20
    private var totalHours: Int { endHour - startHour }

    /// Set of sunny hours for quick lookup
    private var sunnyHourSet: Set<Int> {
        Set(sunnyHours ?? [])
    }

    var body: some View {
        VStack(spacing: 4) {
            // Timeline bar
            GeometryReader { geo in
                let segmentWidth = geo.size.width / CGFloat(totalHours)

                HStack(spacing: 0) {
                    ForEach(startHour..<endHour, id: \.self) { hour in
                        let isSunny = sunnyHourSet.contains(hour)

                        Rectangle()
                            .fill(isSunny ? Color.orange : Color(.systemGray5))
                            .frame(width: segmentWidth, height: 12)
                            .overlay(
                                // Add subtle borders between segments
                                Rectangle()
                                    .stroke(Color(.systemBackground).opacity(0.3), lineWidth: 0.5)
                            )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 12)

            // Hour labels
            GeometryReader { geo in
                let segmentWidth = geo.size.width / CGFloat(totalHours)

                ZStack(alignment: .leading) {
                    ForEach(labelHours, id: \.self) { hour in
                        let offset = CGFloat(hour - startHour) * segmentWidth + segmentWidth / 2

                        Text("\(hour)")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                            .position(x: offset, y: 6)
                    }
                }
            }
            .frame(height: 12)
        }
    }

    /// Hours where labels are shown (every 2 hours)
    private var labelHours: [Int] {
        stride(from: startHour, through: endHour, by: 2).map { $0 }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Full sunshine
        HourlyTimelineView(sunnyHours: Array(6...19))
            .padding(.horizontal)

        // Partial sunshine
        HourlyTimelineView(sunnyHours: [8, 9, 10, 11, 12, 13, 14])
            .padding(.horizontal)

        // Morning only
        HourlyTimelineView(sunnyHours: [6, 7, 8, 9])
            .padding(.horizontal)

        // No sunshine
        HourlyTimelineView(sunnyHours: [])
            .padding(.horizontal)

        // Nil
        HourlyTimelineView(sunnyHours: nil)
            .padding(.horizontal)
    }
    .padding()
}
