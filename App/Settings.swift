import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @AppStorage("defaultReds") private var reds = 15
    @AppStorage("defaultBestOf") private var bestOf = 3
    @AppStorage("defaultTraditional") private var traditional = false
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("haptics") private var haptics = true
    @AppStorage("keepAwake") private var keepAwake = true
    @State private var importing = false
    @State private var exporting = false
    @State private var clearingData = false
    @State private var document = BackupDocument(data: Data())
    var body: some View {
        Form {
            Section("Match defaults") {
                Picker("Reds", selection: $reds) { ForEach(1...15, id: \.self) { Text("\($0)").tag($0) } }
                Picker("Best of", selection: $bestOf) { ForEach([1,3,5,7,9,11,15,17,19,25,35], id: \.self) { Text("\($0) frames").tag($0) } }
                Toggle("Traditional scoreboard", isOn: $traditional)
            }
            Section("At the table") {
                Picker("Appearance", selection: $appearance) { Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark") }
                Toggle("Tap feedback", isOn: $haptics)
                Toggle("Keep screen awake during matches", isOn: $keepAwake)
            }
            Section {
                Button("Export backup", systemImage: "square.and.arrow.up") {
                    store.perform { document = BackupDocument(data: try store.backup().encoded()); exporting = true }
                }.accessibilityIdentifier("export-backup")
                Button("Import games or backup", systemImage: "square.and.arrow.down") { importing = true }.accessibilityIdentifier("import-backup")
                Button(role: .destructive) { clearingData = true } label: {
                    Label("Clear all data", systemImage: "trash")
                }.accessibilityIdentifier("clear-all-data")
            } header: { Text("Your data") } footer: {
                Text("Backups include players, matches and shot history. Keep a copy in Files or share it with another device. Import merges new entries and keeps existing ones. BaizeBook backups and SnookerMate JSON exports are supported.")
            }
            Section("Apple Watch") {
                Label(store.watch.reachable ? "Watch connected" : "Ready for your watch", systemImage: "applewatch")
                Text("Install BaizeBook on your paired Apple Watch. Start a match on iPhone to see its scores, break and timer on your wrist. Open both apps to use live scoring controls.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("About") {
                NavigationLink("How scoring works") { ScoringHelpView() }
                Link("Help and support", destination: URL(string: "https://zuhayrk00.github.io/baizebook/")!)
                NavigationLink("Privacy") { PrivacyView() }
                LabeledContent("Version", value: "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"))")
                Text("Made for time at the table.").font(.footnote).foregroundStyle(.secondary)
            }
        }.scrollContentBackground(.hidden).background(Theme.canvas).navigationTitle("Settings")
            .sheet(isPresented: $clearingData) {
                ConfirmationSheet(title: "Clear all data?", message: "This permanently deletes every player, match, frame, shot and statistic, ends your active match and resets your settings. This cannot be undone. Export a backup first if you want to keep a copy. Backups saved in Files will remain.", icon: "trash") {
                    Button(role: .destructive) {
                        do {
                            try store.clearAllData()
                            clearingData = false
                            store.message = "All data cleared. You're ready for a fresh start."
                        } catch {
                            clearingData = false
                            store.message = error.localizedDescription
                        }
                    } label: {
                        Label("Clear all data", systemImage: "trash").font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.red.opacity(0.09), in: Capsule())
                    }.buttonStyle(.plain).foregroundStyle(.red).accessibilityIdentifier("confirm-clear-all-data")
                }
            }
            .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "BaizeBook-\(Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash)))") { result in if case .failure(let error) = result { store.message = error.localizedDescription } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                store.perform {
                    store.prepareImport(try result.get())
                }
            }
    }
}
struct ImportPreviewView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var links: [UUID: UUID] = [:]
    var body: some View {
        NavigationStack { Form {
            if let draft = store.importPreview {
                Section(draft.source + " export") {
                    LabeledContent("Players", value: "\(draft.backup.players.count)")
                    LabeledContent("Matches", value: "\(draft.backup.matches.count)")
                    LabeledContent("Frames", value: "\(draft.backup.matches.reduce(0) { $0 + $1.frames.count })")
                    LabeledContent("Shots", value: "\(draft.shotCount)")
                }
                Section("Link player profiles") {
                    ForEach(draft.backup.players) { player in
                        Picker(player.name, selection: Binding(get: { links[player.id] ?? player.id }, set: { links[player.id] = $0 })) {
                            Text("Create new profile").tag(player.id)
                            ForEach(store.players.filter { $0.id != player.id }) { Text($0.name).tag($0.id) }
                        }
                    }
                }
                Section { ForEach(draft.notes, id: \.self) { Text($0).font(.footnote).foregroundStyle(.secondary) }; Text("Repeated imports skip existing games. Your edited scores and current data are kept.").font(.footnote) }
                Section { PrimaryButton(title: "Import games", icon: "square.and.arrow.down") { store.perform { let backup = try draft.mapped(to: links, existing: store.players); let result = try store.merge(backup); store.importPreview = nil; dismiss(); store.message = result } }.accessibilityIdentifier("confirm-import") }.listRowBackground(Color.clear)
            }
        }.navigationTitle("Import games").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { store.importPreview = nil; dismiss() } } }
        .onAppear { if let draft = store.importPreview { for player in draft.backup.players { let found = store.players.filter { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(player.name.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame }; if found.count == 1 { links[player.id] = found[0].id } } } }
        }
    }
}
struct PrivacyView: View {
    var body: some View {
        List {
            Section { Label("Your table. Your data.", systemImage: "lock.shield.fill").font(.title3.weight(.semibold)); Text("BaizeBook stores players, match scores and history on your device. It does not collect or transmit your personal data to the developer. There are no accounts, advertisements or analytics.") }
            Section("Apple Watch") { Text("The app sends the selected match to your paired Apple Watch through Apple's WatchConnectivity. Watch scoring actions return to your iPhone. No server is involved.") }
            Section("Backups") { Text("Exporting or sharing a backup sends a file to the destination you choose. A backup includes player names and match history. System device backups may include your app data according to your Apple settings.") }
            Section("Removing data") { Text("Delete a match from its history page to remove its frames and statistics. Clear all data in Settings permanently removes every player and match and resets preferences. Player archiving keeps history. Exported backups remain where you saved them. Export a backup before clearing data, changing devices or reinstalling.") }
        }.navigationTitle("Privacy").navigationBarTitleDisplayMode(.inline)
    }
}
struct ScoringHelpView: View {
    var body: some View {
        List {
            Section("Ball by ball") { Text("Tap a red, then the colour you pot. If several reds went in together, tap Potted multiple reds? before the next shot and choose the total, including the red already recorded. Undo removes that whole shot. Colours are re-spotted while reds remain. After the final red you may pot one more colour, then clear yellow to black in order. End turn switches the player after a miss or safety.") }
            Section("Fouls") { Text("Record 4–7 penalty points for the opponent. Choose the value of the ball on or the ball involved, whichever is higher. Remove any reds pocketed during the foul. Pass back keeps the offending player at the table; miss and replacement restores the ball state.") }
            Section("Free balls") { Text("After a foul, mark a free ball only when the incoming player is snookered on the ball on. Use Free ball to record the nominated colour. A free ball is re-spotted and scores the value of the ball on. If both it and the ball on are potted, each scores during reds; during clearance only the ball on scores.") }
            Section("Re-spotted black") { Text("If scores are level after the final black or a foul on it, the black is re-spotted. Agree who plays first; End turn can switch the player. The next pot or foul decides the frame.") }
            Section("Traditional mode") { Text("Use the score adjustment buttons to mark points manually, then choose the frame winner. Ball counts and break statistics are unavailable for manually entered scores.") }
            Section("Undo and timers") { Text("Undo restores the state before the most recent action. Redo brings it back; scoring a new action clears redo. Tap a player name to switch the turn. Pause stops the frame clock and scoring until you resume. Leaving the app keeps a running frame timer going.") }
            Section("Shortened frames") { Text("Choosing fewer reds uses the normal red-and-colour scoring sequence with a shorter rack. Referee decisions, including competition-specific foul-and-miss limits, remain with the players.") }
            Section { Link("Official WPBSA rules", destination: URL(string: "https://www.wpbsa.com/rules/")!) }
        }.navigationTitle("Scoring guide").navigationBarTitleDisplayMode(.inline)
    }
}
