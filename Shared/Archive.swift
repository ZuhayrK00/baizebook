import Foundation
import CryptoKit

struct HistoricalEvent: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var date: Date
    var player: Int
    var ball: Ball?
    var points: Int
    var redCount: Int
    var penalty: Int
    var removedReds: Int
    var freeBall: Bool
    var disposition: String?
    var legalAfter: [Ball]
}
struct FrameArchive: Codable, Equatable, Sendable {
    var source: String
    var events: [HistoricalEvent] = []
    var cursor: Int?
    var manualScores: [Int]?
    var manualBreaks: [BreakEntry]?
    func baseState(reds: Int, starter: Int, date: Date) -> FrameState {
        var state = FrameState(reds: reds, starter: starter, date: date)
        state.resumedAt = nil
        state.scores = manualScores ?? [0,0]; state.breaks = manualBreaks ?? []
        for event in events.prefix(cursor ?? events.count) {
            if event.player != state.activePlayer { state.closeBreak(); state.activePlayer = event.player }
            if event.penalty > 0 || event.points == 0 { state.closeBreak() }
            state.scores[event.player] += event.points
            state.scores[1-event.player] += event.penalty
            if event.points > 0 { state.breakScore += event.points }
            state.redsRemaining = max(0, state.redsRemaining - event.redCount - event.removedReds)
            if event.legalAfter.contains(.red) { state.phase = .red }
            else if event.legalAfter.count > 1 { state.phase = .colour }
            else if let colour = event.legalAfter.first { state.phase = .clearance; state.nextColour = max(2, colour.rawValue) }
            else { state.phase = .clearance; state.nextColour = 7 }
            state.freeBallAvailable = event.disposition == "FREE_BALL"
            state.elapsed = max(0, event.date.timeIntervalSince(date))
        }
        return state
    }
    func fullState(reds: Int, starter: Int, date: Date) -> FrameState { var full = self; full.cursor = nil; return full.baseState(reds: reds, starter: starter, date: date) }
    func validate() throws {
        guard events.count <= 10000, cursor == nil || (0...events.count).contains(cursor!), Set(events.map(\.id)).count == events.count, manualScores == nil || (manualScores!.count == 2 && manualScores!.allSatisfy { (0...10000).contains($0) }) else { throw ScoringError("Invalid recorded frame.") }
        var previous = Date(timeIntervalSince1970: 0)
        for event in events {
            guard (0...1).contains(event.player), (0...10000).contains(event.points), (0...10000).contains(event.penalty), (0...15).contains(event.redCount), (0...15).contains(event.removedReds), event.date >= previous, event.date.timeIntervalSince1970 <= 4_102_444_800 else { throw ScoringError("Invalid imported shot history.") }; previous = event.date
        }
        guard (manualBreaks ?? []).allSatisfy({ (0...1).contains($0.player) && $0.points > 0 && $0.points <= (manualScores ?? [0,0])[$0.player] }) else { throw ScoringError("Check the recorded breaks.") }
    }
}
struct ImportDraft: Sendable {
    var backup: Backup
    var source: String
    var notes: [String] = []
    var shotCount: Int { backup.matches.reduce(0) { $0 + $1.frames.reduce(0) { $0 + ($1.archive?.events.count ?? $1.shots.count) } } }
    static func decode(_ data: Data) throws -> ImportDraft {
        guard data.count <= 20 * 1024 * 1024 else { throw ScoringError("Choose a JSON file smaller than 20 MB.") }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], object["format"] as? String == "BaizeBook" { return ImportDraft(backup: try Backup.decode(data), source: "BaizeBook") }
        do { return try SnookerMateExport.decode(data) }
        catch let error as ScoringError { throw error }
        catch { throw ScoringError("Choose a BaizeBook backup or a SnookerMate JSON export.") }
    }
    func mapped(to links: [UUID: UUID], existing: [Player]) throws -> Backup {
        let ids = backup.players.map { links[$0.id] ?? $0.id }
        guard Set(ids).count == ids.count else { throw ScoringError("Link each imported player to a different profile.") }
        var result = backup
        result.players = backup.players.map { player in if let id = links[player.id], let found = existing.first(where: { $0.id == id }) { return found }; return player }
        result.matches = backup.matches.map { match in var match = match; match.playerIDs = match.playerIDs.map { links[$0] ?? $0 }; return match }
        try result.validate(); return result
    }
}
private struct SnookerMateExport: Decodable {
    struct Person: Decodable { var i: Int; var n: String }
    struct Game: Decodable { var i: Int; var s: String; var b: Int; var n: Int; var t: String; var w: Int? }
    struct Rack: Decodable { var i: Int; var m: Int; var s: Int; var st: String; var o: Int; var w: Int? }
    struct Link: Decodable { var m: Int; var p: Int; var o: Int }
    struct Adjustment: Decodable { var f: Int; var p: Int; var s: Int }
    struct Foul: Decodable { var a: String; var p: Int; var r: Int }
    struct Availability: Decodable {
        var r: Bool; var y: Bool; var g: Bool; var br: Bool; var b: Bool; var p: Bool; var bl: Bool
        var balls: [Ball] { zip(Ball.allCases, [r,y,g,br,b,p,bl]).compactMap { $0.1 ? $0.0 : nil } }
    }
    struct Event: Decodable {
        var i: Int; var f: Int; var p: Int; var r: Int; var y: Bool; var g: Bool; var br: Bool; var b: Bool; var pi: Bool; var bl: Bool; var fb: Bool; var po: Int; var t: String; var o: Int; var fo: Foul?; var n: Availability
        var ball: Ball? { if r > 0 { return .red }; return zip(Ball.colours, [y,g,br,b,pi,bl]).first { $0.1 }?.0 }
    }
    var p: [Person]; var m: [Game]; var f: [Rack]; var s: [Event]; var mp: [Link]; var fa: [Adjustment]
    static func stableID(_ key: String) -> UUID {
        let bytes = Array(SHA256.hash(data: Data(("BaizeBook.SnookerMate." + key).utf8)).prefix(16))
        return UUID(uuid: (bytes[0],bytes[1],bytes[2],bytes[3],bytes[4],bytes[5],bytes[6],bytes[7],bytes[8],bytes[9],bytes[10],bytes[11],bytes[12],bytes[13],bytes[14],bytes[15]))
    }
    static func decode(_ data: Data) throws -> ImportDraft {
        let fractional = ISO8601DateFormatter(); fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        func date(_ text: String) throws -> Date {
            guard let date = fractional.date(from: text) ?? plain.date(from: text), (0...4_102_444_800).contains(date.timeIntervalSince1970) else { throw ScoringError("An imported game has an invalid date.") }; return date
        }
        let source = try JSONDecoder().decode(Self.self, from: data)
        guard source.p.count <= 5000, source.m.count <= 50000, source.s.count <= 200000, Set(source.p.map(\.i)).count == source.p.count, Set(source.m.map(\.i)).count == source.m.count, Set(source.f.map(\.i)).count == source.f.count, Set(source.s.map(\.i)).count == source.s.count else { throw ScoringError("The SnookerMate export has duplicate entries or is too large.") }
        let players = source.p.map { Player(id: stableID("player:\($0.i):\($0.n.lowercased())"), name: $0.n) }
        let lookup = Dictionary(uniqueKeysWithValues: zip(source.p.map(\.i), players))
        let frames = Dictionary(grouping: source.f, by: \.m), events = Dictionary(grouping: source.s, by: \.f), links = Dictionary(grouping: source.mp, by: \.m), adjustments = Dictionary(grouping: source.fa, by: \.f)
        var matches: [Match] = []
        for game in source.m {
            let people = (links[game.i] ?? []).sorted { $0.o < $1.o }.map(\.p)
            guard people.count == 2, Set(people).count == 2, people.allSatisfy({ lookup[$0] != nil }), (1...15).contains(game.n) else { throw ScoringError("An imported match is missing its players or red count.") }
            let racks = (frames[game.i] ?? []).sorted { $0.o < $1.o }
            guard !racks.isEmpty, let starter = people.firstIndex(of: racks[0].s) else { throw ScoringError("An imported match is missing its frames.") }
            var match = Match(players: people.map { lookup[$0]! }, bestOf: 0, reds: game.n, firstPlayer: starter, traditional: game.t != "SMART", date: try date(game.s))
            match.id = stableID("match:\(game.i):\(game.s)"); match.source = "SnookerMate"; match.frames = []
            for rack in racks {
                guard let starter = people.firstIndex(of: rack.s) else { throw ScoringError("Unknown frame starter in the export.") }
                var frame = Frame(reds: game.n, starter: starter, date: try date(rack.st)); frame.id = stableID("frame:\(rack.i):\(rack.st)")
                var archive = FrameArchive(source: "SnookerMate")
                for event in (events[rack.i] ?? []).sorted(by: { $0.o < $1.o }) {
                    guard let player = people.firstIndex(of: event.p) else { throw ScoringError("Unknown player in imported shots.") }
                    archive.events.append(HistoricalEvent(id: stableID("shot:\(event.i):\(event.t)"), date: try date(event.t), player: player, ball: event.ball, points: event.po, redCount: event.fb ? 0 : event.r, penalty: event.fo?.p ?? 0, removedReds: event.fo?.a == "MISS" ? 0 : event.fo?.r ?? 0, freeBall: event.fb, disposition: event.fo?.a, legalAfter: event.n.balls))
                }
                if let saved = adjustments[rack.i], !saved.isEmpty {
                    guard archive.events.isEmpty else { throw ScoringError("This export mixes manual scores and shots in one frame. Please export those games separately.") }
                    archive.manualScores = [0,0]
                    for adjustment in saved { guard let player = people.firstIndex(of: adjustment.p) else { throw ScoringError("Unknown manual score player.") }; archive.manualScores![player] += adjustment.s }
                }
                frame.archive = archive; frame.state = archive.baseState(reds: frame.initialReds, starter: starter, date: frame.startedAt)
                if let winner = rack.w { guard let index = people.firstIndex(of: winner) else { throw ScoringError("Unknown frame winner.") }; try frame.record(.awardFrame(index), date: max(frame.startedAt, archive.events.last?.date ?? frame.startedAt)) }
                match.frames.append(frame)
            }
            match.closedAt = max(match.createdAt, match.frames.last?.state.endedAt ?? match.frames.last!.startedAt)
            if let winner = game.w { guard let index = people.firstIndex(of: winner) else { throw ScoringError("Unknown match winner.") }; match.declaredWinner = index }
            match.sourceWinner = match.declaredWinner; match.sourceWins = match.wins
            matches.append(match)
        }
        let backup = Backup(players: players, matches: matches); try backup.validate()
        var notes = ["Scores, saved winners, dates and shot history are preserved. Imported sessions stay in History; no timer starts."]
        if !source.fa.isEmpty { notes.append("Manual scores are included without inventing shots or breaks.") }
        if source.mp.contains(where: { link in !source.m.contains { $0.i == link.m } }) { notes.append("Links to deleted SnookerMate matches were ignored.") }
        if source.f.contains(where: { $0.w == nil }) { notes.append("Unfinished frames are retained and excluded from completed-frame statistics.") }
        return ImportDraft(backup: backup, source: "SnookerMate", notes: notes)
    }
}
