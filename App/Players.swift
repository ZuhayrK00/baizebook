import SwiftUI
import Charts

struct PlayersView: View {
    @Environment(AppStore.self) private var store
    @State private var addPlayer = false
    @State private var search = ""
    @State private var archived = false
    var filtered: [Player] { store.players.filter { (archived || !$0.archived) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }
    var body: some View {
        List {
            if filtered.isEmpty {
                ContentUnavailableView { Label(search.isEmpty ? "Your table starts here" : "No players found", systemImage: "person.2") } description: { Text("Add the people you play with. Their breaks and results will build up here.") } actions: { Button("Add player") { addPlayer = true }.buttonStyle(.borderedProminent) }
                    .listRowBackground(Color.clear)
            }
            ForEach(filtered) { player in
                NavigationLink { PlayerDetail(playerID: player.id) } label: {
                    let stats = PlayerStats(playerID: player.id, matches: store.matches)
                    HStack(spacing: 14) {
                        Avatar(name: player.name)
                        VStack(alignment: .leading, spacing: 5) { Text(player.name).font(.headline); Text(player.archived ? "Archived" : "\(stats.matchesPlayed) matches · \(stats.matchesWon) wins").font(.caption).foregroundStyle(.secondary) }
                        Spacer(); VStack(alignment: .trailing, spacing: 3) { Text("\(stats.highestBreak)").font(.system(.title3, design: .rounded, weight: .semibold)); Text("Best break").font(.caption2).foregroundStyle(.secondary) }
                    }.padding(.vertical, 8)
                }
            }
        }.scrollContentBackground(.hidden).background(Theme.canvas).navigationTitle("Players").searchable(text: $search, prompt: "Find a player")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { if store.players.contains(where: \.archived) { Button(archived ? "Hide archived" : "Show archived") { archived.toggle() }.font(.caption) } }
                ToolbarItem(placement: .topBarTrailing) { Button("Add player", systemImage: "plus") { addPlayer = true }.accessibilityIdentifier("add-player") }
            }.sheet(isPresented: $addPlayer) { PlayerEditor() }
    }
}
struct PlayerEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var player: Player? = nil
    @State private var name = ""
    @State private var archived = false
    @State private var error: String?
    var body: some View {
        NavigationStack { ContentSizedSheet {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Player name").font(.subheadline.weight(.semibold))
                    TextField("Name", text: $name).textFieldStyle(.roundedBorder).textContentType(.name).autocorrectionDisabled().accessibilityIdentifier("player-name")
                }
                if player != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Archive player", isOn: $archived)
                        Text("Archived players keep all their history and statistics. Unarchive them to start new matches.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            }
        }.navigationTitle(player == nil ? "Add player" : "Edit player").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do { if let player { try store.editPlayer(player, name: name, archived: archived) } else { try store.addPlayer(name) }; dismiss() }
                        catch { self.error = error.localizedDescription }
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 40).accessibilityIdentifier("save-player")
                }
            }.onAppear { name = player?.name ?? ""; archived = player?.archived ?? false }
        }
    }
}
struct PlayerDetail: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    var playerID: UUID
    @State private var editing = false
    var body: some View {
        if let player = store.players.first(where: { $0.id == playerID }) {
            let stats = PlayerStats(playerID: playerID, matches: store.matches)
            let matches = store.matches.filter { $0.playerIDs.contains(playerID) }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 16) { Avatar(name: player.name, size: 64); VStack(alignment: .leading, spacing: 5) { Text(player.name).font(.title.weight(.semibold)); Text(player.archived ? "Archived player" : "Your game, in numbers").font(.subheadline).foregroundStyle(.secondary) } }.padding(.vertical, 12)
                    LazyVGrid(columns: typeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatTile(value: "\(stats.highestBreak)", label: "Highest break", icon: "sparkles")
                        StatTile(value: stats.winRate.formatted(.percent.precision(.fractionLength(0))), label: "Match win rate", icon: "chart.line.uptrend.xyaxis")
                        StatTile(value: "\(stats.matchesPlayed)", label: "Matches played", icon: "flag.checkered")
                        StatTile(value: "\(stats.matchesWon)", label: "Matches won", icon: "trophy")
                        StatTile(value: "\(stats.framesPlayed)", label: "Frames played", icon: "square.stack")
                        StatTile(value: "\(stats.framesWon)", label: "Frames won", icon: "checkmark.seal")
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        SectionTitle(title: "Break milestones")
                        HStack { milestone("30+", count: stats.breaks30); Spacer(); milestone("50+", count: stats.breaks50); Spacer(); milestone("100+", count: stats.centuries) }
                        Text("Includes breaks recorded ball by ball. Manual score adjustments don't count as breaks.").font(.caption).foregroundStyle(.secondary)
                    }.panel()
                    let recentBreaks = breakPoints(matches: matches)
                    if !recentBreaks.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionTitle(title: "Recent breaks", detail: "LAST \(recentBreaks.count)")
                            Chart(Array(recentBreaks.enumerated()), id: \.offset) { index, points in BarMark(x: .value("Break", index+1), y: .value("Points", points)).foregroundStyle(Theme.green.gradient).cornerRadius(4) }.frame(height: 150).chartXAxis(.hidden)
                        }.panel()
                    }
                    if !matches.isEmpty {
                        SectionTitle(title: "Head to head")
                        VStack(spacing: 16) {
                            ForEach(store.players.filter { opponent in opponent.id != playerID && matches.contains(where: { $0.playerIDs.contains(opponent.id) }) }) { opponent in
                                let meetings = matches.filter { $0.isComplete && $0.playerIDs.contains(opponent.id) }
                                let wins = meetings.filter { $0.winner == $0.playerIDs.firstIndex(of: playerID) }.count
                                HStack { Text(opponent.name).font(.headline); Spacer(); Text("\(wins)–\(meetings.count-wins)").font(.system(.title3, design: .rounded, weight: .semibold)) }
                            }
                        }.panel()
                        SectionTitle(title: "Match history")
                        VStack { ForEach(matches) { match in NavigationLink { MatchHistoryView(matchID: match.id) } label: { MatchRow(match: match) }.buttonStyle(.plain) } }.panel()
                    }
                    Text("Match totals include completed matches. Frame totals include completed frames. Highest break includes the current break.").font(.caption).foregroundStyle(.secondary)
                }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
            }.background(Theme.canvas).navigationTitle("Player stats").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { editing = true } } }
                .sheet(isPresented: $editing) { PlayerEditor(player: player) }
        }
    }
    private func milestone(_ title: String, count: Int) -> some View { VStack(alignment: .leading, spacing: 6) { Text("\(count)").font(.system(.title, design: .rounded, weight: .semibold)); Text("\(title) breaks").font(.caption).foregroundStyle(.secondary) } }
    private func breakPoints(matches: [Match]) -> [Int] {
        Array(matches.sorted { $0.createdAt < $1.createdAt }.flatMap { m -> [Int] in let p = m.playerIDs.firstIndex(of: playerID)!; return m.frames.flatMap { f in f.state.breaks.filter { $0.player == p }.map(\.points) } }.suffix(12))
    }
}
