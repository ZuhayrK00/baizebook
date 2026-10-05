import Foundation

enum Ball: Int, Codable, CaseIterable, Identifiable, Sendable {
    case red = 1, yellow, green, brown, blue, pink, black
    var id: Int { rawValue }
    var name: String { String(describing: self).capitalized }
    static var colours: [Ball] { Array(allCases.dropFirst()) }
}

struct Player: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var createdAt = Date()
    var archived = false
}

enum Phase: String, Codable, Sendable { case red, colour, clearance, respottedBlack, finished }
enum FoulDisposition: String, Codable, CaseIterable, Sendable {
    case opponent, playAgain, replaceAndPlayAgain
    var label: String {
        switch self { case .opponent: "Opponent plays"; case .playAgain: "Pass back"; case .replaceAndPlayAgain: "Miss · replace balls" }
    }
}

enum ScoringAction: Codable, Equatable, Sendable {
    case pot(Ball, count: Int = 1)
    case freeBall(Ball, alsoPotOn: Bool = false)
    case endTurn
    case switchPlayer(Int)
    case correctFrame(scores: [Int], winner: Int?, breaks: [BreakEntry], date: Date)
    case foul(points: Int, removedReds: Int, disposition: FoulDisposition, freeBall: Bool)
    case concede
    case awardFrame(Int)
    case adjustScore(player: Int, delta: Int)
    case pause(Bool)
}

struct BreakEntry: Codable, Equatable, Sendable {
    var player: Int
    var points: Int
}

struct FrameState: Codable, Equatable, Sendable {
    var scores = [0, 0]
    var activePlayer: Int
    var breakScore = 0
    var breaks: [BreakEntry] = []
    var redsRemaining: Int
    var phase = Phase.red
    var nextColour = 2
    var freeBallAvailable = false
    var winner: Int?
    var elapsed: TimeInterval = 0
    var resumedAt: Date?
    var endedAt: Date?
    var recordedDate: Date?

