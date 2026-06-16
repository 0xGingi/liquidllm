import SwiftUI

private enum CompactRoute: Hashable {
    case chat
}

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var appState: AppState
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var compactPath: [CompactRoute] = []
    @State private var showingLibrary = false
    @State private var showingSettings = false

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactLayout
            } else {
                regularLayout
            }
        }
        .background(AppBackground())
        .sheet(isPresented: $showingLibrary) {
            ModelLibraryView()
                .environmentObject(appState)
                .presentationSizing(.form)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(appState)
                .presentationSizing(.form)
        }
    }

    private var compactLayout: some View {
        NavigationStack(path: $compactPath) {
            SidebarView(
                showingLibrary: $showingLibrary,
                showingSettings: $showingSettings,
                columnVisibility: $columnVisibility,
                onOpenThread: openCompactChat
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: CompactRoute.self) { route in
                switch route {
                case .chat:
                    ChatWorkspaceView(
                        showingLibrary: $showingLibrary,
                        showingSettings: $showingSettings,
                        columnVisibility: $columnVisibility,
                        onShowSidebar: closeCompactChat
                    )
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationBarBackButtonHidden(true)
                }
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                showingLibrary: $showingLibrary,
                showingSettings: $showingSettings,
                columnVisibility: $columnVisibility
            )
            .navigationSplitViewColumnWidth(min: 280, ideal: 320)
        } detail: {
            ChatWorkspaceView(
                showingLibrary: $showingLibrary,
                showingSettings: $showingSettings,
                columnVisibility: $columnVisibility
            )
        }
        .scrollContentBackground(.hidden)
    }

    private func openCompactChat() {
        guard appState.selectedThread != nil else { return }
        compactPath = [.chat]
    }

    private func closeCompactChat() {
        compactPath.removeAll()
    }
}
