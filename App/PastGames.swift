import SwiftUI

private struct PastFrameEntry: Identifiable {
    var id = UUID(); var scoreText = ["",""]; var breakText = ["",""]; var winner = -1
    var scores: [Int] { scoreText.map { $0.isEmpty ? 0 : Int($0) ?? -1 } }
    var breaks: [Int] { breakText.map { $0.isEmpty ? 0 : Int($0) ?? -1 } }
}
struct PastMatchView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var first: UUID?
    @State private var second: UUID?
    @State private var date = Date()
    @State private var reds = 15
    @State private var entries = [PastFrameEntry()]
    @State private var addPlayer = false
    @FocusState private var entryFocus: String?
    private var names: [String] { [first,second].map { id in store.players.first { $0.id == id }?.name ?? "Player" } }
    var body: some View {
        NavigationStack { Form {
            Section("The game") {
                Picker("Player one", selection: $first) { Text("Choose player").tag(Optional<UUID>.none); ForEach(store.visiblePlayers) { Text($0.name).tag(Optional($0.id)) } }
                Picker("Player two", selection: $second) { Text("Choose player").tag(Optional<UUID>.none); ForEach(store.visiblePlayers) { Text($0.name).tag(Optional($0.id)) } }
                Button("Add a player", systemImage: "person.badge.plus") { addPlayer = true }
                DatePicker("Played on", selection: $date, in: ...Date(), displayedComponents: [.date,.hourAndMinute])
                Picker("Reds", selection: $reds) { ForEach(1...15, id: \.self) { Text("\($0)").tag($0) } }
            }
            ForEach($entries) { $entry in
                Section("Frame \((entries.firstIndex { $0.id == entry.id } ?? 0)+1)") {
                    ForEach(0...1, id: \.self) { p in HStack { Text(names[p]); Spacer(); TextField("Score", text: $entry.scoreText[p]).focused($entryFocus, equals: "score-\(entry.id)-\(p)").keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 80).accessibilityIdentifier("past-score-\(p)") } }
                    Picker("Winner", selection: $entry.winner) { Text("Choose winner").tag(-1); ForEach(0...1, id: \.self) { p in Text(names[p]).tag(p) } }
                    DisclosureGroup("Highest breaks · optional") { ForEach(0...1, id: \.self) { p in HStack { Text(names[p]); Spacer(); TextField("Break", text: $entry.breakText[p]).focused($entryFocus, equals: "break-\(entry.id)-\(p)").keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 80) } } }
                    if entries.count > 1 { Button("Remove frame", role: .destructive) { entries.removeAll { $0.id == entry.id } } }
                }.onChange(of: entry.scoreText) { _, _ in let scores = entry.scores; if scores[0] != scores[1] { if let index = entries.firstIndex(where: { $0.id == entry.id }) { entries[index].winner = scores[0] > scores[1] ? 0 : 1 } } }
            }
            Section { Button("Add another frame", systemImage: "plus.circle") { entries.append(PastFrameEntry()) }.disabled(entries.count >= 100) }
            Section { Text("Record the scores you remember. Highest breaks are optional; no shot history or running timer is created.").font(.footnote).foregroundStyle(.secondary); PrimaryButton(title: "Save past game", icon: "checkmark") { save() }.disabled(first == nil || second == nil || first == second).accessibilityIdentifier("save-past-game") }
        }.selectScoreOnFocus().scrollDismissesKeyboard(.interactively).navigationTitle("Add past game").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { entryFocus = nil } } }
        .onAppear { first = store.visiblePlayers.first?.id; second = store.visiblePlayers.dropFirst().first?.id }.sheet(isPresented: $addPlayer) { PlayerEditor() }
        }
    }
    private func save() {
        store.perform {
            let selected = [first,second].compactMap { id in store.players.first { $0.id == id } }
            guard selected.count == 2 else { throw ScoringError("Choose two players.") }
            var match = Match(players: selected, bestOf: 0, reds: reds, firstPlayer: 0, traditional: true, date: date); match.source = "Manual entry"; match.frames = []
            for (i, entry) in entries.enumerated() {
                guard entry.scores.allSatisfy({ (0...10000).contains($0) }), entry.breaks.allSatisfy({ (0...10000).contains($0) }) else { throw ScoringError("Use whole numbers from 0 to 10,000 for scores and breaks.") }
                guard (0...1).contains(entry.winner) else { throw ScoringError("Choose who won each frame.") }
                var frame = Frame(reds: reds, starter: i%2, date: date)
                let breaks = (0...1).compactMap { p in entry.breaks[p] > 0 ? BreakEntry(player: p, points: entry.breaks[p]) : nil }
                frame.archive = FrameArchive(source: "Manual entry", manualScores: entry.scores, manualBreaks: breaks)
                try frame.archive!.validate(); frame.state = frame.archive!.baseState(reds: reds, starter: i%2, date: date); try frame.record(.awardFrame(entry.winner), date: date); match.frames.append(frame)
            }
            match.closedAt = date; try store.addPastMatch(match); dismiss()
        }
    }
}
struct FrameEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var matchID: UUID
    var frame: Frame
    var names: [String]
    @State private var scoreText = ["",""]
    @State private var highestText = ["",""]
    @FocusState private var editing: Int?
    private var scores: [Int] { scoreText.map { $0.isEmpty ? 0 : Int($0) ?? -1 } }
    private var highest: [Int] { highestText.map { $0.isEmpty ? 0 : Int($0) ?? -1 } }
    @State private var winner = 0
    @State private var date = Date()
    var body: some View {
        NavigationStack { Form {
            Section("Result") {
                ForEach(0...1, id: \.self) { p in HStack { Text(names[p]); Spacer(); TextField("Score", text: $scoreText[p]).focused($editing, equals: p).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 90).accessibilityIdentifier("edit-score-\(p)") } }
                Picker("Winner", selection: $winner) { Text("No result").tag(-1); ForEach(0...1, id: \.self) { p in Text(names[p]).tag(p) } }
                DatePicker("Played on", selection: $date, displayedComponents: [.date,.hourAndMinute])
            }
            Section("Highest breaks") { ForEach(0...1, id: \.self) { p in HStack { Text(names[p]); Spacer(); TextField("Break", text: $highestText[p]).focused($editing, equals: p+2).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 90) } } }
            Section { Text("Corrections update player statistics. The original story stays visible, and Undo restores the previous result.").font(.footnote).foregroundStyle(.secondary); PrimaryButton(title: "Save changes", icon: "checkmark") {
                store.perform {
                    guard highest.allSatisfy({ (0...10000).contains($0) }) else { throw ScoringError("Check the highest breaks.") }
                    var breaks = frame.state.breaks
                    if frame.state.breakScore > 0 { breaks.append(BreakEntry(player: frame.state.activePlayer, points: frame.state.breakScore)) }
                    for p in 0...1 {
                        let oldHighest = breaks.filter { $0.player == p }.map(\.points).max() ?? 0
                        if highest[p] != oldHighest {
                            if highest[p] > oldHighest { breaks.append(BreakEntry(player: p, points: highest[p])) }
                            else { breaks.removeAll { $0.player == p && $0.points > highest[p] }; if highest[p] > 0 && !breaks.contains(where: { $0.player == p && $0.points == highest[p] }) { breaks.append(BreakEntry(player: p, points: highest[p])) } }
                        }
                    }
                    try store.editFrame(matchID, frameID: frame.id, action: .correctFrame(scores: scores, winner: winner == -1 ? nil : winner, breaks: breaks, date: date)); dismiss()
                }
            }.accessibilityIdentifier("save-frame-changes") }
        }.selectScoreOnFocus().scrollDismissesKeyboard(.interactively).navigationTitle("Edit frame").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }.toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editing = nil } } }.onAppear { scoreText = frame.state.scores.map(String.init); winner = frame.state.winner ?? -1; date = frame.displayDate; highestText = (0...1).map { p in String(max(frame.state.breaks.filter { $0.player == p }.map(\.points).max() ?? 0, frame.state.activePlayer == p ? frame.state.breakScore : 0)) } }
        }
    }
}
