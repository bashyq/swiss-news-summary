import SwiftUI

struct TripNudgeCard: View {
    let trip: DetectedTrip
    let onPlan: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AWAY FROM HOME")
                .font(.znEyebrow)
                .foregroundStyle(.white.opacity(0.6))

            Text("\(trip.eventTitle) in \(trip.locality)")
                .font(.cardHeadline)
                .foregroundStyle(.white)

            if let freeTimeText = freeTimeDescription {
                Text(freeTimeText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            HStack(spacing: 10) {
                Button(action: onPlan) {
                    Text("Plan my day in \(trip.locality)")
                        .font(.znLabel)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(.znLabel)
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer()
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .fill(Color.znNavy)
        }
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        .padding(.horizontal, 16)
    }

    private var freeTimeDescription: String? {
        guard let start = trip.startTime, let end = trip.endTime else {
            return "Explore the area for the whole day"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)
        return "You're free before \(startStr) and after \(endStr)"
    }
}
