import XCTest
#if SWIFT_PACKAGE
@testable import BaizeBookCore
#else
@testable import BaizeBook
#endif
final class ImportTests: XCTestCase {
    let date = Date(timeIntervalSince1970: 1700000000)
    func testRedoAndBranching() throws {
        var frame = Frame(reds: 15, starter: 0, date: date)
        try frame.record(.pot(.red), date: date); try frame.record(.pot(.black), date: date)
        let finished = frame.state; frame.undo(); frame.undo(); try frame.validate()
        try frame.redo(); try frame.redo(); XCTAssertEqual(frame.state, finished); try frame.validate()
        frame.undo(); try frame.record(.pot(.blue), date: date); XCTAssertFalse(frame.canRedo); XCTAssertEqual(frame.state.scores, [6,0])
    }
    func testOpenSessionAndExplicitPlayerSwitch() throws {
        var match = Match(players: [Player(name: "A"),Player(name: "B")], bestOf: 0, reds: 15, firstPlayer: 0, traditional: false, date: date)
        for i in 0..<5 { try match.record(.awardFrame(0), date: date); XCTAssertFalse(match.isComplete); if i < 4 { try match.nextFrame(date: date) } }
        try match.validate(); match.closedAt = date; XCTAssertTrue(match.isComplete); XCTAssertEqual(match.winner, 0)
        var frame = Frame(reds: 15, starter: 0, date: date); try frame.record(.pot(.red), date: date); try frame.record(.switchPlayer(1), date: date)
        XCTAssertEqual(frame.state.activePlayer, 1); XCTAssertEqual(frame.state.phase, .red); XCTAssertEqual(frame.state.breaks, [BreakEntry(player: 0, points: 1)])
    }
    func testRedoRestoresEndedSessionAndNewScoringClearsClosureRedo() throws {
        var match = Match(players: [Player(name: "A"),Player(name: "B")], bestOf: 0, reds: 15, firstPlayer: 0, traditional: false, date: date)
        try match.record(.pot(.red), date: date); try match.record(.awardFrame(0), date: date); match.closedAt = date
        match.undo(); XCTAssertFalse(match.isComplete); try match.validate()
        try match.redo(); XCTAssertTrue(match.isComplete); XCTAssertEqual(match.winner,0); try match.validate()
        match.undo(); try match.record(.pot(.blue), date: date); XCTAssertFalse(match.canRedo); XCTAssertFalse(match.isComplete); try match.validate()
    }
    func testHistoricalCorrectionsAndUndoRedo() throws {
        var frame = Frame(reds: 15, starter: 0, date: date)
        frame.archive = FrameArchive(source: "Manual entry", manualScores: [52,32], manualBreaks: [BreakEntry(player: 0, points: 18)])
        frame.state = frame.archive!.baseState(reds: 15, starter: 0, date: date)
        try frame.record(.awardFrame(0), date: date)
        let original = frame.state
        try frame.record(.correctFrame(scores: [40,60], winner: 1, breaks: [BreakEntry(player: 1, points: 30)], date: date), date: date)
        try frame.validate(); frame.undo(); XCTAssertEqual(frame.state, original); try frame.validate(); try frame.redo(); XCTAssertEqual(frame.state.winner, 1); try frame.validate()
    }
    func testSnookerMatePreservesLegacyPenaltyAndManualScores() throws {
        let json = """
        {"p":[{"i":1,"n":"A"},{"i":2,"n":"B"}],"m":[{"i":1,"s":"2025-10-03T18:10:21.973Z","b":2,"n":15,"t":"SMART","w":1}],"f":[{"i":1,"m":1,"s":1,"st":"2025-10-03T18:10:22.050Z","o":1,"w":1},{"i":2,"m":1,"s":2,"st":"2025-10-03T19:10:22.050Z","o":2,"w":2}],"mp":[{"m":1,"p":1,"o":0},{"m":1,"p":2,"o":1}],"fa":[{"f":2,"p":1,"s":52},{"f":2,"p":2,"s":32}],"s":[{"i":1,"f":1,"p":2,"r":0,"y":false,"g":false,"br":false,"b":false,"pi":false,"bl":false,"fb":false,"po":0,"t":"2025-10-03T18:11:22.050Z","o":0,"fo":{"a":"DO_NOTHING","p":38,"r":0},"n":{"r":true,"y":false,"g":false,"br":false,"b":false,"p":false,"bl":false}}]}
        """
        let draft = try ImportDraft.decode(Data(json.utf8)); let match = try XCTUnwrap(draft.backup.matches.first)
        XCTAssertEqual(match.winner, 0); XCTAssertEqual(match.frames[0].state.scores, [38,0]); XCTAssertEqual(match.frames[1].state.scores,[52,32]); XCTAssertEqual(match.frames[1].state.winner, 1); XCTAssertNil(match.frame.state.resumedAt)
        XCTAssertEqual(try ImportDraft.decode(Data(json.utf8)).backup.matches[0].id, match.id)
        var frame = match.frames[0]; frame.undo(); frame.undo(); XCTAssertEqual(frame.state.scores, [0,0]); try frame.validate(); try frame.redo(); try frame.redo(); XCTAssertEqual(frame.state.scores,[38,0]); try frame.validate()
        _ = try Backup.decode(draft.backup.encoded())
        XCTAssertThrowsError(try draft.mapped(to: [draft.backup.players[0].id: draft.backup.players[1].id], existing: draft.backup.players))
    }
    func testSuppliedExportWhenAvailable() throws {
        guard let path = ProcessInfo.processInfo.environment["BAIZEBOOK_IMPORT_FIXTURE"] else { throw XCTSkip("Private export checked separately; never bundled in the app.") }
        let draft = try ImportDraft.decode(Data(contentsOf: URL(fileURLWithPath: path)))
        XCTAssertEqual(draft.backup.players.count, 2); XCTAssertEqual(draft.backup.matches.count, 50); XCTAssertEqual(draft.backup.matches.reduce(0) { $0 + $1.frames.count },242); XCTAssertEqual(draft.shotCount, 13103)
        XCTAssertEqual(draft.backup.matches.flatMap(\.frames).filter { $0.state.winner != nil }.count,240)
        let frames = draft.backup.matches.flatMap(\.frames)
        let manual = frames.first { $0.archive?.manualScores != nil }; XCTAssertEqual(manual?.state.scores, [52,32])
        let sample = frames.first { abs($0.startedAt.timeIntervalSince1970 - 1790355961) < 60 }; XCTAssertEqual(sample?.state.scores,[53,30])
        let data = try draft.backup.encoded(); XCTAssertLessThan(data.count,20*1024*1024); _ = try Backup.decode(data)
        for match in draft.backup.matches { XCTAssertNil(match.frame.state.resumedAt) }
    }
}
