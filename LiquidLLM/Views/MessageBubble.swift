import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        switch message.role {
        case .user:
            userMessage
        case .assistant:
            assistantMessage
        case .system:
            systemMessage
        }
    }

    private var userMessage: some View {
        HStack(alignment: .bottom) {
            Spacer(minLength: 44)
            Text(displayText)
                .font(.body)
                .lineSpacing(3)
                .textSelection(.enabled)
                .foregroundStyle(AppTheme.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .frame(maxWidth: 540, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
    }

    private var assistantMessage: some View {
        HStack(alignment: .top, spacing: 11) {
            AssistantAvatar(isStreaming: message.isStreaming)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                if message.isStreaming && message.text.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Thinking")
                            .font(.body)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                } else {
                    Text(displayText)
                        .font(.body)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .foregroundStyle(AppTheme.text.opacity(0.92))
                }
            }
            .frame(maxWidth: 720, alignment: .leading)

            Spacer(minLength: 20)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var systemMessage: some View {
        Text(displayText)
            .font(.footnote)
            .lineSpacing(3)
            .foregroundStyle(AppTheme.secondaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
    }

    private var displayText: String {
        message.text.isEmpty ? "Thinking..." : message.text
    }
}

private struct AssistantAvatar: View {
    let isStreaming: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.surface)
                .frame(width: 28, height: 28)
            Image(systemName: isStreaming ? "waveform" : "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.text)
        }
    }
}
