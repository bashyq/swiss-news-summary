import SwiftUI
import CoreLocation

/// "Near you" horizontal scroll of photo chip cards showing nearby explore items.
struct NearYouSection: View {
    @Environment(AppState.self) private var appState

    let items: [ExploreItem]
    let userLocation: CLLocation?
    var onItemTap: ((ExploreItem) -> Void)?

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                // Section header
                HStack(alignment: .firstTextBaseline) {
                    Text(appState.localized(en: "Near you", de: "In der Nähe"))
                        .font(.sectionHeadline)
                        .foregroundStyle(.znInk)
                    Spacer()
                    Text(appState.localized(en: "0.8 km radius", de: "0.8 km Umkreis"))
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(.znMuted)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)

                // Horizontal scroll of chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(items) { item in
                            nearYouChip(item)
                                .onTapGesture {
                                    onItemTap?(item)
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - Chip Card

    private func nearYouChip(_ item: ExploreItem) -> some View {
        VStack(spacing: 0) {
            // Photo area — illustrated placeholder
            chipIllustration(item)
                .frame(height: 72)
                .clipped()

            // Info area
            VStack(alignment: .leading, spacing: 2) {
                Text(item.localizedName(language: appState.language))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.znInk)
                    .lineLimit(1)

                if let distance = distanceString(to: item) {
                    Text("↗ \(distance)")
                        .font(.system(size: 11))
                        .foregroundStyle(.znMuted)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: AppSpacing.nearYouChipWidth)
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    // MARK: - Illustrated Placeholders

    @ViewBuilder
    private func chipIllustration(_ item: ExploreItem) -> some View {
        let seed = abs(item.localizedName(language: .en).hashValue)
        let variant = seed % 5

        switch variant {
        case 0: museumIllustration
        case 1: parkIllustration
        case 2: cafeIllustration
        case 3: zooIllustration
        default: institutionIllustration
        }
    }

    /// Museum scene — blue-gray sky, classical facade with pediment, columns, arched door
    private var museumIllustration: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            // Sky
            ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)), with: .color(Color(red: 0.69, green: 0.72, blue: 0.78)))
            // Ground
            ctx.fill(Path(CGRect(x: 0, y: h * 0.58, width: w, height: h * 0.42)), with: .color(Color(red: 0.60, green: 0.68, blue: 0.75)))
            // Building facade
            ctx.fill(Path(CGRect(x: w * 0.12, y: h * 0.31, width: w * 0.77, height: h * 0.69)), with: .color(Color(red: 0.83, green: 0.79, blue: 0.72)))
            // Pediment triangle
            ctx.fill(Path { p in
                p.move(to: CGPoint(x: w * 0.12, y: h * 0.31))
                p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.08))
                p.addLine(to: CGPoint(x: w * 0.89, y: h * 0.31))
                p.closeSubpath()
            }, with: .color(Color(red: 0.78, green: 0.74, blue: 0.66)))
            // Columns
            let colColor = Color(red: 0.88, green: 0.85, blue: 0.78)
            for x in stride(from: 0.19, through: 0.75, by: 0.08) {
                ctx.fill(Path(CGRect(x: w * x, y: h * 0.31, width: w * 0.046, height: h * 0.69)), with: .color(colColor))
            }
            // Arched door
            ctx.fill(Path(roundedRect: CGRect(x: w * 0.38, y: h * 0.61, width: w * 0.23, height: h * 0.39), cornerRadii: .init(topLeading: w * 0.115, topTrailing: w * 0.115)), with: .color(Color(red: 0.54, green: 0.48, blue: 0.37)))
        }
    }

    /// Park/garden scene — blue sky, green ground, two trees with trunks, sandy path
    private var parkIllustration: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            // Sky
            ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: h * 0.58)), with: .color(Color(red: 0.66, green: 0.77, blue: 0.85)))
            // Ground
            ctx.fill(Path(CGRect(x: 0, y: h * 0.58, width: w, height: h * 0.42)), with: .color(Color(red: 0.55, green: 0.69, blue: 0.45)))
            // Sandy path
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.19, y: h * 0.64, width: w * 0.62, height: h * 0.33)), with: .color(Color(red: 0.87, green: 0.78, blue: 0.50).opacity(0.45)))
            // Left tree trunk + canopy
            ctx.fill(Path(CGRect(x: w * 0.09, y: h * 0.39, width: w * 0.046, height: h * 0.31)), with: .color(Color(red: 0.29, green: 0.44, blue: 0.19)))
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.02, y: h * 0.14, width: w * 0.18, height: h * 0.39)), with: .color(Color(red: 0.36, green: 0.54, blue: 0.23)))
            // Right tree trunk + canopy
            ctx.fill(Path(CGRect(x: w * 0.81, y: h * 0.33, width: w * 0.054, height: h * 0.36)), with: .color(Color(red: 0.29, green: 0.44, blue: 0.19)))
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.72, y: h * 0.04, width: w * 0.22, height: h * 0.44)), with: .color(Color(red: 0.36, green: 0.54, blue: 0.23)))
        }
    }

    /// Cafe/restaurant scene — warm tones, terracotta awning, facade with window and door
    private var cafeIllustration: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            // Sky
            ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: h * 0.56)), with: .color(Color(red: 0.77, green: 0.66, blue: 0.51)))
            // Ground/street
            ctx.fill(Path(CGRect(x: 0, y: h * 0.56, width: w, height: h * 0.44)), with: .color(Color(red: 0.72, green: 0.56, blue: 0.41)))
            // Building facade
            ctx.fill(Path(CGRect(x: w * 0.14, y: h * 0.25, width: w * 0.72, height: h * 0.75)), with: .color(Color(red: 0.91, green: 0.83, blue: 0.72)))
            // Terracotta awning
            ctx.fill(Path(CGRect(x: w * 0.14, y: h * 0.25, width: w * 0.72, height: h * 0.22)), with: .color(Color(red: 0.77, green: 0.38, blue: 0.23).opacity(0.6)))
            // Window (blue-ish)
            ctx.fill(Path(roundedRect: CGRect(x: w * 0.25, y: h * 0.58, width: w * 0.15, height: h * 0.31), cornerRadius: 2), with: .color(Color(red: 0.56, green: 0.72, blue: 0.82).opacity(0.7)))
            // Door (brown)
            ctx.fill(Path(roundedRect: CGRect(x: w * 0.38, y: h * 0.67, width: w * 0.23, height: h * 0.33), cornerRadius: 2), with: .color(Color(red: 0.54, green: 0.42, blue: 0.25)))
        }
    }

    /// Zoo/nature scene — green-teal, blue sky, trees, gray path oval
    private var zooIllustration: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            // Sky
            ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: h * 0.58)), with: .color(Color(red: 0.48, green: 0.68, blue: 0.75)))
            // Ground
            ctx.fill(Path(CGRect(x: 0, y: h * 0.58, width: w, height: h * 0.42)), with: .color(Color(red: 0.47, green: 0.63, blue: 0.41)))
            // Left tree trunk + canopy
            ctx.fill(Path(CGRect(x: w * 0.11, y: h * 0.39, width: w * 0.054, height: h * 0.31)), with: .color(Color(red: 0.29, green: 0.44, blue: 0.19)))
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.03, y: h * 0.12, width: w * 0.20, height: h * 0.42)), with: .color(Color(red: 0.36, green: 0.54, blue: 0.23)))
            // Right tree trunk + canopy
            ctx.fill(Path(CGRect(x: w * 0.83, y: h * 0.33, width: w * 0.062, height: h * 0.36)), with: .color(Color(red: 0.29, green: 0.44, blue: 0.19)))
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.72, y: h * 0.0, width: w * 0.23, height: h * 0.50)), with: .color(Color(red: 0.36, green: 0.54, blue: 0.23)))
            // Gray path
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.25, y: h * 0.63, width: w * 0.49, height: h * 0.28)), with: .color(Color(red: 0.54, green: 0.54, blue: 0.54).opacity(0.45)))
        }
    }

    /// Institution/museum scene — blue-gray, imposing facade with navy band, small windows
    private var institutionIllustration: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            // Sky
            ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: h * 0.58)), with: .color(Color(red: 0.60, green: 0.72, blue: 0.82)))
            // Ground
            ctx.fill(Path(CGRect(x: 0, y: h * 0.58, width: w, height: h * 0.42)), with: .color(Color(red: 0.47, green: 0.56, blue: 0.66)))
            // Building facade
            ctx.fill(Path(CGRect(x: w * 0.06, y: h * 0.31, width: w * 0.88, height: h * 0.69)), with: .color(Color(red: 0.82, green: 0.85, blue: 0.88)))
            // Navy header band
            ctx.fill(Path(CGRect(x: w * 0.06, y: h * 0.31, width: w * 0.88, height: h * 0.19)), with: .color(Color(red: 0.10, green: 0.23, blue: 0.36).opacity(0.5)))
            // Small windows row
            let winColor = Color(red: 0.56, green: 0.75, blue: 0.82).opacity(0.8)
            for i in 0..<3 {
                let xOff = 0.12 + Double(i) * 0.14
                ctx.fill(Path(roundedRect: CGRect(x: w * xOff, y: h * 0.39, width: w * 0.09, height: h * 0.10), cornerRadius: 1), with: .color(winColor))
            }
        }
    }

    private func distanceString(to item: ExploreItem) -> String? {
        guard let location = userLocation else { return nil }
        let itemLocation = CLLocation(latitude: item.coordinate.latitude, longitude: item.coordinate.longitude)
        let meters = location.distance(from: itemLocation)
        if meters < 1000 {
            return "\(Int(meters))m"
        }
        return String(format: "%.1f km", meters / 1000)
    }
}



#Preview {
    NearYouSection(items: [], userLocation: nil)
        .environment(AppState())
}