    init(reds: Int, starter: Int, date: Date) {
        redsRemaining = reds; activePlayer = starter; resumedAt = date
    }
    var ballOn: Int {
        switch phase { case .red: 1; case .colour: 4; case .clearance: nextColour; case .respottedBlack: 7; case .finished: 0 }
    }
    var legalBalls: [Ball] {
        switch phase { case .red: [.red]; case .colour: Ball.colours; case .clearance: [Ball(rawValue: nextColour)!]; case .respottedBlack: [.black]; case .finished: [] }
    }
    var remaining: Int {
        switch phase {
        case .red: redsRemaining * 8 + 27 + (freeBallAvailable ? 8 : 0)
        case .colour: redsRemaining * 8 + 34
        case .clearance: (nextColour...7).reduce(0, +) + (freeBallAvailable ? nextColour : 0)
        case .respottedBlack: 7
        case .finished: 0
        }
    }
    var minimumFoul: Int { max(4, ballOn) }
    var lead: Int { scores[activePlayer] - scores[1-activePlayer] }
    var snookersNeeded: Int { max(0, Int(ceil(Double(-lead - remaining) / Double(max(4, minimumFoul))))) }
    func duration(at date: Date = Date()) -> TimeInterval { elapsed + (resumedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0) }
    mutating func closeBreak() {
        if breakScore > 0 { breaks.append(BreakEntry(player: activePlayer, points: breakScore)) }
        breakScore = 0
    }
    mutating func stopClock(at date: Date) { elapsed = duration(at: date); resumedAt = nil }
    mutating func finish(_ player: Int, date: Date) {
        closeBreak(); stopClock(at: date); endedAt = date; winner = player; phase = .finished; freeBallAvailable = false
    }
    mutating func finalBlack(date: Date) {
        if scores[0] == scores[1] { closeBreak(); phase = .respottedBlack; freeBallAvailable = false }
        else { finish(scores[0] > scores[1] ? 0 : 1, date: date) }
    }
    mutating func apply(_ action: ScoringAction, date: Date) throws {
        if case .correctFrame(let newScores, let result, let entries, let recordedDate) = action {
            guard newScores.count == 2, newScores.allSatisfy({ (0...10000).contains($0) }), result == nil || (0...1).contains(result!), entries.allSatisfy({ (0...1).contains($0.player) && $0.points > 0 && $0.points <= newScores[$0.player] }), recordedDate.timeIntervalSince1970.isFinite, (0...4_102_444_800).contains(recordedDate.timeIntervalSince1970) else { throw ScoringError("Check the scores, winner, date and breaks.") }
            stopClock(at: date); scores = newScores; breaks = entries; breakScore = 0; winner = result; phase = .finished; endedAt = date; freeBallAvailable = false; self.recordedDate = recordedDate
            return
        }
        if case .awardFrame(let player) = action, resumedAt == nil, phase != .finished {
            guard (0...1).contains(player) else { throw ScoringError("Choose a valid player.") }
            finish(player, date: date); return
        }
        guard phase != .finished else { throw ScoringError("This frame has finished. Undo its last action to change the result.") }
        if case .pause(let paused) = action {
            if paused { stopClock(at: date) } else if resumedAt == nil { resumedAt = date }
            return
        }
        if case .switchPlayer(let player) = action {
            guard (0...1).contains(player) else { throw ScoringError("Choose a valid player.") }
            if player != activePlayer { closeBreak(); activePlayer = player; freeBallAvailable = false; if phase == .colour { phase = redsRemaining > 0 ? .red : .clearance } }
            return
        }
        guard resumedAt != nil else { throw ScoringError("Resume the frame before scoring.") }
        switch action {
        case .pot(let ball, let count):
            guard legalBalls.contains(ball), count >= 1, (ball == .red ? count <= redsRemaining : count == 1) else { throw ScoringError("That ball is not on.") }
            freeBallAvailable = false
            scores[activePlayer] += ball.rawValue * count; breakScore += ball.rawValue * count
            switch phase {
            case .red: redsRemaining -= count; phase = .colour
            case .colour: phase = redsRemaining > 0 ? .red : .clearance
            case .clearance:
                if nextColour == 7 { finalBlack(date: date) } else { nextColour += 1 }
            case .respottedBlack: finish(activePlayer, date: date)
            case .finished: break
            }
        case .freeBall(let ball, let alsoPotOn):
            guard freeBallAvailable, (phase == .red || phase == .clearance), ball.rawValue != ballOn, ball != .red, (phase != .clearance || ball.rawValue > nextColour) else { throw ScoringError("A free ball must be a colour still on the table other than the ball on.") }
            let value = ballOn
            let points = value * (alsoPotOn && phase == .red ? 2 : 1)
            scores[activePlayer] += points; breakScore += points; freeBallAvailable = false
            if phase == .red {
                if alsoPotOn { redsRemaining -= 1 }
                phase = .colour
            } else if alsoPotOn {
                if nextColour == 7 { finalBlack(date: date) } else { nextColour += 1 }
            }
        case .endTurn:
            closeBreak(); activePlayer = 1-activePlayer; freeBallAvailable = false
            if phase == .colour { phase = redsRemaining > 0 ? .red : .clearance }
        case .foul(let points, let removed, let disposition, let freeBall):
            guard (minimumFoul...7).contains(points), (0...redsRemaining).contains(removed) else { throw ScoringError("Check the foul value and reds removed.") }
            let previousPhase = phase
            let wasFinalBlack = phase == .respottedBlack || (phase == .clearance && nextColour == 7)
            closeBreak(); scores[1-activePlayer] += points
            if disposition != .replaceAndPlayAgain { redsRemaining -= removed }
            if disposition == .opponent { activePlayer = 1-activePlayer }
            if disposition != .replaceAndPlayAgain, previousPhase == .colour || previousPhase == .red { phase = redsRemaining > 0 ? .red : .clearance }
            // The ball-on after replacement is the original ball-on, including a nominated colour.
            freeBallAvailable = freeBall && disposition == .opponent && (phase == .red || phase == .clearance) && !wasFinalBlack
            if wasFinalBlack { finalBlack(date: date) }
        case .concede: finish(1-activePlayer, date: date)
        case .awardFrame(let player):
            guard (0...1).contains(player) else { throw ScoringError("Choose a valid player.") }
            finish(player, date: date)
        case .adjustScore(let player, let delta):
            guard (0...1).contains(player), (-200...200).contains(delta), scores[player] + delta >= 0, scores[player] + delta <= 10000 else { throw ScoringError("The score must stay between 0 and 10,000.") }
            closeBreak(); scores[player] += delta
        case .pause, .switchPlayer, .correctFrame: break
        }
    }
}

