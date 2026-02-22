import SwiftUI

// MARK: - Toast Type

enum ToastType {
    case success
    case error
    case info

    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        }
    }

    var sfSymbol: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

// MARK: - Toast Manager

@Observable
final class ToastManager {
    var message: String = ""
    var type: ToastType = .success
    var isShowing: Bool = false

    func show(_ message: String, type: ToastType = .success) {
        self.message = message
        self.type = type

        withAnimation(.spring(duration: 0.3)) {
            self.isShowing = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.spring(duration: 0.3)) {
                self.isShowing = false
            }
        }
    }
}

// MARK: - Toast Overlay

struct ToastOverlay: View {
    @Environment(ToastManager.self) private var toastManager

    var body: some View {
        if toastManager.isShowing {
            HStack(spacing: 8) {
                Image(systemName: toastManager.type.sfSymbol)
                    .font(.subheadline)
                Text(toastManager.message)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(toastManager.type.color.gradient)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            .padding(.bottom, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
