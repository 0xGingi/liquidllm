import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if message.role == .user { Spacer(minLength: 48) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                    Text(label)
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                    if message.isStreaming {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                .foregroundStyle(.white.opacity(0.56))

                Text(message.text.isEmpty ? "Thinking..." : message.text)
                    .font(.system(.body, design: .rounded))
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(maxWidth: 720, alignment: message.role == .user ? .trailing : .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .liquidGlass(cornerRadius: 24, tint: tint, interactive: message.role == .user)

            if message.role != .user { Spacer(minLength: 48) }
        }
        .frame(maxWidth: .infinity)
    }

    private var icon: String {
        switch message.role {
        case .user:
            "person.fill"
        case .assistant:
            "sparkle.magnifyingglass"
        case .system:
            "gearshape.fill"
        }
    }

    private var label: String {
        switch message.role {
        case .user:
            "You"
        case .assistant:
            "Assistant"
        case .system:
            "System"
        }
    }

    private var tint: Color {
        switch message.role {
        case .user:
            AppTheme.blue.opacity(0.18)
        case .assistant:
            AppTheme.mint.opacity(0.12)
        case .system:
            AppTheme.amber.opacity(0.14)
        }
    }
}
