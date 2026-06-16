import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            header
            threadList
            statusBar
        }
        .padding(18)
        .background(.clear)
        .toolbar(removing: .sidebarToggle)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.mint.opacity(0.16))
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.mint)
            }
            .frame(width: 46, height: 46)
            .liquidGlass(cornerRadius: 16, tint: AppTheme.mint.opacity(0.18))

            VStack(alignment: .leading, spacing: 2) {
                Text("Liquid LLM")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text("iOS 27 Core AI chat")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
            }

            Spacer()

            Button {
                appState.createThread()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.glass)
            .help("New chat")
        }
    }

    private var threadList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(appState.threads) { thread in
                    Button {
                        appState.selectedThreadID = thread.id
                    } label: {
                        ThreadRow(
                            thread: thread,
                            isSelected: thread.id == appState.selectedThreadID
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            Image(systemName: appState.isGenerating ? "waveform" : "checkmark.seal.fill")
                .foregroundStyle(appState.isGenerating ? AppTheme.amber : AppTheme.mint)
            Text(appState.statusMessage)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .lineLimit(2)
                .foregroundStyle(.white.opacity(0.72))
            Spacer()
            Button(role: .destructive) {
                appState.deleteSelectedThread()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.glass)
            .disabled(appState.threads.count <= 1)
        }
        .padding(12)
        .liquidGlass(cornerRadius: 20, tint: .white.opacity(0.06), interactive: true)
    }
}

private struct ThreadRow: View {
    let thread: ChatThread
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(thread.title)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                if isSelected {
                    Circle()
                        .fill(AppTheme.mint)
                        .frame(width: 8, height: 8)
                }
            }

            HStack(spacing: 10) {
                Label("\(thread.messages.count)", systemImage: "text.bubble")
                Text(AppTheme.relativeDateString(for: thread.updatedAt))
            }
            .font(.system(.caption2, design: .rounded, weight: .medium))
            .foregroundStyle(.white.opacity(0.52))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(
            cornerRadius: 20,
            tint: isSelected ? AppTheme.mint.opacity(0.22) : .white.opacity(0.04),
            interactive: true
        )
    }
}
