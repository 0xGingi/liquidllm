import SwiftUI

enum AppTheme {
    static let ink = Color(red: 0.025, green: 0.027, blue: 0.032)
    static let graphite = Color(red: 0.10, green: 0.105, blue: 0.115)
    static let porcelain = Color(red: 0.93, green: 0.96, blue: 0.96)
    static let mint = Color(red: 0.45, green: 0.95, blue: 0.78)
    static let coral = Color(red: 1.0, green: 0.42, blue: 0.34)
    static let amber = Color(red: 1.0, green: 0.72, blue: 0.30)
    static let blue = Color(red: 0.32, green: 0.68, blue: 1.0)

    static func relativeDateString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct LiquidBackground: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let seconds = timeline.date.timeIntervalSinceReferenceDate
                let width = size.width
                let height = size.height
                let phase = CGFloat(seconds.truncatingRemainder(dividingBy: 18) / 18)

                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        Gradient(colors: [
                            AppTheme.ink,
                            Color(red: 0.06, green: 0.075, blue: 0.08),
                            Color(red: 0.05, green: 0.045, blue: 0.04)
                        ]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: width, y: height)
                    )
                )

                drawRibbon(
                    in: &context,
                    size: size,
                    yBase: height * (0.23 + 0.04 * sin(phase * .pi * 2)),
                    thickness: height * 0.28,
                    color: AppTheme.mint.opacity(0.24),
                    phase: phase
                )
                drawRibbon(
                    in: &context,
                    size: size,
                    yBase: height * (0.67 + 0.035 * cos(phase * .pi * 2)),
                    thickness: height * 0.24,
                    color: AppTheme.coral.opacity(0.18),
                    phase: phase + 0.34
                )
                drawRibbon(
                    in: &context,
                    size: size,
                    yBase: height * 0.46,
                    thickness: height * 0.18,
                    color: AppTheme.blue.opacity(0.14),
                    phase: phase + 0.68
                )
            }
            .ignoresSafeArea()
            .overlay {
                Rectangle()
                    .fill(.ultraThinMaterial.opacity(0.26))
                    .ignoresSafeArea()
            }
        }
    }

    private func drawRibbon(
        in context: inout GraphicsContext,
        size: CGSize,
        yBase: CGFloat,
        thickness: CGFloat,
        color: Color,
        phase: CGFloat
    ) {
        let width = size.width
        let offset = width * (phase - 0.5) * 0.18
        var path = Path()
        path.move(to: CGPoint(x: -width * 0.15, y: yBase - thickness * 0.5))
        path.addCurve(
            to: CGPoint(x: width * 1.15, y: yBase - thickness * 0.15),
            control1: CGPoint(x: width * 0.24 + offset, y: yBase - thickness),
            control2: CGPoint(x: width * 0.70 - offset, y: yBase + thickness * 0.12)
        )
        path.addLine(to: CGPoint(x: width * 1.15, y: yBase + thickness * 0.55))
        path.addCurve(
            to: CGPoint(x: -width * 0.15, y: yBase + thickness * 0.38),
            control1: CGPoint(x: width * 0.74 - offset, y: yBase + thickness),
            control2: CGPoint(x: width * 0.26 + offset, y: yBase - thickness * 0.08)
        )
        path.closeSubpath()
        context.addFilter(.blur(radius: 46))
        context.fill(path, with: .color(color))
    }
}

struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = 28
    var tint: Color? = nil
    var interactive: Bool = false

    func body(content: Content) -> some View {
        content
            .glassEffect(
                .regular
                    .tint(tint)
                    .interactive(interactive),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }
}

extension View {
    func liquidGlass(
        cornerRadius: CGFloat = 28,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius, tint: tint, interactive: interactive))
    }
}

struct MetricChip: View {
    let icon: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.88))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .liquidGlass(cornerRadius: 14, tint: tint.opacity(0.18), interactive: true)
    }
}

extension Int64 {
    var formattedByteCount: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
