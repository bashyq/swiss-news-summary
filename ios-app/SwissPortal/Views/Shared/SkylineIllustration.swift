import SwiftUI

/// City skyline silhouette drawn with SwiftUI Canvas.
/// White building silhouettes — towers, church spires, dome, rooftops.
/// Used at 9% opacity in hero banners (News, Explore, Activities).
struct SkylineIllustration: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let white = Color.white
            // Building 1: tower with spire
            ctx.fill(Path(CGRect(x: w * 0.05, y: h * 0.36, width: w * 0.09, height: h * 0.64)), with: .color(white))
            ctx.fill(Path { p in
                p.move(to: CGPoint(x: w * 0.05, y: h * 0.36))
                p.addLine(to: CGPoint(x: w * 0.095, y: h * 0.11))
                p.addLine(to: CGPoint(x: w * 0.14, y: h * 0.36))
                p.closeSubpath()
            }, with: .color(white))
            // Building 2: wider with triangular roof
            ctx.fill(Path(CGRect(x: w * 0.19, y: h * 0.45, width: w * 0.11, height: h * 0.55)), with: .color(white))
            ctx.fill(Path { p in
                p.move(to: CGPoint(x: w * 0.19, y: h * 0.45))
                p.addLine(to: CGPoint(x: w * 0.245, y: h * 0.16))
                p.addLine(to: CGPoint(x: w * 0.30, y: h * 0.45))
                p.closeSubpath()
            }, with: .color(white))
            // Building 3: dome building
            ctx.fill(Path(CGRect(x: w * 0.36, y: h * 0.41, width: w * 0.08, height: h * 0.59)), with: .color(white))
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.32, y: h * 0.29, width: w * 0.16, height: h * 0.18)), with: .color(white))
            // Building 4: tall rectangular with cap
            ctx.fill(Path(CGRect(x: w * 0.50, y: h * 0.32, width: w * 0.14, height: h * 0.68)), with: .color(white))
            ctx.fill(Path(CGRect(x: w * 0.525, y: h * 0.20, width: w * 0.09, height: h * 0.15)), with: .color(white))
            // Building 5: church spire
            ctx.fill(Path { p in
                p.move(to: CGPoint(x: w * 0.69, y: h))
                p.addLine(to: CGPoint(x: w * 0.79, y: h * 0.25))
                p.addLine(to: CGPoint(x: w * 0.89, y: h))
                p.closeSubpath()
            }, with: .color(white))
            // Horizon bar
            ctx.fill(Path(CGRect(x: 0, y: h * 0.76, width: w, height: h * 0.13)), with: .color(white.opacity(0.25)))
        }
    }
}