struct ScoringError: LocalizedError, Sendable {
    var message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

struct Shot: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var date: Date
    var action: ScoringAction
    var before: FrameState
    var summary: String {
        switch action {
        case .pot(let ball, let count): "Potted \(count > 1 ? "\(count) reds" : ball.name.lowercased())"
        case .freeBall(let ball, let also): "Free ball: \(ball.name.lowercased())\(also ? " + ball on" : "")"
        case .endTurn: "End of visit"
        case .switchPlayer: "Player changed"
        case .correctFrame: "Frame corrected"
        case .foul(let p, let r, let d, let f): "Foul \(p) · \(d.label)\(r > 0 ? " · \(r) reds removed" : "")\(f ? " · free ball" : "")"
        case .concede: "Frame conceded"
        case .awardFrame: "Frame awarded"
        case .adjustScore(_, let delta): "Score adjusted \(delta >= 0 ? "+" : "")\(delta)"
        case .pause(let paused): paused ? "Timer paused" : "Timer resumed"
        }
    }
}

struct Frame: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var startedAt: Date
    var initialReds: Int
    var starter: Int
    var state: FrameState
    var shots: [Shot] = []
    var undoneShots: [Shot]?
    var archive: FrameArchive?
    var displayDate: Date { state.recordedDate ?? startedAt }
    var canUndo: Bool { !shots.isEmpty || (archive?.cursor ?? archive?.events.count ?? 0) > 0 }
    var canRedo: Bool { !(undoneShots ?? []).isEmpty || (archive.map { ($0.cursor ?? $0.events.count) < $0.events.count } ?? false) }
    var redPotMaximum: Int? {
        guard state.phase == .colour, let shot = shots.last,
              case .pot(.red, count: 1) = shot.action, shot.before.phase == .red,
              shot.before.redsRemaining > 1 else { return nil }
        return shot.before.redsRemaining
    }
    mutating func reviseRedPot(total: Int, shotID: UUID) throws {
        guard let maximum = redPotMaximum, (2...maximum).contains(total),
              var shot = shots.last, shot.id == shotID else {
            throw ScoringError("The turn has changed. Record multiple reds immediately after potting a red.")
        }
        var revised = shot.before
        shot.action = .pot(.red, count: total)
        try revised.apply(shot.action, date: shot.date)
        shots[shots.count-1] = shot; state = revised; undoneShots = nil
    }
    init(reds: Int, starter: Int, date: Date = Date()) {
        self.initialReds = reds; self.starter = starter; self.startedAt = date
        self.state = FrameState(reds: reds, starter: starter, date: date)
    }
    mutating func record(_ action: ScoringAction, date: Date = Date()) throws {
        let before = state
        var next = state
        try next.apply(action, date: date)
        if var saved = archive, let cursor = saved.cursor, cursor < saved.events.count { saved.events = Array(saved.events.prefix(cursor)); saved.cursor = nil; archive = saved }
        undoneShots = nil
        state = next
        shots.append(Shot(date: date, action: action, before: before))
    }
    mutating func undo() {
        if let shot = shots.popLast() { state = shot.before; if undoneShots == nil { undoneShots = [] }; undoneShots!.append(shot) }
        else if var saved = archive, (saved.cursor ?? saved.events.count) > 0 { saved.cursor = (saved.cursor ?? saved.events.count)-1; archive = saved; state = saved.baseState(reds: initialReds, starter: starter, date: startedAt) }
    }
    mutating func redo() throws {
        if var saved = archive, (saved.cursor ?? saved.events.count) < saved.events.count { saved.cursor = (saved.cursor ?? saved.events.count)+1; archive = saved; state = saved.baseState(reds: initialReds, starter: starter, date: startedAt) }
        else if var pending = undoneShots, let shot = pending.popLast() { guard shot.before == state else { throw ScoringError("This redo is no longer available.") }; try state.apply(shot.action, date: shot.date); shots.append(shot); undoneShots = pending }
    }
    func validate() throws {
        guard (1...15).contains(initialReds), (0...1).contains(starter), shots.count <= 10000, startedAt.timeIntervalSince1970.isFinite, (0...4_102_444_800).contains(startedAt.timeIntervalSince1970), Set(shots.map(\.id)).count == shots.count else { throw ScoringError("Invalid frame in the backup.") }
        try archive?.validate()
        guard (undoneShots ?? []).count <= 10000 else { throw ScoringError("Too many redo actions in this frame.") }
        if let archive { guard (archive.events.first?.date ?? startedAt) >= startedAt else { throw ScoringError("Imported shots predate their frame.") } }
        var replay = archive?.baseState(reds: initialReds, starter: starter, date: startedAt) ?? FrameState(reds: initialReds, starter: starter, date: startedAt)
        var date = max(startedAt, archive?.events.prefix(archive?.cursor ?? archive?.events.count ?? 0).last?.date ?? startedAt)
        for shot in shots {
            guard shot.date >= date, shot.date.timeIntervalSince1970 <= 4_102_444_800, shot.before == replay else { throw ScoringError("The backup's scoring history is inconsistent.") }
            try replay.apply(shot.action, date: shot.date); date = shot.date
        }
        guard replay.scores.allSatisfy({ (0...10000).contains($0) }), replay == state else { throw ScoringError("The backup's frame score does not match its history.") }
        var future = replay
        var futureDate = date
        if let archive, (archive.cursor ?? archive.events.count) < archive.events.count { future = archive.fullState(reds: initialReds, starter: starter, date: startedAt); futureDate = max(futureDate, archive.events.last?.date ?? startedAt) }
        for shot in (undoneShots ?? []).reversed() {
            guard shot.before == future, shot.date >= futureDate else { throw ScoringError("The backup's redo history is inconsistent.") }
            try future.apply(shot.action, date: shot.date); futureDate = shot.date
        }
    }
}

