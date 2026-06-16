import SwiftUI

struct ModelLibraryView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        searchField
                        localModels
                        huggingFaceResults
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                }
            }
            .navigationTitle("Models")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .tint(AppTheme.text)
        }
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)

            TextField("Search Hugging Face", text: $appState.modelSearchText)
                .font(.body)
                .textFieldStyle(.plain)
                .foregroundStyle(AppTheme.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { appState.searchModels() }

            Button {
                appState.searchModels()
            } label: {
                Image(systemName: appState.isSearchingModels ? "hourglass" : "arrow.forward")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.background)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.text, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(appState.isSearchingModels)
            .accessibilityLabel("Search")
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 0.5)
        }
    }

    private var localModels: some View {
        LibrarySection(title: "On This Device") {
            VStack(spacing: 0) {
                ForEach(appState.allModels) { model in
                    LocalModelRow(model: model)
                    if model.id != appState.allModels.last?.id {
                        Hairline()
                            .padding(.leading, 56)
                    }
                }
            }
        }
    }

    private var huggingFaceResults: some View {
        LibrarySection(title: "Hugging Face") {
            if appState.isSearchingModels {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Searching models")
                        .font(.callout)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else if appState.modelResults.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Search for Core AI-ready repos or tokenizer-backed model bundles.")
                        .font(.callout)
                        .foregroundStyle(AppTheme.secondaryText)
                    Text("Private and gated repositories can use the Hugging Face token in Settings.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.tertiaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            } else {
                VStack(spacing: 0) {
                    ForEach(appState.modelResults) { model in
                        HuggingFaceModelRow(model: model)
                        if model.id != appState.modelResults.last?.id {
                            Hairline()
                                .padding(.leading, 14)
                        }
                    }
                }
            }
        }
    }
}

private struct LibrarySection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .textCase(.uppercase)
                .padding(.horizontal, 2)

            VStack(spacing: 0) {
                content
            }
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 0.5)
            }
        }
    }
}

private struct LocalModelRow: View {
    @EnvironmentObject private var appState: AppState
    let model: LocalModel
    @State private var isConfirmingDelete = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(statusColor)
                .frame(width: 34, height: 34)
                .background(AppTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(.body)
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 5) {
                Text(statusText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(statusColor)
                if model.bytesOnDisk > 0 {
                    Text(model.bytesOnDisk.formattedByteCount)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            }

            Image(systemName: appState.selectedModel.id == model.id ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(appState.selectedModel.id == model.id ? AppTheme.text : AppTheme.tertiaryText)

            if canDelete {
                Button {
                    isConfirmingDelete = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.destructive)
                        .frame(width: 30, height: 30)
                        .background(AppTheme.surfaceElevated, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete \(model.displayName)")
            }
        }
        .padding(14)
        .contentShape(Rectangle())
        .onTapGesture {
            guard model.status == .ready else { return }
            appState.selectModel(model)
        }
        .contextMenu {
            if canDelete {
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label("Delete model", systemImage: "trash")
                }
            }
        }
        .confirmationDialog(
            "Delete \(model.displayName)?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete model", role: .destructive) {
                appState.deleteModel(model)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the downloaded model files from this device.")
        }
    }

    private var canDelete: Bool {
        model.id != LocalModel.appleFoundation.id
    }

    private var icon: String {
        switch model.runtime {
        case .appleFoundation:
            "apple.intelligence"
        case .coreAIBundle:
            "cpu"
        case .downloadedFiles:
            "externaldrive"
        }
    }

    private var subtitle: String {
        if let tokenizer = model.compatibility.tokenizer {
            return "\(model.subtitle) · \(tokenizer)"
        }
        return model.compatibility.notes.first ?? model.subtitle
    }

    private var statusText: String {
        switch model.status {
        case .ready:
            "Ready"
        case .downloading:
            "Downloading"
        case .unavailable:
            "Unavailable"
        case .failed:
            "Failed"
        }
    }

    private var statusColor: Color {
        switch model.status {
        case .ready:
            AppTheme.secondaryText
        case .downloading:
            AppTheme.accent
        case .unavailable:
            AppTheme.warning
        case .failed:
            AppTheme.destructive
        }
    }
}

private struct HuggingFaceModelRow: View {
    @EnvironmentObject private var appState: AppState
    let model: HuggingFaceModel

