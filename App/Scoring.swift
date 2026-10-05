import SwiftUI

struct MatchView: View {
    @Environment(AppStore.self) private var store
    @AppStorage("haptics") private var haptics = true
    @AppStorage("keepAwake") private var keepAwake = true
    var matchID: UUID
    @State private var foul = false
    @State private var redShot: Shot?
    @State private var freeBall = false
    @State private var finish = false
    @State private var endSession = false
    @State private var showShots = false
    @State private var adjustedPlayer: Int?
    private var match: Match? { store.matches.first { $0.id == matchID } }
    var body: some View {
        Group {
            if let match {
                let state = match.frame.state
                let names = store.names(match)
                GeometryReader { geometry in
                    let compact = geometry.size.height < 700
                    VStack(spacing: compact ? 4 : 10) {
                        HStack {
                            Text("FRAME \(match.frames.count)").font(.system(size: 11, weight: .bold)).tracking(2)
                            Text("· \(match.formatLabel)").font(.system(size: 12))
                            Spacer()
                            TimelineView(.periodic(from: .now, by: 1)) { timeline in Label(duration(state.duration(at: timeline.date)), systemImage: state.resumedAt == nil ? "pause" : "clock").font(.system(size: 12, weight: .medium)).monospacedDigit() }
                        }.foregroundStyle(.secondary)
                        HStack(spacing: 10) {
                            ForEach(0...1, id: \.self) { p in
                                Button { if state.phase != .finished && !match.isComplete { score(.switchPlayer(p)) } } label: {
                                    VStack(spacing: 4) {
                                        HStack(spacing: 5) { Circle().fill(state.activePlayer == p && state.phase != .finished && !match.isComplete ? Theme.green : .clear).frame(width: 5, height: 5); Text(names[p]).font(.system(size: compact ? 14 : 17, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.55) }
                                        Text("\(state.scores[p])").font(.system(size: compact ? 42 : 56, weight: .medium, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6).frame(height: compact ? 50 : 67).accessibilityIdentifier("score-\(p)")
                                        Text("\(match.wins[p]) \(match.wins[p] == 1 ? "frame" : "frames")").font(.system(size: 11)).foregroundStyle(.secondary)
                                    }.frame(maxWidth: .infinity).padding(.vertical, compact ? 8 : 12)
                                    .background(state.activePlayer == p ? Theme.green.opacity(0.09) : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
                                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(state.activePlayer == p ? Theme.green.opacity(0.4) : .primary.opacity(0.04)))
                                }.buttonStyle(.plain).accessibilityIdentifier("switch-player-\(p)").accessibilityHint("Switch the turn to \(names[p])")
                            }
                        }
                        if state.phase == .finished || match.isComplete { result(match, names: names) }
                        else {
                            HStack {
                                Text(match.traditional ? "Traditional scoreboard" : "\(names[state.activePlayer])'s turn").font(.system(size: compact ? 15 : 18, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.6).accessibilityIdentifier("current-turn")
                                Spacer()
                                Text(state.lead == 0 ? "Level" : "\(abs(state.lead)) \(state.lead > 0 ? "ahead" : "behind")").font(.system(size: 12)).foregroundStyle(.secondary)
                            }.padding(.horizontal, 3)
                            if match.traditional { traditionalControls(match, names: names) }
                            else { guidedControls(match, compact: compact) }
                            if state.resumedAt == nil { Text("Paused · resume to score").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.green) }
                        }
                        HStack(spacing: 6) {
                            Button { store.undo(matchID); feedback() } label: { Label("Undo", systemImage: "arrow.uturn.backward").font(.system(size: 12, weight: .medium)).frame(maxWidth: .infinity, minHeight: 38) }.disabled(!match.canUndo).accessibilityIdentifier("undo")
                            Button { store.redo(matchID); feedback() } label: { Label("Redo", systemImage: "arrow.uturn.forward").font(.system(size: 12, weight: .medium)).frame(maxWidth: .infinity, minHeight: 38) }.disabled(!match.canRedo).accessibilityIdentifier("redo")
                            if state.phase != .finished && !match.isComplete { Button { score(.pause(state.resumedAt != nil)) } label: { Label(state.resumedAt == nil ? "Resume" : "Pause", systemImage: state.resumedAt == nil ? "play" : "pause").font(.system(size: 12, weight: .medium)).frame(maxWidth: .infinity, minHeight: 38) }.accessibilityIdentifier("pause") }
                        }.buttonStyle(.plain).foregroundStyle(Theme.green).background(.thinMaterial, in: Capsule())
                        Spacer(minLength: 0)
                    }.padding(compact ? 10 : 16).frame(maxWidth: 680).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }.background(Theme.canvas)
                    .sheet(isPresented: $foul) { FoulView(match: match) { score($0); foul = false } }
                    .sheet(item: $redShot) { shot in MultipleRedsView(maximum: shot.before.redsRemaining) { store.reviseRedPot(matchID, total: $0, shotID: shot.id); feedback(); redShot = nil } }
                    .sheet(isPresented: $freeBall) { FreeBallView(state: state) { score($0); freeBall = false } }
                    .sheet(isPresented: $showShots) { NavigationStack { FrameHistoryView(matchID: matchID, frameID: match.frame.id).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showShots = false } } } } }
                    .sheet(isPresented: Binding(get: { adjustedPlayer != nil }, set: { if !$0 { adjustedPlayer = nil } })) { if let p = adjustedPlayer { ScoreAdjustmentView(name: names[p]) { score(.adjustScore(player: p, delta: $0)); adjustedPlayer = nil } } }
                    .sheet(isPresented: $finish) {
                        ConfirmationSheet(title: "Who won this frame?", message: "Choose the winner, including when a frame is conceded. You can undo this result.", icon: "flag.checkered") {
                            ForEach(0...1, id: \.self) { p in WinnerChoice(name: names[p], score: state.scores[p]) { score(.awardFrame(p)); finish = false } }
                        }
                    }
                    .sheet(isPresented: $endSession) {
                        ConfirmationSheet(title: "End this session?", message: "Completed frames count towards the result. An unfinished frame stays in history without a winner.", icon: "checkmark.circle") {
                            PrimaryButton(title: "End session and save", icon: "checkmark") { store.closeMatch(matchID); endSession = false }
                        }
                    }
            } else { ContentUnavailableView("Match not found", systemImage: "flag.checkered") }
        }.navigationTitle("At the table").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { if let match { Menu {
                Button("Frame timeline", systemImage: "list.bullet.rectangle") { showShots = true }
                if match.frame.state.phase != .finished && !match.isComplete { Button("Finish frame", systemImage: "flag.checkered") { finish = true } }
                if match.bestOf == 0 && !match.isComplete { Button("End session", systemImage: "checkmark.circle") { endSession = true } }
                ShareLink(item: "BaizeBook · \(store.names(match).joined(separator: " vs ")) · \(match.wins[0])–\(match.wins[1])") { Label("Share score", systemImage: "square.and.arrow.up") }
            } label: { Image(systemName: "ellipsis") }.accessibilityIdentifier("match-menu") } } }
            .onAppear { store.select(matchID); UIApplication.shared.isIdleTimerDisabled = keepAwake }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
    private func guidedControls(_ match: Match, compact: Bool) -> some View {
        let state = match.frame.state
        return VStack(spacing: compact ? 4 : 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) { Text("BREAK").font(.system(size: 10, weight: .bold)).tracking(1.3); Text("\(state.breakScore)").font(.system(size: compact ? 23 : 30, weight: .semibold, design: .rounded)) }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) { Text("REMAINING").font(.system(size: 10, weight: .bold)).tracking(1.3); Text("\(state.remaining)").font(.system(size: compact ? 23 : 30, weight: .semibold, design: .rounded)) }
            }.foregroundStyle(.white).padding(.horizontal, 4)
            HStack {
                Text(state.phase == .red ? "Red on" : state.phase == .colour ? "Colour on" : state.phase == .respottedBlack ? "Re-spotted black" : "\(Ball(rawValue: state.nextColour)!.name) on").font(.system(size: 12, weight: .semibold))
                Spacer()
                if state.freeBallAvailable { Button("Free ball") { freeBall = true }.font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.gold) }
                else if state.snookersNeeded > 0 { Text("\(state.snookersNeeded) snookers needed").font(.system(size: 11)) }
            }.foregroundStyle(.white.opacity(0.7))
            VStack(spacing: compact ? 4 : 12) {
                HStack(spacing: 8) { ForEach(Array(Ball.allCases.prefix(4))) { ball in tableBall(ball, state: state, compact: compact) } }
                HStack(spacing: 8) { ForEach(Array(Ball.allCases.suffix(3))) { ball in tableBall(ball, state: state, compact: compact) } }.padding(.horizontal, 20)
            }
            if match.frame.redPotMaximum != nil, let shot = match.frame.shots.last {
                Button { redShot = shot } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "plus.circle")
                        Text("Potted multiple reds?")
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                    }.font(.system(size: 12, weight: .semibold)).padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 44).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).foregroundStyle(.white.opacity(0.9)).disabled(state.resumedAt == nil).accessibilityIdentifier("multiple-reds")
            }
            HStack(spacing: 9) {
                Button { foul = true } label: { Label("Foul", systemImage: "exclamationmark.circle").font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 44).background(.white.opacity(0.12), in: Capsule()) }.foregroundStyle(.white).accessibilityIdentifier("foul")
                Button { score(.endTurn) } label: { Label("End turn", systemImage: "arrow.left.arrow.right").font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 44).background(Color(red: 0.83, green: 0.91, blue: 0.72), in: Capsule()) }.foregroundStyle(Theme.forest).accessibilityIdentifier("end-turn")
            }.buttonStyle(.plain).disabled(state.resumedAt == nil)
        }.padding(compact ? 12 : 16).background(LinearGradient(colors: [Theme.forest, Color(red: 0.08, green: 0.25, blue: 0.19)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 25)).overlay(RoundedRectangle(cornerRadius: 25).stroke(Theme.gold.opacity(0.25)))
    }
    private func tableBall(_ ball: Ball, state: FrameState, compact: Bool) -> some View {
        let available = state.legalBalls.contains(ball)
        return Button { score(.pot(ball)) } label: { VStack(spacing: 3) { BallGlyph(ball: ball, value: ball == .red ? state.redsRemaining : ball.rawValue, size: compact ? 40 : 50); Text(ball.name).font(.system(size: 10, weight: .medium)).foregroundStyle(.white) }.frame(maxWidth: .infinity, minHeight: 55).opacity(available ? 1 : 0.3) }.buttonStyle(.plain).disabled(!available || state.resumedAt == nil).accessibilityLabel("Pot \(ball.name.lowercased())\(ball == .red ? ", \(state.redsRemaining) remaining" : "")").accessibilityIdentifier("ball-\(ball.rawValue)")
    }
    private func traditionalControls(_ match: Match, names: [String]) -> some View {
        VStack(spacing: 12) {
            ForEach(0...1, id: \.self) { p in VStack(alignment: .leading, spacing: 5) { Text(names[p]).font(.system(size: 13, weight: .semibold)); HStack { ForEach([-1,1,5,10], id: \.self) { delta in Button("\(delta > 0 ? "+" : "")\(delta)") { score(.adjustScore(player: p, delta: delta)) }.font(.system(size: 17, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 44).buttonStyle(.bordered).disabled((delta < 0 && match.frame.state.scores[p] == 0) || match.frame.state.resumedAt == nil).accessibilityIdentifier("adjust-\(p)-\(delta)") }; Button { adjustedPlayer = p } label: { Image(systemName: "plusminus") }.buttonStyle(.bordered).disabled(match.frame.state.resumedAt == nil) } } }
            Button("Finish frame", systemImage: "flag.checkered") { finish = true }.buttonStyle(.borderedProminent).controlSize(.large)
        }.padding(14).background(.background, in: RoundedRectangle(cornerRadius: 22))
    }
    private func result(_ match: Match, names: [String]) -> some View {
        VStack(spacing: 18) {
            Image(systemName: match.isComplete ? "trophy.fill" : "checkmark.seal.fill").font(.system(size: 34)).foregroundStyle(Theme.gold)
            Text((match.isComplete ? match.winner : match.frame.state.winner).map { "\(names[$0]) wins \(match.isComplete ? "the match" : "the frame")" } ?? "Session saved").font(.title3.weight(.semibold)).multilineTextAlignment(.center)
            if !match.isComplete { PrimaryButton(title: "Next frame", icon: "arrow.right") { store.nextFrame(matchID) }; if match.bestOf == 0 { Button("End session") { endSession = true } } }
            else { Text("Saved to your match history").font(.footnote).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity).panel()
    }
    private func score(_ action: ScoringAction) { store.act(action, matchID: matchID); feedback() }
    private func feedback() { if haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() } }
    private func duration(_ interval: TimeInterval) -> String { let s = Int(max(0, interval)); return s >= 3600 ? String(format: "%d:%02d:%02d", s/3600, s/60%60, s%60) : String(format: "%02d:%02d", s/60, s%60) }
}
struct FoulView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var match: Match
    var onApply: (ScoringAction) -> Void
    @State private var points = 4
    @State private var removed = 0
    @State private var choice = 0
    private let options = ["Opponent plays", "Free ball", "Pass back", "Miss / replace"]
    var body: some View {
        NavigationStack { ContentSizedSheet {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 9) { Text("Penalty points").font(.subheadline.weight(.semibold)); Picker("Foul points", selection: $points) { ForEach(match.frame.state.minimumFoul...7, id: \.self) { Text("\($0)").tag($0) } }.pickerStyle(.segmented) }
                Stepper("Reds removed: \(removed)", value: $removed, in: 0...match.frame.state.redsRemaining).font(.subheadline).disabled(choice == 3)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Next shot").font(.subheadline.weight(.semibold))
                    LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible())], spacing: 8) {
                        ForEach(0..<4) { item in Button { choice = item } label: { HStack(spacing: 5) { Image(systemName: choice == item ? "checkmark.circle.fill" : "circle"); Text(options[item]).font(.system(size: 13, weight: .medium)); Spacer(minLength: 0) }.padding(12).frame(maxWidth: .infinity, minHeight: 44).background(choice == item ? Theme.green.opacity(0.12) : .primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14)) }.buttonStyle(.plain).disabled(item == 1 && (match.frame.state.phase == .respottedBlack || (match.frame.state.phase == .clearance && match.frame.state.nextColour == 7))) }
                    }
                }
                Text("\(points) points to \(store.names(match)[1-match.frame.state.activePlayer]). \(choice < 2 ? store.names(match)[1-match.frame.state.activePlayer] : store.names(match)[match.frame.state.activePlayer]) plays\(choice == 3 ? " again with the balls replaced" : " next").").font(.footnote).foregroundStyle(.secondary)
                PrimaryButton(title: "Record foul", icon: "checkmark") { onApply(.foul(points: points, removedReds: choice == 3 ? 0 : removed, disposition: choice < 2 ? .opponent : choice == 2 ? .playAgain : .replaceAndPlayAgain, freeBall: choice == 1)) }.accessibilityIdentifier("record-foul")
            }
        }.navigationTitle("Foul").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }.onAppear { points = match.frame.state.minimumFoul } }
    }
}
struct MultipleRedsView: View {
    var maximum: Int
    var onApply: (Int) -> Void
    @State private var count = 2
    var body: some View {
        ConfirmationSheet(title: "How many reds?", message: "Choose the total potted in that shot, including the red you just recorded.", icon: "circle.grid.2x2") {
            HStack(spacing: 20) {
                Button { count -= 1 } label: { Image(systemName: "minus").frame(width: 48, height: 48).background(Theme.green.opacity(0.09), in: Circle()) }.disabled(count == 2).accessibilityLabel("Fewer reds")
                Spacer(minLength: 0)
                VStack(spacing: 4) { Text("\(count)").font(.system(size: 36, weight: .semibold, design: .rounded)).monospacedDigit().accessibilityIdentifier("red-total"); Text("reds in this shot").font(.caption).foregroundStyle(.secondary) }
                Spacer(minLength: 0)
                Button { count += 1 } label: { Image(systemName: "plus").frame(width: 48, height: 48).background(Theme.green.opacity(0.09), in: Circle()) }.disabled(count >= maximum).accessibilityLabel("More reds")
            }.buttonStyle(.plain).foregroundStyle(Theme.green).padding(.vertical, 4)
            PrimaryButton(title: "Record \(count) reds", icon: "checkmark") { onApply(count) }.accessibilityIdentifier("record-multiple-reds")
        }
    }
}
struct FreeBallView: View {
    @Environment(\.dismiss) private var dismiss
    var state: FrameState
    var onApply: (ScoringAction) -> Void
    @State private var alsoOn = false
    var body: some View {
        NavigationStack { ContentSizedSheet {
            VStack(alignment: .leading, spacing: 20) {
                Text("Choose the nominated colour you potted. It scores \(state.ballOn) \(state.ballOn == 1 ? "point" : "points") and is re-spotted.").font(.subheadline).foregroundStyle(.secondary)
                Toggle("Also potted the ball on", isOn: $alsoOn)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nominated free ball").font(.subheadline.weight(.semibold))
                    ForEach(Ball.colours.filter { state.phase == .red || $0.rawValue > state.nextColour }) { ball in
                        Button { onApply(.freeBall(ball, alsoPotOn: alsoOn)) } label: { HStack { Circle().fill(ball.color).frame(width: 22, height: 22); Text(ball.name); Spacer(); Image(systemName: "plus.circle") }.frame(minHeight: 44) }
                    }
                }
            }
        }.navigationTitle("Free ball").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } } }
    }
}
struct ScoreAdjustmentView: View {
    @Environment(\.dismiss) private var dismiss
    var name: String
    var onApply: (Int) -> Void
    @State private var amount = 1
    var body: some View {
        NavigationStack { ContentSizedSheet {
            VStack(spacing: 20) {
                Stepper("Adjustment: \(amount >= 0 ? "+" : "")\(amount)", value: $amount, in: -200...200)
                PrimaryButton(title: "Apply to \(name)", icon: "checkmark") { onApply(amount) }.disabled(amount == 0)
            }
        }.navigationTitle("Adjust score").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } } }
    }
}
