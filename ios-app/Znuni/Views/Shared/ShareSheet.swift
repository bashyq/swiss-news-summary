import SwiftUI
import UIKit

/// Native iOS share sheet wrapped for SwiftUI.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { activityType, completed, _, _ in
            if completed {
                let method: String
                switch activityType {
                case .message:
                    method = "messages"
                case .copyToPasteboard:
                    method = "copy"
                default:
                    if activityType?.rawValue.contains("whatsapp") == true {
                        method = "whatsapp"
                    } else {
                        method = activityType?.rawValue ?? "other"
                    }
                }
                ZnuniEvent.planShared(method: method)
            }
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Button that triggers a share sheet with a formatted plan summary.
struct SharePlanButton: View {
    let agenda: DayAgenda
    let city: String
    @State private var showShareSheet = false

    var body: some View {
        Button {
            showShareSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .medium))
                Text("Share this plan")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(Color.znNavy)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.znNeutralTagBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.znBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [PlanShareFormatter.format(agenda, city: city)])
        }
    }
}
