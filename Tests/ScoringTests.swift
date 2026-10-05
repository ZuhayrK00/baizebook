import XCTest
#if SWIFT_PACKAGE
@testable import BaizeBookCore
#else
@testable import BaizeBook
#endif

final class ScoringTests: XCTestCase {
    func testMultipleRedsRevisesOneShotAndRoundTripsUndoRedo() throws {
        var f = Frame(reds: 15, starter: 0)
        try f.record(.pot(.red)); let shot = try XCTUnwrap(f.shots.last)
        XCTAssertEqual(f.redPotMaximum, 15)
        try f.reviseRedPot(total: 3, shotID: shot.id)
        XCTAssertEqual(f.state.scores, [3,0]); XCTAssertEqual(f.state.breakScore, 3)
        XCTAssertEqual(f.state.redsRemaining, 12); XCTAssertEqual(f.state.phase, .colour)
        XCTAssertEqual(f.shots.count, 1); XCTAssertEqual(f.shots[0].id, shot.id)
        XCTAssertNil(f.redPotMaximum)
        try f.validate()
        let revised = f.state
        f.undo(); XCTAssertEqual(f.state.scores, [0,0]); XCTAssertEqual(f.state.redsRemaining, 15)
        try f.redo(); XCTAssertEqual(f.state, revised)
        let saved = try JSONDecoder().decode(Frame.self, from: JSONEncoder().encode(f)); try saved.validate()
        XCTAssertEqual(saved, f)
    }
    func testMultipleRedsCannotAmendAChangedTurnOrInvalidTotal() throws {
        var f = Frame(reds: 6, starter: 1); try f.record(.pot(.red)); let id = f.shots.last!.id
        let before = f
        for count in [0,1,7] { XCTAssertThrowsError(try f.reviseRedPot(total: count, shotID: id)); XCTAssertEqual(f,before) }
        XCTAssertThrowsError(try f.reviseRedPot(total: 2, shotID: UUID())); XCTAssertEqual(f,before)
        try f.record(.pot(.black)); XCTAssertNil(f.redPotMaximum)
        let afterColour = f; XCTAssertThrowsError(try f.reviseRedPot(total: 2, shotID: id)); XCTAssertEqual(f,afterColour)
        f.undo(); XCTAssertEqual(f.redPotMaximum, 6)
        try f.reviseRedPot(total: 2, shotID: id); XCTAssertFalse(f.canRedo); try f.validate()
        try f.record(.endTurn); XCTAssertNil(f.redPotMaximum)
    }
    func testMultipleRedsIncludesTheAlreadyRecordedFinalRed() throws {
        var f = Frame(reds: 2, starter: 0); try f.record(.pot(.red))
        try f.reviseRedPot(total: 2, shotID: f.shots.last!.id)
        XCTAssertEqual(f.state.scores[0], 2); XCTAssertEqual(f.state.redsRemaining, 0)
        try f.record(.pot(.black)); XCTAssertEqual(f.state.scores[0], 9); XCTAssertEqual(f.state.phase, .clearance); try f.validate()
        var single = Frame(reds: 1, starter: 0); try single.record(.pot(.red)); XCTAssertNil(single.redPotMaximum)
    }
    func testMaximumBreakAndRemaining() throws {
        var frame = Frame(reds: 15, starter: 0)
        XCTAssertEqual(frame.state.remaining, 147)
        for red in 0..<15 {
            try frame.record(.pot(.red))
            XCTAssertEqual(frame.state.remaining, 147 - red*8 - 1)
            try frame.record(.pot(.black))
            XCTAssertEqual(frame.state.remaining, 147 - (red+1)*8)
        }
        for ball in Ball.colours { try frame.record(.pot(ball)) }
        XCTAssertEqual(frame.state.scores, [147,0]); XCTAssertEqual(frame.state.winner, 0)
        XCTAssertEqual(frame.state.breaks, [BreakEntry(player: 0, points: 147)])
        XCTAssertEqual(frame.state.phase, .finished); XCTAssertEqual(frame.state.remaining, 0)
        try frame.validate()
    }
    func testRedsConfigurations() throws {
        for reds in 1...15 {
            var f = Frame(reds: reds, starter: 1)
            for _ in 0..<reds { try f.record(.pot(.red)); try f.record(.pot(.black)) }
            for b in Ball.colours { try f.record(.pot(b)) }
            XCTAssertEqual(f.state.scores[1], reds*8+27)
            try f.validate()
        }
    }
    func testIllegalPotDoesNotMutate() throws {
        var f = Frame(reds: 15, starter: 0); let before = f
        XCTAssertThrowsError(try f.record(.pot(.black)))
        XCTAssertEqual(f, before)
        XCTAssertThrowsError(try f.record(.pot(.red, count: 16)))
        XCTAssertEqual(f, before)
    }
    func testFinalColourIsStillAvailable() throws {
        var f = Frame(reds: 1, starter: 0)
        try f.record(.pot(.red)); XCTAssertEqual(f.state.phase, .colour); XCTAssertEqual(f.state.remaining, 34)
        try f.record(.pot(.pink)); XCTAssertEqual(f.state.phase, .clearance); XCTAssertEqual(f.state.legalBalls, [.yellow]); XCTAssertEqual(f.state.remaining, 27)
    }
    func testMissingFinalColourStartsClearance() throws {
        var f = Frame(reds: 1, starter: 0)
        try f.record(.pot(.red)); try f.record(.endTurn)
        XCTAssertEqual(f.state.legalBalls, [.yellow]); XCTAssertEqual(f.state.activePlayer, 1)
        XCTAssertEqual(f.state.breaks.first?.points, 1)
    }
    func testMultipleRedsIncludingTheLastPair() throws {
        var f = Frame(reds: 2, starter: 0)
        try f.record(.pot(.red, count: 2)); XCTAssertEqual(f.state.redsRemaining, 0); XCTAssertEqual(f.state.scores[0], 2)
        try f.record(.pot(.black)); XCTAssertEqual(f.state.legalBalls, [.yellow])
        f.undo(); XCTAssertEqual(f.state.phase, .colour); f.undo(); XCTAssertEqual(f.state.redsRemaining, 2)
    }
    func testFoulOnLastRed() throws {
        var f = Frame(reds: 1, starter: 0)
        try f.record(.foul(points: 4, removedReds: 1, disposition: .opponent, freeBall: false))
        XCTAssertEqual(f.state.legalBalls, [.yellow]); XCTAssertEqual(f.state.scores, [0,4]); XCTAssertEqual(f.state.remaining, 27)
        f.undo(); XCTAssertEqual(f.state.phase, .red); XCTAssertEqual(f.state.redsRemaining, 1)
    }
    func testLastColourFoulDoesNotOfferAnotherColour() throws {
        var f = Frame(reds: 1, starter: 0)
        try f.record(.pot(.red)); try f.record(.foul(points: 7, removedReds: 0, disposition: .opponent, freeBall: false))
        XCTAssertEqual(f.state.legalBalls, [.yellow]); XCTAssertEqual(f.state.scores, [1,7]); XCTAssertEqual(f.state.breakScore, 0)
    }
    func testMissReplacementRestoresBallOnAndReds() throws {
        var f = Frame(reds: 1, starter: 0)
        try f.record(.pot(.red)); try f.record(.foul(points: 4, removedReds: 0, disposition: .replaceAndPlayAgain, freeBall: true))
        XCTAssertEqual(f.state.phase, .colour); XCTAssertEqual(f.state.activePlayer, 0); XCTAssertFalse(f.state.freeBallAvailable)
        var reds = Frame(reds: 2, starter: 0)
        try reds.record(.foul(points: 4, removedReds: 2, disposition: .replaceAndPlayAgain, freeBall: false))
        XCTAssertEqual(reds.state.redsRemaining, 2); XCTAssertEqual(reds.state.scores[1], 4)
    }
    func testPassBackAwardsPointsButKeepsPlayer() throws {
        var f = Frame(reds: 15, starter: 0)
        try f.record(.foul(points: 6, removedReds: 1, disposition: .playAgain, freeBall: true))
        XCTAssertEqual(f.state.activePlayer, 0); XCTAssertEqual(f.state.scores, [0,6]); XCTAssertEqual(f.state.redsRemaining, 14); XCTAssertFalse(f.state.freeBallAvailable)
    }
    func testColourFoulMinimum() throws {
        var f = try clearance()
        for b in [Ball.yellow, .green, .brown] { try f.record(.pot(b)) }
        XCTAssertEqual(f.state.minimumFoul, 5)
        let before = f
        XCTAssertThrowsError(try f.record(.foul(points: 4, removedReds: 0, disposition: .opponent, freeBall: false)))
        XCTAssertEqual(f, before)
        try f.record(.foul(points: 5, removedReds: 0, disposition: .opponent, freeBall: false))
        XCTAssertEqual(f.state.legalBalls, [.blue])
    }
    func testFreeBallAsRedKeepsRedCount() throws {
        var f = Frame(reds: 15, starter: 0)
        try f.record(.foul(points: 4, removedReds: 0, disposition: .opponent, freeBall: true))
        XCTAssertEqual(f.state.remaining, 155)
        try f.record(.freeBall(.black)); XCTAssertEqual(f.state.redsRemaining, 15); XCTAssertEqual(f.state.phase, .colour)
        XCTAssertEqual(f.state.scores, [0,5]); XCTAssertEqual(f.state.breakScore, 1)
        try f.record(.pot(.black)); XCTAssertEqual(f.state.remaining, 147)
        try f.validate()
    }
    func testFreeBallAndRedBothScore() throws {
        var f = Frame(reds: 1, starter: 0)
        try f.record(.foul(points: 4, removedReds: 0, disposition: .opponent, freeBall: true))
        try f.record(.freeBall(.blue, alsoPotOn: true)); XCTAssertEqual(f.state.breakScore, 2); XCTAssertEqual(f.state.redsRemaining, 0)
        try f.record(.pot(.black)); XCTAssertEqual(f.state.legalBalls, [.yellow])
    }
    func testFreeBallAndColourOnlyScoreOnce() throws {
        var f = try clearance()
        try f.record(.foul(points: 4, removedReds: 0, disposition: .opponent, freeBall: true))
        try f.record(.freeBall(.black, alsoPotOn: true))
        XCTAssertEqual(f.state.breakScore, 2); XCTAssertEqual(f.state.legalBalls, [.green])
        try f.validate()
    }
    func testFreeBallAloneOnClearanceLeavesBallOn() throws {
        var f = try clearance()
        try f.record(.foul(points: 4, removedReds: 0, disposition: .opponent, freeBall: true))
        try f.record(.freeBall(.pink)); XCTAssertEqual(f.state.legalBalls, [.yellow]); XCTAssertEqual(f.state.breakScore, 2)
    }
    func testClearedColourCannotBeFreeBall() throws {
        var f = try clearance(); try f.record(.pot(.yellow))
        try f.record(.foul(points: 4, removedReds: 0, disposition: .opponent, freeBall: true))
        XCTAssertThrowsError(try f.record(.freeBall(.yellow)))
        XCTAssertThrowsError(try f.record(.freeBall(.green)))
    }
    func testFinalBlackFoulEndsFrame() throws {
        var f = try finalBlack()
        try f.record(.foul(points: 7, removedReds: 0, disposition: .opponent, freeBall: false))
        XCTAssertEqual(f.state.phase, .finished); XCTAssertEqual(f.state.winner, 0)
    }
    func testTiedFinalBlackIsRespotted() throws {
        var f = try finalBlack()
        try f.record(.adjustScore(player: 1, delta: f.state.scores[0]+7))
        try f.record(.pot(.black)); XCTAssertEqual(f.state.phase, .respottedBlack); XCTAssertNil(f.state.winner)
        try f.record(.endTurn); try f.record(.pot(.black)); XCTAssertEqual(f.state.winner, 1)
        f.undo(); XCTAssertEqual(f.state.phase, .respottedBlack)
    }
    func testTiedFinalBlackFoulIsRespotted() throws {
        var f = try finalBlack()
        try f.record(.adjustScore(player: 1, delta: f.state.scores[0]-7))
        try f.record(.foul(points: 7, removedReds: 0, disposition: .opponent, freeBall: false))
        XCTAssertEqual(f.state.phase, .respottedBlack)
        try f.record(.foul(points: 7, removedReds: 0, disposition: .opponent, freeBall: false)); XCTAssertEqual(f.state.winner, 0)
    }
    func testPauseResumeAndUndo() throws {
        let start = Date(timeIntervalSince1970: 100)
        var f = Frame(reds: 15, starter: 0, date: start)
        try f.record(.pause(true), date: start.addingTimeInterval(20))
        XCTAssertEqual(f.state.duration(at: start.addingTimeInterval(100)), 20)
        XCTAssertThrowsError(try f.record(.pot(.red)))
        try f.record(.pause(false), date: start.addingTimeInterval(100))
        XCTAssertEqual(f.state.duration(at: start.addingTimeInterval(110)), 30)
        f.undo(); XCTAssertNil(f.state.resumedAt); try f.validate()
    }
    func testConcedeWithHigherScore() throws {
        var f = Frame(reds: 15, starter: 0); try f.record(.pot(.red)); try f.record(.concede)
        XCTAssertEqual(f.state.winner, 1); XCTAssertEqual(f.state.breaks.first?.points, 1)
        f.undo(); XCTAssertNil(f.state.winner); XCTAssertEqual(f.state.breakScore, 1)
    }
    func testMatchWinAndAlternatingBreakOff() throws {
        var m = makeMatch(bestOf: 3)
        try m.record(.awardFrame(0)); try m.nextFrame(); XCTAssertEqual(m.frame.state.activePlayer, 1)
        try m.record(.awardFrame(0)); XCTAssertEqual(m.winner, 0); XCTAssertThrowsError(try m.nextFrame())
        try m.validate(); m.undo(); XCTAssertNil(m.winner)
    }
    func testUndoAcrossNewFrame() throws {
        var m = makeMatch(bestOf: 3); try m.record(.awardFrame(0)); try m.nextFrame(); m.undo()
        XCTAssertEqual(m.frames.count, 1); XCTAssertNil(m.frame.state.winner); XCTAssertEqual(m.wins, [0,0])
    }
    func testStatisticsExcludeFoulsAndManualPointsFromBreaks() throws {
        var m = makeMatch(bestOf: 1)
        for _ in 0..<5 { try m.record(.pot(.red)); try m.record(.pot(.black)) }
        try m.record(.foul(points: 7, removedReds: 0, disposition: .opponent, freeBall: false))
        try m.record(.adjustScore(player: 1, delta: 100)); try m.record(.awardFrame(0))
        let a = PlayerStats(playerID: m.playerIDs[0], matches: [m]), b = PlayerStats(playerID: m.playerIDs[1], matches: [m])
        XCTAssertEqual(a.highestBreak, 40); XCTAssertEqual(a.breaks30, 1); XCTAssertEqual(a.matchesWon, 1); XCTAssertEqual(a.framesWon, 1)
        XCTAssertEqual(b.highestBreak, 0); XCTAssertEqual(b.totalPoints, 107); XCTAssertEqual(b.matchesPlayed, 1)
    }
    func testSnookersEstimate() throws {
        var f = Frame(reds: 1, starter: 0)
        try f.record(.adjustScore(player: 1, delta: 40)); XCTAssertEqual(f.state.remaining, 35); XCTAssertEqual(f.state.snookersNeeded, 2)
    }
    func testBackupRoundTrip() throws {
        var m = makeMatch(bestOf: 1); try m.record(.pot(.red)); try m.record(.pot(.pink))
        let players = zip(m.playerIDs, m.playerNames).map { Player(id: $0.0, name: $0.1) }
        let original = Backup(players: players, matches: [m]); let imported = try Backup.decode(original.encoded())
        XCTAssertEqual(imported.players, players); XCTAssertEqual(imported.matches, [m])
    }
    func testBackupRejectsInvalidVersionAndDuplicateIDs() throws {
        var b = Backup(players: [], matches: []); b.version = 2; XCTAssertThrowsError(try b.validate())
        b.version = 1; let p = Player(name: "A"); b.players = [p,p]; XCTAssertThrowsError(try b.validate())
    }
    func testBackupRejectsMissingPlayerAndTamperedScores() throws {
        var m = makeMatch(bestOf: 1)
        XCTAssertThrowsError(try Backup(players: [], matches: [m]).validate())
        let players = zip(m.playerIDs, m.playerNames).map { Player(id: $0.0, name: $0.1) }
        m.frames[0].state.scores[0] = 147; XCTAssertThrowsError(try Backup(players: players, matches: [m]).validate())
    }
    func testBackupRejectsCorruptOrOversizedFiles() {
        XCTAssertThrowsError(try Backup.decode(Data("{}".utf8)))
        XCTAssertThrowsError(try Backup.decode(Data(repeating: 0, count: 21*1024*1024)))
    }
    func testExtremeAdjustmentCannotOverflow() {
        var f = Frame(reds: 15, starter: 0)
        XCTAssertThrowsError(try f.record(.adjustScore(player: 0, delta: Int.min)))
        XCTAssertThrowsError(try f.record(.adjustScore(player: 0, delta: Int.max)))
    }
    private func clearance() throws -> Frame { var f = Frame(reds: 1, starter: 0); try f.record(.pot(.red)); try f.record(.pot(.black)); return f }
    private func finalBlack() throws -> Frame { var f = try clearance(); for b in Ball.colours.dropLast() { try f.record(.pot(b)) }; return f }
    private func makeMatch(bestOf: Int) -> Match { Match(players: [Player(name: "Alex"), Player(name: "Jamie")], bestOf: bestOf, reds: 15, firstPlayer: 0, traditional: false) }
}
