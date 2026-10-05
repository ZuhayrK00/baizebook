import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var newMatch = false
    @State private var path: [UUID] = []
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Label("AT THE TABLE", systemImage: "circle.fill").font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(Theme.gold)
                        Spacer()
                        if !typeSize.isAccessibilitySize { Text("147").font(.system(.title, design: .serif, weight: .medium)).foregroundStyle(.white.opacity(0.45)) }
                    }
                    Text(typeSize.isAccessibilitySize ? "Ready to play?" : "Every frame.\nYour story.").font(.system(.largeTitle, design: .serif, weight: .medium)).foregroundStyle(.white)
                    Text(typeSize.isAccessibilitySize ? "Score a new match." : "Keep the score. Find your form.").font(.subheadline).foregroundStyle(.white.opacity(0.75))
                    Button { newMatch = true } label: {
                        HStack { Text("New match").font(.headline); Spacer(); Image(systemName: "arrow.up.right") }.padding(17)
                    }.foregroundStyle(Theme.forest).background(Color(red: 0.84, green: 0.92, blue: 0.73), in: Capsule()).accessibilityIdentifier("new-match")
                }.padding(26).frame(maxWidth: .infinity, alignment: .leading)
                    .background(LinearGradient(colors: [Theme.forest, Color(red: 0.09, green: 0.29, blue: 0.21)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 30))
                if let match = store.activeMatch, !match.isComplete {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle(title: "Back to the baize", detail: "IN PROGRESS")
                        Button { store.select(match.id); path.append(match.id) } label: {
                            VStack(alignment: .leading, spacing: 18) {
                                MatchRow(match: match)
                                HStack {
                                    Text("Frame \(match.frames.count) · \(match.frame.state.scores[0])–\(match.frame.state.scores[1])").font(.subheadline)
                                    Spacer(); Label("Resume", systemImage: "arrow.right").font(.subheadline.weight(.semibold))
                                }.foregroundStyle(Theme.green)
                            }.panel()
                        }.buttonStyle(.plain).accessibilityIdentifier("resume-match")
                    }
                }
                AdaptiveStack(spacing: 12) {
                    StatTile(value: "\(store.matches.filter(\.isComplete).count)", label: "Matches played", icon: "flag.checkered")
                    StatTile(value: "\(store.players.map { PlayerStats(playerID: $0.id, matches: store.matches).highestBreak }.max() ?? 0)", label: "Highest break", icon: "sparkles")
                }
                if !store.matches.isEmpty {
                    SectionTitle(title: "Recent matches")
                    VStack(spacing: 0) {
                        ForEach(Array(store.matches.prefix(3))) { match in
                            Button { store.select(match.id); path.append(match.id) } label: { MatchRow(match: match) }.buttonStyle(.plain)
                            if match.id != store.matches.prefix(3).last?.id { Divider().padding(.vertical, 10) }
                        }
                    }.panel()
                } else {
                    Label("Your scores stay on your devices.", systemImage: "lock.shield").font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 8)
                }
            }.padding(20).frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
        }.background(Theme.canvas).navigationTitle("BaizeBook")
            .sheet(isPresented: $newMatch) { NewMatchView { id in newMatch = false; path.append(id) } }
            .navigationDestination(isPresented: Binding(get: { !path.isEmpty }, set: { if !$0 { path = [] } })) { if let id = path.last { MatchView(matchID: id) } }
    }
}

struct NewMatchView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultReds") private var defaultReds = 15
    @AppStorage("defaultBestOf") private var defaultBestOf = 3
    @AppStorage("defaultTraditional") private var defaultTraditional = false
    @State private var first: UUID?
    @State private var second: UUID?
    @State private var reds = 15
    @State private var bestOf = 3
    @State private var openSession = false
    @State private var starter = 0
    @State private var traditional = false
    @State private var addPlayer = false
    var onStart: (UUID) -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Player one", selection: $first) {
                        Text("Choose player").tag(Optional<UUID>.none)
                        ForEach(store.visiblePlayers) { Text($0.name).tag(Optional($0.id)) }
                    }.accessibilityIdentifier("player-one")
                    Picker("Player two", selection: $second) {
                        Text("Choose player").tag(Optional<UUID>.none)
                        ForEach(store.visiblePlayers) { Text($0.name).tag(Optional($0.id)) }
                    }.accessibilityIdentifier("player-two")
                    Button("Add a player", systemImage: "person.badge.plus") { addPlayer = true }
                } header: { Text("Who's playing?") } footer: { if first == second && first != nil { Text("Choose two different players.") } }
                Section("The match") {
                    Toggle("Open session · no frame limit", isOn: $openSession).accessibilityIdentifier("open-session")
                    if !openSession { Picker("Best of", selection: $bestOf) { ForEach([1,3,5,7,9,11,15,17,19,25,35], id: \.self) { Text("\($0) \($0 == 1 ? "frame" : "frames")").tag($0) } } }
                    Picker("Reds", selection: $reds) { ForEach(1...15, id: \.self) { Text("\($0)").tag($0) } }
                    Picker("Breaks first", selection: $starter) {
                        Text(store.players.first { $0.id == first }?.name ?? "Player one").tag(0)
                        Text(store.players.first { $0.id == second }?.name ?? "Player two").tag(1)
                    }
                }
                Section {
                    Picker("Scoring", selection: $traditional) { Text("Ball by ball").tag(false); Text("Traditional").tag(true) }.pickerStyle(.segmented)
                    Text(traditional ? "Adjust each player's score directly. Ball counts and breaks aren't recorded in this mode." : "Tap each potted ball. BaizeBook tracks the break, balls remaining and points available.").font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    PrimaryButton(title: "Start match", icon: "play.fill") {
                        store.perform {
                            let selected = [first, second].compactMap { id in store.players.first { $0.id == id } }
                            let id = try store.start(players: selected, bestOf: openSession ? 0 : bestOf, reds: reds, starter: starter, traditional: traditional)
                            onStart(id)
                        }
                    }.disabled(first == nil || second == nil || first == second).accessibilityIdentifier("start-match")
                }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }.navigationTitle("New match").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .onAppear {
                    reds = defaultReds; bestOf = defaultBestOf; traditional = defaultTraditional
                    first = store.visiblePlayers.first?.id; second = store.visiblePlayers.dropFirst().first?.id
                }
                .sheet(isPresented: $addPlayer) { PlayerEditor() }
        }
    }
}
