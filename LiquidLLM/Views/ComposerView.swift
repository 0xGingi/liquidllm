import SwiftUI

struct ComposerView: View {
    @EnvironmentObject private var appState: AppState
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Ask your local model", text: $appState.composerText, axis: .vertical)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1...6)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .focused($isFocused)
                .onSubmit {
                    appState.sendComposerMessage()
                }

            if appState.isGenerating {
                Button {
                    appState.stopGeneration()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 17, weight: .bold))
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.glassProminent)
                .help("Stop")
            } else {
                Button {
                    appState.sendComposerMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 17, weight: .bold))
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.glassProminent)
                .disabled(appState.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Send")
            }
        }
        .padding(8)
        .liquidGlass(cornerRadius: 28, tint: .white.opacity(0.08), interactive: true)
    }
}
