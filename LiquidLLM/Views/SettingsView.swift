import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        promptSection
                        generationSection
                        huggingFaceSection
                    }
                    .padding(22)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.saveNow()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("System Prompt", systemImage: "text.alignleft")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            TextField("System prompt", text: $appState.settings.systemPrompt, axis: .vertical)
                .lineLimit(4...10)
                .font(.system(.body, design: .rounded))
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .padding(14)
                .liquidGlass(cornerRadius: 18, tint: .white.opacity(0.05), interactive: true)
                .onChange(of: appState.settings) { _, _ in appState.saveSoon() }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 26, tint: .white.opacity(0.08))
    }

    private var generationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Generation", systemImage: "dial.medium")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Temperature")
                    Spacer()
                    Text(appState.settings.temperature, format: .number.precision(.fractionLength(2)))
                }
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.76))
                Slider(value: $appState.settings.temperature, in: 0...2, step: 0.05)
                    .tint(AppTheme.mint)
            }

            Stepper(value: $appState.settings.maximumTokens, in: 64...4096, step: 64) {
                HStack {
                    Text("Max response")
                    Spacer()
                    Text("\(appState.settings.maximumTokens) tokens")
                        .foregroundStyle(.white.opacity(0.58))
                }
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
            }
            .onChange(of: appState.settings) { _, _ in appState.saveSoon() }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 26, tint: .white.opacity(0.08))
    }

    private var huggingFaceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Hugging Face", systemImage: "key")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)

            SecureField("Access token for private or gated repos", text: $appState.settings.huggingFaceToken)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white)
                .padding(14)
                .liquidGlass(cornerRadius: 18, tint: .white.opacity(0.05), interactive: true)
                .onChange(of: appState.settings) { _, _ in appState.saveSoon() }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 26, tint: .white.opacity(0.08))
    }
}
