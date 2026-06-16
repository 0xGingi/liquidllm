import SwiftUI

struct ModelLibraryView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        searchPanel
                        localModels
                        results
                    }
                    .padding(22)
                }
            }
            .navigationTitle("Model Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }

    private var searchPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.mint)
                TextField("Search Hugging Face", text: $appState.modelSearchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { appState.searchModels() }
                Button {
                    appState.searchModels()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glassProminent)
            }
            .font(.system(.body, design: .rounded, weight: .medium))
            .foregroundStyle(.white)

            HStack(spacing: 10) {
                MetricChip(icon: "cpu", value: "Core AI bundles", tint: AppTheme.mint)
                MetricChip(icon: "lock.shield", value: "Private token optional", tint: AppTheme.blue)
                MetricChip(icon: "externaldrive", value: "\(appState.localModels.count) local", tint: AppTheme.amber)
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 26, tint: .white.opacity(0.08), interactive: true)
    }

    private var localModels: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("On This Device", icon: "internaldrive")
            ForEach(appState.allModels) { model in
                LocalModelRow(model: model)
            }
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Hugging Face", icon: "arrow.down.app")
            if appState.isSearchingModels {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .liquidGlass(cornerRadius: 24, tint: .white.opacity(0.05))
            } else if appState.modelResults.isEmpty {
                EmptyLibraryState()
            } else {
                ForEach(appState.modelResults) { model in
                    HuggingFaceModelRow(model: model)
                }
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.mint)
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.top, 2)
    }
}

private struct LocalModelRow: View {
    @EnvironmentObject private var appState: AppState
    let model: LocalModel

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 42, height: 42)
                .liquidGlass(cornerRadius: 16, tint: color.opacity(0.16))

            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(.system(.callout, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(2)
            }

            Spacer()

            if model.bytesOnDisk > 0 {
                Text(model.bytesOnDisk.formattedByteCount)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.58))
            }

            Button {
                appState.selectModel(model)
            } label: {
                Image(systemName: appState.selectedModel.id == model.id ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
            }
            .buttonStyle(.glass)
            .disabled(model.status != .ready)
        }
        .padding(14)
        .liquidGlass(cornerRadius: 22, tint: .white.opacity(0.05), interactive: true)
    }

    private var icon: String {
        switch model.runtime {
        case .appleFoundation:
            "apple.intelligence"
        case .coreAIBundle:
            "cpu.fill"
        case .downloadedFiles:
            "externaldrive.badge.questionmark"
        }
    }

    private var color: Color {
        model.status == .ready ? AppTheme.mint : AppTheme.amber
    }

    private var subtitle: String {
        if let tokenizer = model.compatibility.tokenizer {
            return "\(model.subtitle) - \(tokenizer)"
        }
        return model.compatibility.notes.first ?? model.subtitle
    }
}

private struct HuggingFaceModelRow: View {
    @EnvironmentObject private var appState: AppState
    let model: HuggingFaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.id)
                        .font(.system(.callout, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        if let downloads = model.downloads {
                            Label(downloads.formatted(), systemImage: "arrow.down")
                        }
                        if let likes = model.likes {
                            Label(likes.formatted(), systemImage: "heart")
                        }
                        Text(model.pipelineTag ?? "text-generation")
                    }
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.56))
                }

                Spacer()

                Button {
                    appState.download(model)
                } label: {
                    Image(systemName: "arrow.down.to.line.compact")
                        .font(.system(size: 17, weight: .bold))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.glassProminent)
            }

            if let progress = appState.downloadProgress[model.id] {
                ProgressView(value: progress.fractionCompleted)
                    .tint(AppTheme.mint)
                Text(progress.currentFile)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            tagStrip
        }
        .padding(14)
        .liquidGlass(cornerRadius: 22, tint: .white.opacity(0.05), interactive: true)
    }

    private var tagStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach((model.tags ?? []).prefix(6), id: \.self) { tag in
                    Text(tag)
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .liquidGlass(cornerRadius: 12, tint: AppTheme.blue.opacity(0.10))
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

private struct EmptyLibraryState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(AppTheme.mint)
            Text("Search for Core AI-ready language bundles or tokenizer-backed model repos.")
                .font(.system(.callout, design: .rounded, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.64))
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding()
        .liquidGlass(cornerRadius: 24, tint: .white.opacity(0.05))
    }
}
