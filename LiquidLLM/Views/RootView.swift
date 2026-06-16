import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showingLibrary = false
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            LiquidBackground()

            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView()
                    .navigationSplitViewColumnWidth(min: 280, ideal: 320)
            } detail: {
                ChatWorkspaceView(
                    showingLibrary: $showingLibrary,
                    showingSettings: $showingSettings
                )
            }
            .scrollContentBackground(.hidden)
        }
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
}
