import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        promptSection
                        generationSection
                        huggingFaceSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        appState.saveNow()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .tint(AppTheme.text)
            .onChange(of: appState.settings) { _, _ in
                appState.saveSoon()
            }
        }
    }

    private var promptSection: some View {
        SettingsSection(title: "Instructions") {
            TextField("System prompt", text: $appState.settings.systemPrompt, axis: .vertical)
                .lineLimit(4...8)
                .font(.body)
                .textFieldStyle(.plain)
                .foregroundStyle(AppTheme.text)
                .padding(12)
                .background(AppTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var generationSection: some View {
        SettingsSection(title: "Generation") {
            VStack(spacing: 0) {
                HStack {
                    Text("Temperature")
                    Spacer()
                    Text(appState.settings.temperature, format: .number.precision(.fractionLength(2)))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .font(.body)
                .foregroundStyle(AppTheme.text)

                Slider(value: $appState.settings.temperature, in: 0...2, step: 0.05)
                    .tint(AppTheme.accent)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                Hairline()

                Stepper(value: $appState.settings.maximumTokens, in: 64...4096, step: 64) {
                    HStack {
                        Text("Max response")
                        Spacer()
                        Text("\(appState.settings.maximumTokens) tokens")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .font(.body)
                    .foregroundStyle(AppTheme.text)
                }
                .padding(.top, 12)
            }
        }
    }

    private var huggingFaceSection: some View {
        SettingsSection(title: "Hugging Face") {
            SecureField("Access token", text: $appState.settings.huggingFaceToken)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body)
                .textFieldStyle(.plain)
                .foregroundStyle(AppTheme.text)
                .padding(12)
                .background(AppTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .textCase(.uppercase)
                .padding(.horizontal, 2)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 0.5)
            }
        }
    }
}