struct Match: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var playerIDs: [UUID]
    var playerNames: [String]
    var bestOf: Int
    var reds: Int
    var firstPlayer: Int
    var traditional: Bool
    var createdAt: Date
    var frames: [Frame]
    var revision = 0
    var closedAt: Date?
    var declaredWinner: Int?
    var source: String?
    var sourceWinner: Int?
    var sourceWins: [Int]?
    var redoNewFrame: Frame?
    var redoClosedAt: Date?
    var redoDeclaredWinner: Int?
    var historyEdited: Bool?
    var formatLabel: String { bestOf == 0 ? "Open session" : "Best of \(bestOf)" }
    var canUndo: Bool { frame.canUndo || (frames.count > 1 && frame.archive == nil) }
    var canRedo: Bool { frame.canRedo || redoNewFrame != nil || redoClosedAt != nil }
    init(players: [Player], bestOf: Int, reds: Int, firstPlayer: Int, traditional: Bool, date: Date = Date()) {
        playerIDs = players.map(\.id); playerNames = players.map(\.name)
        self.bestOf = bestOf; self.reds = reds; self.firstPlayer = firstPlayer; self.traditional = traditional
        createdAt = date; frames = [Frame(reds: reds, starter: firstPlayer, date: date)]
    }
    var frame: Frame { frames.last! }
    var wins: [Int] { (0...1).map { p in frames.filter { $0.state.winner == p }.count } }
    var winner: Int? {
        if closedAt != nil { return declaredWinner ?? (wins[0] == wins[1] ? nil : wins[0] > wins[1] ? 0 : 1) }
        return bestOf == 0 ? nil : wins.firstIndex { $0 >= bestOf/2 + 1 }
    }
    var isComplete: Bool { closedAt != nil || winner != nil }
    mutating func record(_ action: ScoringAction, date: Date = Date()) throws {
        guard !isComplete else { throw ScoringError("This session has ended. Edit its frames in History.") }
        try frames[frames.count-1].record(action, date: date); redoNewFrame = nil; redoClosedAt = nil; redoDeclaredWinner = nil; revision += 1
    }
    mutating func undo() {
        if let closedAt { redoClosedAt = closedAt; redoDeclaredWinner = declaredWinner }
        closedAt = nil; declaredWinner = nil
        if frames.count > 1 && frame.shots.isEmpty && frame.archive == nil { redoNewFrame = frames.removeLast() }
        frames[frames.count-1].undo(); revision += 1
    }
    mutating func redo() throws {
        try frames[frames.count-1].redo()
        if frame.state.phase == .finished, let pending = redoNewFrame { frames.append(pending); redoNewFrame = nil }
        if !frame.canRedo, let closed = redoClosedAt { closedAt = closed; declaredWinner = redoDeclaredWinner; redoClosedAt = nil; redoDeclaredWinner = nil }
        revision += 1
    }
    mutating func nextFrame(date: Date = Date()) throws {
        guard !isComplete, frame.state.phase == .finished else { throw ScoringError("Finish this frame before starting the next.") }
        redoNewFrame = nil; redoClosedAt = nil; redoDeclaredWinner = nil
        frames.append(Frame(reds: reds, starter: (firstPlayer + frames.count) % 2, date: date)); revision += 1
    }
    func validate() throws {
        guard playerIDs.count == 2, Set(playerIDs).count == 2, playerNames.count == 2, playerNames.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 40 }), (bestOf == 0 || ((1...35).contains(bestOf) && bestOf % 2 == 1)), (1...15).contains(reds), (0...1).contains(firstPlayer), !frames.isEmpty, frames.count <= (bestOf == 0 ? 1000 : bestOf), revision >= 0, (sourceWinner == nil || (0...1).contains(sourceWinner!)), (sourceWins == nil || (sourceWins!.count == 2 && sourceWins!.allSatisfy { (0...1000).contains($0) })), declaredWinner == nil || (0...1).contains(declaredWinner!) else { throw ScoringError("Invalid match settings in the backup.") }
        guard createdAt.timeIntervalSince1970.isFinite, (0...4_102_444_800).contains(createdAt.timeIntervalSince1970), closedAt == nil || (closedAt! >= createdAt && closedAt!.timeIntervalSince1970 <= 4_102_444_800) else { throw ScoringError("Invalid match dates.") }
        guard redoDeclaredWinner == nil || (0...1).contains(redoDeclaredWinner!) else { throw ScoringError("Invalid saved session winner.") }
        if let date = redoClosedAt { guard date >= createdAt, date.timeIntervalSince1970 <= 4_102_444_800 else { throw ScoringError("Invalid saved session date.") } }
        if let pending = redoNewFrame { try pending.validate(); guard pending.shots.isEmpty, pending.archive == nil, pending.initialReds == reds else { throw ScoringError("Invalid next-frame redo.") } }
        for (i, frame) in frames.enumerated() {
            guard frame.initialReds == reds, (frame.archive != nil || frame.starter == (firstPlayer+i)%2), historyEdited == true || i == frames.count-1 || frame.state.phase == .finished else { throw ScoringError("Invalid frame sequence in the backup.") }
            try frame.validate()
        }
        guard Set(frames.map(\.id)).count == frames.count else { throw ScoringError("Duplicate frames in the backup.") }
        var tally = [0,0]
        for (i, f) in frames.enumerated() {
            if let w = f.state.winner { tally[w] += 1 }
            let corrected = frames.contains { $0.shots.contains { if case .correctFrame = $0.action { return true }; return false } }
            guard bestOf == 0 || historyEdited == true || corrected || i == frames.count-1 || tally.max()! < bestOf/2+1 else { throw ScoringError("The backup continues after a match was won.") }
        }
    }
}

