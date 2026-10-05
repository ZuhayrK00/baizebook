import SwiftUI

struct HistoryView: View {
    @Environment(AppStore.self) private var store
    @State private var search = ""
    @State private var filter = "All"
    @State private var addPast = false
    var matches: [Match] { store.matches.filter { (filter == "All" || (filter == "Completed" ? $0.isComplete : !$0.isComplete)) && (search.isEmpty || store.names($0).contains { $0.localizedCaseInsensitiveContains(search) }) } }
    var body: some View {
        List {
            Section { Picker("Matches", selection: $filter) { ForEach(["All", "Completed", "In progress"], id: \.self) { Text($0) } }.pickerStyle(.segmented) }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            if matches.isEmpty { ContentUnavailableView("Your time at the table", systemImage: "clock.arrow.circlepath", description: Text("Play a match, import your history or add a past game.")) .listRowBackground(Color.clear) }
            ForEach(matches) { match in NavigationLink { MatchHistoryView(matchID: match.id) } label: { MatchRow(match: match) } }
        }.scrollContentBackground(.hidden).background(Theme.canvas).navigationTitle("History").searchable(text: $search, prompt: "Search players")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Add past game", systemImage: "plus") { addPast = true }.accessibilityIdentifier("add-past-game") } }.sheet(isPresented: $addPast) { PastMatchView() }
    }
}
struct MatchHistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var matchID: UUID
    @State private var delete = false
    var body: some View {
        if let match = store.matches.first(where: { $0.id == matchID }) {
            let names = store.names(match)
            List {
                Section {
                    MatchRow(match: match)
                    LabeledContent("Format", value: "\(match.formatLabel) · \(match.reds) reds")
                    LabeledContent("Scoring", value: match.source ?? (match.traditional ? "Traditional" : "Ball by ball"))
                    if let winner = match.winner { LabeledContent("Winner", value: names[winner]) }
                    else if match.isComplete { LabeledContent("Result", value: "Session saved · level") }
                    if !match.isComplete { NavigationLink("Resume match") { MatchView(matchID: matchID) } }
                }
                Section("Frames") {
                    ForEach(Array(match.frames.enumerated()), id: \.element.id) { index, frame in
                        NavigationLink { FrameHistoryView(matchID: matchID, frameID: frame.id) } label: {
                            HStack { VStack(alignment: .leading, spacing: 5) { Text("Frame \(index+1)").font(.headline); Text(frame.state.winner.map { "\(names[$0]) won" } ?? "No result recorded").font(.caption).foregroundStyle(.secondary) }; Spacer(); Text("\(frame.state.scores[0])–\(frame.state.scores[1])").font(.system(.title3, design: .rounded, weight: .semibold)) }.padding(.vertical, 6)
                        }
                    }
                }
                Section { Button("Delete match", role: .destructive) { delete = true }.accessibilityIdentifier("delete-match") }
            }.scrollContentBackground(.hidden).background(Theme.canvas).navigationTitle("Match history").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $delete) {
                ConfirmationSheet(title: "Delete this match?", message: "This removes its frames and statistics from both players. Export a backup first if you want to keep a copy.", icon: "trash") {
                    Button(role: .destructive) { store.perform { try store.deleteMatch(matchID); delete = false; dismiss() } } label: {
                        Label("Delete match", systemImage: "trash").font(.headline).frame(maxWidth: .infinity, minHeight: 50).background(Color.red.opacity(0.09), in: Capsule())
                    }.buttonStyle(.plain).foregroundStyle(.red).accessibilityIdentifier("confirm-delete-match")
                }
            }
        }
    }
}
struct FrameHistoryView: View {
    @Environment(AppStore.self) private var store
    var matchID: UUID
    var frameID: UUID
    @State private var edit = false
    var body: some View {
        if let match = store.matches.first(where: { $0.id == matchID }), let frame = match.frames.first(where: { $0.id == frameID }) {
            FrameTimeline(frame: frame, names: store.names(match))
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button("Undo", systemImage: "arrow.uturn.backward") { store.perform { try store.editFrame(matchID, frameID: frameID, undo: true) } }.disabled(!frame.canUndo).accessibilityIdentifier("history-undo")
                    Spacer()
                    Button("Redo", systemImage: "arrow.uturn.forward") { store.perform { try store.editFrame(matchID, frameID: frameID, redo: true) } }.disabled(!frame.canRedo).accessibilityIdentifier("history-redo")
                    Spacer()
                    Button("Edit", systemImage: "pencil") { edit = true }.accessibilityIdentifier("edit-frame")
                }.font(.subheadline.weight(.semibold)).padding(18).background(.ultraThinMaterial)
            }.sheet(isPresented: $edit) { FrameEditor(matchID: matchID, frame: frame, names: store.names(match)) }
        }
    }
}
private struct VisitLine: Identifiable {
    var id = UUID(); var ball: Ball?; var points: Int; var text: String; var running: Int
}
private struct Visit: Identifiable {
    var id = UUID(); var player: Int; var date: Date; var points = 0; var lines: [VisitLine] = []
}
struct FrameTimeline: View {
    var frame: Frame
    var names: [String]
    @State private var showSafeties = false
    private func isSafety(_ visit: Visit) -> Bool { visit.points == 0 && visit.lines.allSatisfy { $0.text == "Safety / no pot" || $0.text == "End of visit" } }
    private var visits: [Visit] {
        var result: [Visit] = []; var visit: Visit?
        func flush() { if let saved = visit { result.append(saved) }; visit = nil }
        func add(id: UUID, player: Int, date: Date, ball: Ball?, points: Int, text: String, end: Bool) {
            if visit?.player != player { flush() }
            if visit == nil { visit = Visit(id: id, player: player, date: date) }
            visit!.points += points; visit!.lines.append(VisitLine(id: id, ball: ball, points: points, text: text, running: visit!.points))
            if end { flush() }
        }
        for e in (frame.archive?.events ?? []).prefix(frame.archive?.cursor ?? frame.archive?.events.count ?? 0) {
            add(id: e.id, player: e.player, date: e.date, ball: e.points > 0 ? e.ball : nil, points: e.points, text: e.penalty > 0 ? "Foul · \(e.penalty) to \(names[1-e.player])\(e.disposition == "FREE_BALL" ? " · free ball" : "")" : e.points == 0 ? "Safety / no pot" : e.freeBall ? "Free ball · \(e.points)" : e.redCount > 1 ? "\(e.redCount) reds" : e.ball?.name ?? "Points", end: e.points == 0 || e.penalty > 0)
        }
        for shot in frame.shots {
            let p = shot.before.activePlayer
            switch shot.action {
            case .pot(let ball, let count): add(id: shot.id, player: p, date: shot.date, ball: ball, points: ball.rawValue*count, text: count > 1 ? "\(count) reds" : ball.name, end: false)
            case .freeBall(let ball, let also): add(id: shot.id, player: p, date: shot.date, ball: ball, points: shot.before.ballOn * (also && shot.before.phase == .red ? 2 : 1), text: "Free ball", end: false)
            case .foul(let points, _, _, _): add(id: shot.id, player: p, date: shot.date, ball: nil, points: 0, text: "Foul · \(points) to \(names[1-p])", end: true)
            case .endTurn, .switchPlayer: add(id: shot.id, player: p, date: shot.date, ball: nil, points: 0, text: "End of visit", end: true)
            case .correctFrame(let scores, let winner, _, _): flush(); add(id: shot.id, player: winner ?? p, date: shot.date, ball: nil, points: 0, text: "Result corrected · \(scores[0])–\(scores[1])" + (winner.map { " · \(names[$0]) won" } ?? ""), end: true)
            case .awardFrame(let winner): flush(); add(id: shot.id, player: winner, date: shot.date, ball: nil, points: 0, text: "Frame won", end: true)
            default: flush(); add(id: shot.id, player: p, date: shot.date, ball: nil, points: 0, text: shot.summary, end: true)
            }
        }
        flush(); return result
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 15) {
                    Text(frame.displayDate.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                    ForEach(0...1, id: \.self) { p in HStack { Avatar(name: names[p], size: 32); VStack(alignment: .leading, spacing: 3) { Text(names[p]).font(.headline); let highest = max(frame.state.breaks.filter { $0.player == p }.map(\.points).max() ?? 0, frame.state.activePlayer == p ? frame.state.breakScore : 0); if highest > 0 { Text("Highest break \(highest)").font(.caption2).foregroundStyle(.secondary) } }; Spacer(); if frame.state.winner == p { Image(systemName: "crown.fill").foregroundStyle(Theme.gold) }; Text("\(frame.state.scores[p])").font(.system(size: 31, weight: .semibold, design: .rounded)).monospacedDigit() } }
                }.panel()
                if frame.archive?.manualScores != nil { Label("Scores entered from a past game", systemImage: "pencil.line").font(.footnote).foregroundStyle(.secondary) }
                if visits.contains(where: isSafety) { Toggle("Show safety visits", isOn: $showSafeties).font(.footnote).padding(.horizontal, 4) }
                if visits.isEmpty { ContentUnavailableView("No shot history", systemImage: "circle.grid.2x2", description: Text("Manual games keep their scores and reported breaks without inventing shots.")) }
                ForEach(visits.filter { showSafeties || !isSafety($0) }) { visit in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) { Avatar(name: names[visit.player], size: 28); VStack(alignment: .leading, spacing: 2) { Text(names[visit.player]).font(.subheadline.weight(.semibold)); Text(visit.date, style: .time).font(.caption2).foregroundStyle(.secondary) }; Spacer(); if visit.points > 0 { Text("\(visit.points)").font(.system(size: 25, weight: .semibold, design: .rounded)); Text("break").font(.caption).foregroundStyle(.secondary) } }
                        Divider()
                        ForEach(visit.lines) { line in HStack(spacing: 12) {
                            if let ball = line.ball { BallGlyph(ball: ball, size: 28) } else { Image(systemName: line.text.hasPrefix("Foul") ? "exclamationmark.circle" : line.text == "Frame won" ? "checkmark.seal" : "minus").foregroundStyle(line.text.hasPrefix("Foul") ? .orange : Theme.green).frame(width: 28) }
                            Text(line.text).font(.subheadline).foregroundStyle(line.ball == nil ? .secondary : .primary)
                            Spacer(); if line.points > 0 { Text("\(line.running)").font(.system(.subheadline, design: .rounded, weight: .medium)).monospacedDigit().foregroundStyle(.secondary) }
                        } }
                    }.padding(16).background(.background, in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.green.opacity(0.09)))
                }
            }.padding(18).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }.background(Theme.canvas).navigationTitle("Frame story").navigationBarTitleDisplayMode(.inline)
    }
}
