import SwiftUI

enum Glass {
    static let accent = Color(red: 0.04, green: 0.56, blue: 0.99)
    static let accent2 = Color(red: 0.48, green: 0.36, blue: 1.0)
}

struct AuroraBackground: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.025, blue: 0.04)

            blob(Glass.accent.opacity(0.55), size: 380, x: -120, y: -140)
                .offset(x: phase * 40, y: -phase * 24)
            blob(Glass.accent2.opacity(0.50), size: 340, x: 140, y: 120)
                .offset(x: -phase * 34, y: phase * 30)
            blob(Color(red: 0.0, green: 0.85, blue: 0.76).opacity(0.35), size: 320, x: -60, y: 320)
                .offset(x: phase * 26, y: -phase * 38)
            blob(Color(red: 1.0, green: 0.36, blue: 0.63).opacity(0.30), size: 260, x: 150, y: 520)
                .offset(x: -phase * 20, y: phase * 20)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    private func blob(_ color: Color, size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color, .clear], center: .center,
                                 startRadius: 0, endRadius: size / 2))
            .frame(width: size, height: size)
            .blur(radius: 58)
            .offset(x: x, y: y)
    }
}

extension View {
    /// iOS 26 液态玻璃，低版本回落到材质
    @ViewBuilder
    func glassCard(_ radius: CGFloat = 26) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
        }
    }

    @ViewBuilder
    func glassPill() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            self
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        }
    }
}
