import SwiftUI

struct ChatWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var showingLibrary: Bool
    @Binding var showingSettings: Bool
    @Binding var columnVisibility: NavigationSplitViewVisibility
    var onShowSidebar: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Hairline()
            messageScroll
            ComposerView {
                showingLibrary = true
            }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .background(AppTheme.background)
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            IconOnlyButton(
                systemName: "sidebar.left",
                accessibilityLabel: "Show chats"
            ) {
                if let onShowSidebar {
                    onShowSidebar()
                } else {
                    columnVisibility = .all
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(appState.selectedThread?.title ?? "New chat")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)
                ModelSelectorButton()
            }

            Spacer(minLength: 8)

            IconOnlyButton(
                systemName: "tray.and.arrow.down",
                accessibilityLabel: "Model library"
            ) {
                showingLibrary = true
            }

            IconOnlyButton(
                systemName: "slider.horizontal.3",
                accessibilityLabel: "Settings"
            ) {
                showingSettings = true
            }

            IconOnlyButton(
                systemName: "square.and.pencil",
                accessibilityLabel: "New chat"
            ) {
                appState.createThread()
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 58)
        .background(AppTheme.background)
    }

    private var messageScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if let messages = appState.selectedThread?.messages {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.top, 18)
                .padding(.bottom, 10)
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
        withAnimation(.smooth(duration: 0.24)) {
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
                    Label(model.displayName, systemImage: appState.selectedModel.id == model.id ? "checkmark" : icon(for: model))
                }
                .disabled(model.status != .ready)
            }
        } label: {
            HStack(spacing: 4) {
                Text(appState.selectedModel.displayName)
                    .font(.caption)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(AppTheme.secondaryText)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func icon(for model: LocalModel) -> String {
        switch model.runtime {
        case .appleFoundation:
            "apple.intelligence"
        case .coreAIBundle:
            "cpu"
        case .downloadedFiles:
            "externaldrive"
        }
    }
}
