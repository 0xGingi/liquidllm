import SwiftUI

struct ChatWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var showingLibrary: Bool
    @Binding var showingSettings: Bool
    @Namespace private var glassNamespace

    var body: some View {
        VStack(spacing: 14) {
            topBar
            messageScroll
            ComposerView()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.clear)
    }

    private var topBar: some View {
        GlassEffectContainer(spacing: 18) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.selectedThread?.title ?? "New chat")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(appState.selectedModel.subtitle)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                ModelSelectorButton()
                    .glassEffectID("model-selector", in: glassNamespace)

                Button {
                    showingLibrary = true
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.glass)
                .help("Model library")

                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.glass)
                .help("Settings")
            }
            .padding(14)
            .liquidGlass(cornerRadius: 26, tint: .white.opacity(0.06), interactive: true)
        }
    }

    private var messageScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 18) {
                    if let messages = appState.selectedThread?.messages {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 10)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: appState.selectedThread?.messages.last?.text) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: appState.selectedThreadID) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let id = appState.selectedThread?.messages.last?.id else { return }
        withAnimation(.smooth(duration: 0.32)) {
            proxy.scrollTo(id, anchor: .bottom)
        }
    }
}

private struct ModelSelectorButton: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Menu {
            ForEach(appState.allModels) { model in
                Button {
                    appState.selectModel(model)
                } label: {
                    Label(model.displayName, systemImage: icon(for: model))
                }
                .disabled(model.status != .ready)
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: icon(for: appState.selectedModel))
                    .foregroundStyle(AppTheme.mint)
                Text(appState.selectedModel.displayName)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.52))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 13)
            .frame(height: 40)
            .liquidGlass(cornerRadius: 18, tint: AppTheme.mint.opacity(0.15), interactive: true)
        }
    }

    private func icon(for model: LocalModel) -> String {
        switch model.runtime {
        case .appleFoundation:
            "apple.intelligence"
        case .coreAIBundle:
            "cpu.fill"
        case .downloadedFiles:
            "externaldrive.badge.questionmark"
        }
    }
}
