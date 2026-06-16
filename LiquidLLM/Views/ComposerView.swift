import SwiftUI

struct ComposerView: View {
    @EnvironmentObject private var appState: AppState
    @FocusState private var isFocused: Bool
    let openLibrary: () -> Void

    private var canSend: Bool {
        !appState.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button(action: openLibrary) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open model library")

            TextField("Message", text: $appState.composerText, axis: .vertical)
                .font(.body)
                .foregroundStyle(AppTheme.text)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(.vertical, 8)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit {
                    if canSend {
                        appState.sendComposerMessage()
                    }
                }

            Button {
                if appState.isGenerating {
                    appState.stopGeneration()
                } else if canSend {
                    appState.sendComposerMessage()
                }
            } label: {
                Image(systemName: appState.isGenerating ? "stop.fill" : "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(appState.isGenerating || canSend ? Color.black : AppTheme.tertiaryText)
                    .frame(width: 32, height: 32)
                    .background(sendButtonBackground, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!appState.isGenerating && !canSend)
            .accessibilityLabel(appState.isGenerating ? "Stop generating" : "Send")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 0.5)
        }
    }

    private var sendButtonBackground: Color {
        if appState.isGenerating || canSend {
            return AppTheme.text
        }
        return AppTheme.surfacePressed
    }
}
