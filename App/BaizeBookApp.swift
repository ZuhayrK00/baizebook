import SwiftUI

@main struct BaizeBookApp: App {
    @State private var store: AppStore?
    private var startupError: String?
    @AppStorage("appearance") private var appearance = "system"
    init() {
        do { _store = State(initialValue: try AppStore()) }
        catch { startupError = error.localizedDescription }
    }
    var body: some Scene {
        WindowGroup {
            Group {
                if let store { RootView().environment(store) }
                else {
                    ContentUnavailableView {
                        Label("Your data needs attention", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text("BaizeBook could not open its local database. Your saved files have been preserved. \(startupError ?? "Please restart the app.")")
                    }
                }
            }
            .tint(Theme.green)
            .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        @Bindable var store = store
        TabView {
            NavigationStack { HomeView() }.tabItem { Label("Play", systemImage: "circle.grid.2x2.fill") }
            NavigationStack { PlayersView() }.tabItem { Label("Players", systemImage: "person.2.fill") }
            NavigationStack { HistoryView() }.tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            NavigationStack { SettingsView() }.tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
        }
        .id(store.dataResetID)
        .alert("BaizeBook", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("OK") { store.message = nil }
        } message: { Text(store.message ?? "") }
        .overlay { if store.importLoading { ProgressView("Reading games…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)) } }
        .onOpenURL { store.prepareImport($0) }
        .sheet(isPresented: Binding(get: { store.importPreview != nil }, set: { if !$0 { store.importPreview = nil } })) { ImportPreviewView() }
    }
}