struct PlayerStats: Sendable {
    var matchesPlayed = 0, matchesWon = 0, framesPlayed = 0, framesWon = 0, highestBreak = 0
    var breaks30 = 0, breaks50 = 0, centuries = 0, totalPoints = 0
    var winRate: Double { matchesPlayed == 0 ? 0 : Double(matchesWon)/Double(matchesPlayed) }
    init(playerID: UUID, matches: [Match]) {
        for match in matches {
            guard let p = match.playerIDs.firstIndex(of: playerID) else { continue }
            if match.isComplete { matchesPlayed += 1; if match.winner == p { matchesWon += 1 } }
            for frame in match.frames {
                if let winner = frame.state.winner { framesPlayed += 1; if winner == p { framesWon += 1 }; totalPoints += frame.state.scores[p] }
                let breaks = frame.state.breaks.filter { $0.player == p }.map(\.points) + (frame.state.activePlayer == p && frame.state.breakScore > 0 ? [frame.state.breakScore] : [])
                highestBreak = max(highestBreak, breaks.max() ?? 0)
                breaks30 += breaks.filter { $0 >= 30 }.count; breaks50 += breaks.filter { $0 >= 50 }.count; centuries += breaks.filter { $0 >= 100 }.count
            }
        }
    }
}

struct Backup: Codable, Sendable {
    var format = "BaizeBook"
    var version = 1
    var exportedAt = Date()
    var players: [Player]
    var matches: [Match]
    func validate() throws {
        guard format == "BaizeBook", version == 1 else { throw ScoringError("Choose a BaizeBook version 1 backup.") }
        guard players.count <= 5000, matches.count <= 50000, Set(players.map(\.id)).count == players.count, Set(matches.map(\.id)).count == matches.count, Set(players.map(\.id) + matches.map(\.id)).count == players.count + matches.count else { throw ScoringError("The backup has duplicate entries or exceeds the import limit.") }
        guard players.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.name.count <= 40 }) else { throw ScoringError("A player name in the backup is invalid.") }
        let ids = Set(players.map(\.id))
        for match in matches { guard match.playerIDs.allSatisfy(ids.contains) else { throw ScoringError("The backup is missing a player used in a match.") }; try match.validate() }
    }
    static func decode(_ data: Data) throws -> Backup {
        guard data.count <= 20 * 1024 * 1024 else { throw ScoringError("Backups must be smaller than 20 MB.") }
        do { let result = try JSONDecoder().decode(Backup.self, from: data); try result.validate(); return result }
        catch let error as ScoringError { throw error }
        catch { throw ScoringError("This file is not a valid BaizeBook backup.") }
    }
    func encoded() throws -> Data { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; return try encoder.encode(self) }
}
