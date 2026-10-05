import SwiftUI

@main struct BaizeBookWatchApp: App {
    @State private var connection = Connectivity()
    var body: some Scene { WindowGroup { WatchScoreView().environment(connection).onAppear { connection.activate() } } }
}
struct WatchScoreView: View {
    @Environment(Connectivity.self) private var connection
    @State private var colours = false
    @State private var finish = false
    #if DEBUG && targetEnvironment(simulator)
    @State private var probeSent = false
    #endif
    var body: some View {
        NavigationStack {
            if let match = connection.snapshot.match, connection.snapshot.names.count == 2 {
                let state = match.frame.state
                let names = connection.snapshot.names
                TabView {
                    VStack(spacing: 5) {
                        HStack { Text("FRAME \(match.framesCount)"); Spacer(); Text("\(match.wins[0])–\(match.wins[1])") }.font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                        ForEach(0...1, id: \.self) { p in Button { connection.send(.switchPlayer(p)) } label: { HStack { Text(names[p]).font(.system(size: 15, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.6); Spacer(); Text("\(state.scores[p])").font(.system(size: 29, weight: .semibold, design: .rounded)).monospacedDigit() }.foregroundStyle(state.activePlayer == p ? .mint : .white) }.buttonStyle(.plain).disabled(!connected || state.phase == .finished || match.isComplete) }
                        if state.phase == .finished || match.isComplete {
                            Text((match.isComplete ? match.winner : state.winner).map { "\(names[$0]) wins" } ?? "Session saved").font(.caption.weight(.semibold)).foregroundStyle(.yellow).lineLimit(1)
                            if !match.isComplete { Button("Next frame") { connection.send(nil, nextFrame: true) }.tint(.mint).disabled(!connected) }
                        } else {
                            if !match.traditional { HStack { Text("Break \(state.breakScore)"); Spacer(); Text("Left \(state.remaining)") }.font(.system(size: 11)).foregroundStyle(.secondary) }
                            if match.traditional { HStack { ForEach([1,5,10], id: \.self) { points in Button("+\(points)") { connection.send(.adjustScore(player: state.activePlayer, delta: points)) }.disabled(!canScore) } } }
                            else { HStack(spacing: 5) { Button { if state.legalBalls.count == 1, let ball = state.legalBalls.first { connection.send(.pot(ball)) } else { colours = true } } label: { Text(state.phase == .red ? "Pot red · \(state.redsRemaining)" : state.legalBalls.count == 1 ? "Pot \(state.legalBalls[0].name.lowercased())" : "Pot colour").font(.system(size: 14, weight: .semibold)) }.tint(state.phase == .red ? .red : .mint).disabled(!canScore)
                                Button { connection.send(.endTurn) } label: { Image(systemName: "arrow.left.arrow.right").font(.system(size: 14)).frame(minHeight: 34) }.tint(.mint).disabled(!canScore).accessibilityLabel("End turn")
                            } }
                        }
                        if !connection.reachable { Text("Open app on iPhone").font(.system(size: 10)).foregroundStyle(.orange) }
                    }.padding(.horizontal, 2).tag(0)
                    ScrollView {
                        VStack(spacing: 8) {
                            TimelineView(.periodic(from: .now, by: 1)) { timeline in let seconds = Int(state.duration(at: timeline.date)); Label(String(format: "%d:%02d", seconds/60, seconds%60), systemImage: state.resumedAt == nil ? "pause" : "clock").font(.caption).monospacedDigit().foregroundStyle(.secondary) }
                            HStack { Button("Undo") { connection.send(nil, undo: true) }.disabled(!connected || !match.canUndo); Button("Redo") { connection.send(nil, redo: true) }.disabled(!connected || match.canRedo != true) }
                            if state.phase != .finished && !match.isComplete {
                                if state.freeBallAvailable { NavigationLink("Pot free ball") { WatchFreeBallView() }.disabled(!canScore) }
                                NavigationLink("Foul") { WatchFoulView(minimum: state.minimumFoul) }.disabled(!canScore)
                                Button(state.resumedAt == nil ? "Resume timer" : "Pause timer") { connection.send(.pause(state.resumedAt != nil)) }.disabled(!connected)
                                Button("Finish frame") { finish = true }.disabled(!connected)
                            }
                            Button("Refresh score") { connection.refresh() }.font(.caption)
                        }
                    }.tag(1)
                }.tabViewStyle(.page).navigationTitle("BaizeBook")
                .sheet(isPresented: $colours) { List { ForEach(state.legalBalls) { ball in Button { connection.send(.pot(ball)); colours = false } label: { HStack { Circle().fill(ball.watchColor).frame(width: 22,height: 22); Text(ball.name); Spacer(); Text("\(ball.rawValue)").foregroundStyle(.secondary) } }.disabled(!canScore) } }.navigationTitle("Pot colour") }
                .confirmationDialog("Who won this frame?", isPresented: $finish, titleVisibility: .visible) { ForEach(0...1, id: \.self) { p in Button("\(names[p]) wins") { connection.send(.awardFrame(p)) } } }
            } else { VStack(spacing: 14) { Image(systemName: "circle.grid.2x2.fill").font(.largeTitle).foregroundStyle(.mint); Text("Ready for the baize").font(.headline); Text("Start a match on your iPhone.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).lineLimit(2).fixedSize(horizontal: false, vertical: true); Button("Refresh") { connection.refresh() } } }
        }.onAppear { connection.refresh(); probe() }.onChange(of: connection.reachable) { _, _ in probe() }.onChange(of: connection.snapshot.match?.revision) { _, _ in probe() }.onChange(of: connection.snapshot.match?.id) { _, _ in probe() }
        .alert("BaizeBook", isPresented: Binding(get: { connection.message != nil }, set: { if !$0 { connection.message = nil } })) { Button("OK") { connection.message = nil } } message: { Text(connection.message ?? "") }
    }
    private var connected: Bool { connection.reachable && !connection.sending }
    private var canScore: Bool { connected && connection.snapshot.match?.frame.state.resumedAt != nil }
    private func probe() {
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--connection-probe"), !probeSent, canScore, connection.snapshot.match?.traditional == false, let ball = connection.snapshot.match?.frame.state.legalBalls.first { probeSent = true; connection.send(.pot(ball)) }
        #endif
    }
}
struct WatchFoulView: View {
    @Environment(Connectivity.self) private var connection
    @Environment(\.dismiss) private var dismiss
    var minimum: Int
    @State private var points = 4
    @State private var choice = 0
    @State private var removed = 0
    var body: some View { List {
        Picker("Penalty", selection: $points) { ForEach(minimum...7, id: \.self) { Text("\($0) points").tag($0) } }
        Picker("Next shot", selection: $choice) { Text("Opponent plays").tag(0); Text("Free ball").tag(1); Text("Pass back").tag(2); Text("Miss / replace").tag(3) }
        Stepper("Reds removed: \(removed)", value: $removed, in: 0...(connection.snapshot.match?.frame.state.redsRemaining ?? 0)).disabled(choice == 3)
        Button("Record foul") { connection.send(.foul(points: points, removedReds: choice == 3 ? 0 : removed, disposition: choice < 2 ? .opponent : choice == 2 ? .playAgain : .replaceAndPlayAgain, freeBall: choice == 1)); dismiss() }.tint(.mint).disabled(!connection.reachable || connection.sending)
    }.navigationTitle("Foul").onAppear { points = minimum } }
}
struct WatchFreeBallView: View {
    @Environment(Connectivity.self) private var connection
    @Environment(\.dismiss) private var dismiss
    @State private var alsoOn = false
    var body: some View {
        List { if let state = connection.snapshot.match?.frame.state {
            Toggle("Also potted ball on", isOn: $alsoOn)
            ForEach(Ball.colours.filter { state.phase == .red || $0.rawValue > state.nextColour }) { ball in Button(ball.name) { connection.send(.freeBall(ball, alsoPotOn: alsoOn)); dismiss() }.disabled(!connection.reachable || connection.sending || state.resumedAt == nil) }
        } }.navigationTitle("Free ball")
    }
}
extension Ball {
    var watchColor: Color {
        switch self { case .red: .red; case .yellow: .yellow; case .green: .green; case .brown: .brown; case .blue: .blue; case .pink: .pink; case .black: Color(white: 0.18) }
    }
}