    private var variants: [HuggingFaceModelVariant]? {
        appState.modelVariants[model.id]
    }

    private var isLoadingVariants: Bool {
        appState.loadingVariantRepoIDs.contains(model.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.id)
                        .font(.body)
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(2)

                    HStack(spacing: 10) {
                        if let downloads = model.downloads {
                            Label(downloads.formatted(), systemImage: "arrow.down")
                        }
                        if let likes = model.likes {
                            Label(likes.formatted(), systemImage: "heart")
                        }
                        Text(model.pipelineTag ?? "text-generation")
                    }
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
                    appState.loadVariants(for: model)
                } label: {
                    if isLoadingVariants {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 34, height: 34)
                    } else {
                        Image(systemName: variants == nil ? "list.bullet.rectangle" : "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.background)
                            .frame(width: 34, height: 34)
                            .background(AppTheme.text, in: Circle())
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLoadingVariants)
                .accessibilityLabel("Show variants for \(model.id)")
            }

            variantList

            tagStrip
        }
        .padding(14)
    }

    @ViewBuilder
    private var variantList: some View {
        if let variants {
            if variants.isEmpty {
                Text("No Core AI model variants were found in this repo.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(variants) { variant in
                        HuggingFaceVariantRow(variant: variant)
                        if variant.id != variants.last?.id {
                            Hairline()
                                .padding(.leading, 46)
                        }
                    }
                }
                .background(AppTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var tagStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                ForEach((model.tags ?? []).prefix(6), id: \.self) { tag in
                    InlineTag(text: tag)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

private struct HuggingFaceVariantRow: View {
    @EnvironmentObject private var appState: AppState
    let variant: HuggingFaceModelVariant
    @State private var isConfirmingDelete = false

    private var progress: ModelDownloadProgress? {
        appState.downloadProgress[variant.id]
    }

    private var localModel: LocalModel? {
        appState.localModels.first { $0.id == variant.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(2)
                    Text(detailText)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Button(action: primaryAction) {
                    Image(systemName: buttonIcon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(buttonForeground)
                        .frame(width: 32, height: 32)
                        .background(buttonBackground, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(isButtonDisabled)
                .accessibilityLabel(buttonAccessibilityLabel)
            }

            featureStrip

            Text(variant.rootPath)
                .font(.caption2)
                .foregroundStyle(AppTheme.tertiaryText)
                .lineLimit(2)
                .padding(.leading, 45)

            if let progress {
                VStack(alignment: .leading, spacing: 7) {
                    ProgressView(value: progress.fractionCompleted)
                        .tint(AppTheme.accent)
                    HStack(spacing: 8) {
                        Text(progress.fractionCompleted, format: .percent.precision(.fractionLength(0)))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                        Text(progressByteText(progress))
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                        Spacer(minLength: 8)
                        Text(speedText(progress.bytesPerSecond))
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Text("Current: \(displayFileName(progress.currentFile))")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.tertiaryText)
                        .lineLimit(2)
                }
                .padding(.leading, 45)
            }
        }
        .padding(11)
        .contextMenu {
            if let localModel {
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label("Delete model", systemImage: "trash")
                }
                .disabled(progress != nil)
            }
        }
        .confirmationDialog(
            "Delete \(localModel?.displayName ?? variant.displayName)?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            if let localModel {
                Button("Delete model", role: .destructive) {
                    appState.deleteModel(localModel)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the downloaded model files from this device.")
        }
    }

    private var title: String {
        if variant.rootPath.contains("ios-gpu") {
            return "iOS GPU"
        }
        if variant.rootPath.contains("ios-ane") {
            return "iOS ANE"
        }
        if variant.rootPath.contains("gpu-pipelined") {
            return "GPU pipelined"
        }
        if variant.rootPath.contains("macos") {
            return "macOS GPU"
        }
        return variant.subtitle
    }

    private var icon: String {
        switch variant.kind {
        case .languageBundle:
            "cpu"
        case .standaloneAsset:
            "cube"
        }
    }

    private var iconColor: Color {
        variant.isChatReadyCandidate ? AppTheme.secondaryText : AppTheme.warning
    }

    private var detailText: String {
        var parts = [readableVariantName]
        if let totalBytes = variant.totalBytes {
            parts.append(totalBytes.formattedByteCount)
        }
        if variant.requiresCustomRuntime {
            parts.append("custom runtime needed")
        } else if !variant.isChatReadyCandidate {
            parts.append("not chat-ready")
        }
        return parts.joined(separator: " · ")
    }

    private var readableVariantName: String {
        variant.displayName
            .replacingOccurrences(of: "gemma4_e2b_", with: "")
            .replacingOccurrences(of: "qwen3_5_0_8b_", with: "")
            .replacingOccurrences(of: "_", with: " ")
    }

    private var featureStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(featureTags, id: \.self) { tag in
                    InlineTag(text: tag)
                }
            }
        }
        .padding(.leading, 45)
        .scrollIndicators(.hidden)
    }

    private var featureTags: [String] {
        let path = variant.rootPath.lowercased()
        var tags: [String] = []

        if path.contains("gpu-pipelined") {
            tags.append("fast path")
        }
        if path.contains("ios-gpu") {
            tags.append("faster")
        }
        if path.contains("ios-ane") {
            tags.append("efficient")
        }
        if path.contains("qat") {
            tags.append("QAT")
        }
        if path.contains("vl") {
            tags.append("vision")
        }
        if path.contains("aotc") || path.contains(".aimodelc") {
            tags.append("AOT")
        }
        if path.contains("h18p") {
            tags.append("h18p")
        }
        if path.contains("int4") {
            tags.append("int4")
        } else if path.contains("int8") {
            tags.append("int8")
        }
        if path.contains("tbl") {
            tags.append("table inputs")
        }
        if variant.requiresCustomRuntime {
            tags.append("custom runtime")
        }
        if variant.kind == .standaloneAsset {
            tags.append("raw asset")
        }

        if tags.isEmpty {
            tags.append(variant.subtitle)
        }
        return tags
    }

    private var buttonIcon: String {
        if progress != nil { return "hourglass" }
        if localModel?.status == .ready { return "checkmark" }
        return variant.isChatReadyCandidate ? "arrow.down" : "xmark"
    }

    private var buttonForeground: Color {
        variant.isChatReadyCandidate ? AppTheme.background : AppTheme.tertiaryText
    }

    private var buttonBackground: Color {
        variant.isChatReadyCandidate ? AppTheme.text : AppTheme.surfacePressed
    }

    private var isButtonDisabled: Bool {
        progress != nil || !variant.isChatReadyCandidate
    }

    private var buttonAccessibilityLabel: String {
        if localModel?.status == .ready {
            return "Select \(variant.displayName)"
        }
        if variant.requiresCustomRuntime {
            return "\(variant.displayName) needs a custom runtime"
        }
        return "Download \(variant.displayName)"
    }

    private func primaryAction() {
        if let localModel, localModel.status == .ready {
            appState.selectModel(localModel)
        } else {
            appState.download(variant)
        }
    }

    private func progressByteText(_ progress: ModelDownloadProgress) -> String {
        if let totalBytes = progress.totalBytes, totalBytes > 0 {
            return "\(progress.completedBytes.formattedByteCount) / \(totalBytes.formattedByteCount)"
        }
        if let fileBytes = progress.currentFileTotalBytes, fileBytes > 0 {
            return "\(progress.currentFileBytes.formattedByteCount) / \(fileBytes.formattedByteCount) file"
        }
        return "\(progress.completedBytes.formattedByteCount) downloaded"
    }

    private func speedText(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond > 0 else { return "Starting" }
        return "\(Int64(bytesPerSecond).formattedByteCount)/s"
    }

    private func displayFileName(_ file: String) -> String {
        URL(filePath: file).lastPathComponent
    }
}
