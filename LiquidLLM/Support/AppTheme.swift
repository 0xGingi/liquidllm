import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.04, green: 0.04, blue: 0.04)
    static let surface = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let surfaceElevated = Color(red: 0.17, green: 0.17, blue: 0.17)
    static let surfacePressed = Color(red: 0.22, green: 0.22, blue: 0.22)
    static let text = Color.white
    static let secondaryText = Color.white.opacity(0.64)
    static let tertiaryText = Color.white.opacity(0.42)
    static let hairline = Color.white.opacity(0.10)
    static let accent = Color(red: 0.20, green: 0.56, blue: 1.0)
    static let warning = Color(red: 1.0, green: 0.72, blue: 0.30)
    static let destructive = Color(red: 1.0, green: 0.38, blue: 0.34)

    static func relativeDateString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct AppBackground: View {
    var body: some View {
        AppTheme.background
            .ignoresSafeArea()
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.hairline)
            .frame(height: 0.5)
    }
}

struct IconOnlyButton: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.text)
                .frame(width: 38, height: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct InlineTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(AppTheme.secondaryText)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(AppTheme.surfaceElevated, in: Capsule())
    }
}

extension Int64 {
    var formattedByteCount: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
