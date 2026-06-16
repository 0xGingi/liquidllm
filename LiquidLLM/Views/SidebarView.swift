import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var showingLibrary: Bool
    @Binding var showingSettings: Bool
    @Binding var columnVisibility: NavigationSplitViewVisibility
    var onOpenThread: () -> Void = {}
    @State private var searchText = ""

    private var filteredThreads: [ChatThread] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appState.threads }
        return appState.threads.filter { thread in
            thread.title.localizedCaseInsensitiveContains(query)
            || thread.messages.contains { $0.text.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            threadList
            footer
        }
        .background(AppTheme.background)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.text)
                .frame(width: 34, height: 34)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text("Liquid LLM")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Text(appState.selectedModel.displayName)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            IconOnlyButton(
                systemName: "square.and.pencil",
                accessibilityLabel: "New chat"
            ) {
                appState.createThread()
                onOpenThread()
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.tertiaryText)
            TextField("Search", text: $searchText)
                .font(.callout)
                .textFieldStyle(.plain)
                .foregroundStyle(AppTheme.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 0.5)
        }
    }

    private var threadList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                if filteredThreads.isEmpty {
                    Text("No chats found")
                        .font(.callout)
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 18)
                } else {
                    ForEach(filteredThreads) { thread in
                        Button {
                            appState.selectThread(thread.id)
                            columnVisibility = .detailOnly
                            onOpenThread()
                        } label: {
                            ThreadRow(
                                thread: thread,
                                isSelected: thread.id == appState.selectedThreadID
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
        }
        .scrollIndicators(.hidden)
    }

    private var footer: some View {
        VStack(spacing: 2) {
            Hairline()
                .padding(.bottom, 6)

            SidebarActionRow(
                icon: "cpu",
                title: "Models",
                subtitle: "\(appState.localModels.count) on device"
            ) {
                showingLibrary = true
            }

            SidebarActionRow(
                icon: "slider.horizontal.3",
                title: "Settings",
                subtitle: appState.statusMessage
            ) {
                showingSettings = true
            }

            Button(role: .destructive) {
                appState.deleteSelectedThread()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 24)
                    Text("Delete chat")
                        .font(.callout)
                    Spacer()
                }
                .foregroundStyle(appState.threads.count <= 1 ? AppTheme.tertiaryText : AppTheme.destructive)
                .padding(.horizontal, 14)
                .frame(height: 44)
            }
            .buttonStyle(.plain)
            .disabled(appState.threads.count <= 1)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 10)
        .background(AppTheme.background)
    }
}

private struct ThreadRow: View {
    let thread: ChatThread
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bubble.left")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isSelected ? AppTheme.text : AppTheme.secondaryText)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(thread.title)
                    .font(.callout)
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)
                Text("\(thread.messages.count) messages · \(AppTheme.relativeDateString(for: thread.updatedAt))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
        .background(
            isSelected ? AppTheme.surfaceElevated : Color.clear,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SidebarActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout)
                        .foregroundStyle(AppTheme.text)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.tertiaryText)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
