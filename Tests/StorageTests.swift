#if !SWIFT_PACKAGE
import XCTest
import SwiftData
@testable import BaizeBook

@MainActor final class StorageTests: XCTestCase {
    func testClearAllDataPersistsResetsPreferencesAndAllowsBackupRestore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("BaizeBookReset-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = ModelConfiguration("ResetTests", url: directory.appendingPathComponent("Tests.store"), cloudKitDatabase: .none)
        let suite = "BaizeBookResetTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = try AppStore(configuration: configuration, defaults: defaults, connectWatch: false)
        try store.addPlayer("A"); try store.addPlayer("B")
        let id = try store.start(players: store.players, bestOf: 3, reds: 15, starter: 0, traditional: false)
        store.act(.pot(.red), matchID: id)
        let match = try XCTUnwrap(store.activeMatch)
        let command = WatchCommand(matchID: id, frameID: match.frame.id, revision: match.revision, action: .pot(.black))
        XCTAssertNil(store.watch.onCommand?(command))
        try store.editPlayer(store.players[0], name: "A", archived: true)
        let backupURL = directory.appendingPathComponent("Backup.json")
        try store.backup().encoded().write(to: backupURL)
        let savedBackup = try Data(contentsOf: backupURL)
        let preferenceKeys = ["defaultReds", "defaultBestOf", "defaultTraditional", "appearance", "haptics", "keepAwake"]
        for key in preferenceKeys { defaults.set("custom", forKey: key) }
        defaults.set("keep", forKey: "unrelated")
        store.importPreview = ImportDraft(backup: store.backup(), source: "BaizeBook")
        store.watch.snapshot = WatchSnapshot(match: store.activeMatch, names: store.names(store.activeMatch!))
        let resetID = store.dataResetID

        try store.clearAllData()

        XCTAssertTrue(store.players.isEmpty); XCTAssertTrue(store.matches.isEmpty)
        XCTAssertNil(store.activeID); XCTAssertNil(store.activeMatch); XCTAssertNil(store.importPreview)
        XCTAssertFalse(store.importLoading); XCTAssertNil(store.watch.snapshot.match); XCTAssertTrue(store.watch.snapshot.names.isEmpty)
        XCTAssertNotEqual(store.dataResetID, resetID)
        XCTAssertNil(defaults.object(forKey: "activeMatch"))
        for key in preferenceKeys { XCTAssertNil(defaults.object(forKey: key)) }
        XCTAssertEqual(defaults.string(forKey: "unrelated"), "keep")
        XCTAssertNotNil(store.watch.onCommand?(command)) // A stale wrist command cannot restore erased scoring data.
        let reopened = try AppStore(configuration: configuration, defaults: defaults, connectWatch: false)
        XCTAssertTrue(reopened.players.isEmpty); XCTAssertTrue(reopened.matches.isEmpty); XCTAssertNil(reopened.activeID)
        XCTAssertEqual(try Data(contentsOf: backupURL), savedBackup)
        _ = try reopened.merge(Backup.decode(savedBackup))
        XCTAssertEqual(reopened.players.count, 2); XCTAssertEqual(reopened.matches.count, 1)
        XCTAssertEqual(reopened.matches[0].frame.state.scores, [8,0])
        XCTAssertEqual(PlayerStats(playerID: reopened.matches[0].playerIDs[0], matches: reopened.matches).highestBreak, 8)
    }
    func testClearAllDataInvalidatesPendingImportAndAllowsAnotherImport() async throws {
        let store = try makeStore()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("BaizeBookResetImport-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Backup(players: [Player(name: "Imported")], matches: []).encoded().write(to: url)
        store.prepareImport(url); XCTAssertTrue(store.importLoading)
        try store.clearAllData()
        await Task.yield()
        XCTAssertNil(store.importPreview); XCTAssertFalse(store.importLoading); XCTAssertNil(store.message)
        store.prepareImport(url)
        for _ in 0..<200 { if !store.importLoading { break }; try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertFalse(store.importLoading); XCTAssertEqual(store.importPreview?.backup.players.first?.name, "Imported")
        XCTAssertTrue(store.players.isEmpty)
    }
    func testMultipleRedRevisionPersistsAndRejectsStaleShot() throws {
        let store = try makeStore(); try store.addPlayer("A"); try store.addPlayer("B")
        let id = try store.start(players: store.players, bestOf: 3, reds: 15, starter: 0, traditional: false)
        store.act(.pot(.red), matchID: id); let shot = store.activeMatch!.frame.shots.last!
        let revision = store.activeMatch!.revision
        store.reviseRedPot(id, total: 3, shotID: shot.id)
        XCTAssertEqual(store.activeMatch!.revision, revision+1); XCTAssertEqual(store.activeMatch!.frame.state.scores[0],3)
        let restored = try Backup.decode(store.backup().encoded()); XCTAssertEqual(restored.matches[0].frame.state.redsRemaining,12)
        store.undo(id); XCTAssertEqual(store.activeMatch!.frame.state.scores[0],0)
        store.redo(id); XCTAssertEqual(store.activeMatch!.frame.state.scores[0],3)
        store.act(.pot(.black), matchID: id); let before = store.activeMatch
        store.reviseRedPot(id,total:4,shotID:shot.id); XCTAssertEqual(store.activeMatch,before); XCTAssertNotNil(store.message)
    }
    func makeStore() throws -> AppStore {
        let defaults = UserDefaults(suiteName: "BaizeBookTests.\(UUID())")!
        return try AppStore(configuration: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none), defaults: defaults, connectWatch: false)
    }
    func testImportPreviewLoadsOffMainThreadWithoutChangingSavedData() async throws {
        let store = try makeStore(); try store.addPlayer("Existing")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("BaizeBookImport-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Backup(players: [Player(name: "New")], matches: []).encoded().write(to: url)
        store.prepareImport(url)
        for _ in 0..<200 { if !store.importLoading { break }; try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertFalse(store.importLoading); XCTAssertEqual(store.importPreview?.backup.players.first?.name,"New"); XCTAssertEqual(store.players.count,1)
        store.importPreview = nil; try FileManager.default.removeItem(at: url); store.prepareImport(url)
        for _ in 0..<200 { if !store.importLoading { break }; try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertFalse(store.importLoading); XCTAssertNil(store.importPreview); XCTAssertNotNil(store.message); XCTAssertEqual(store.players.count,1)
    }
    func testImportIsIdempotentAndKeepsLocalEdits() throws {
        let store = try makeStore()
        try store.addPlayer("Alex"); try store.addPlayer("Jamie")
        let id = try store.start(players: store.players, bestOf: 3, reds: 15, starter: 0, traditional: false)
        let original = store.backup()
        store.act(.pot(.red), matchID: id)
        _ = try store.merge(original); _ = try store.merge(original)
        XCTAssertEqual(store.players.count, 2); XCTAssertEqual(store.matches.count, 1)
        XCTAssertEqual(store.matches[0].frame.state.scores[0], 1)
    }
    func testImportAddsNewPlayersMatchesAndTheirHistory() throws {
        let source = try makeStore(); try source.addPlayer("A"); try source.addPlayer("B")
        let id = try source.start(players: source.players, bestOf: 1, reds: 6, starter: 1, traditional: false)
        source.act(.pot(.red), matchID: id); source.act(.pot(.black), matchID: id); source.act(.awardFrame(1), matchID: id)
        let destination = try makeStore()
        _ = try destination.merge(Backup.decode(source.backup().encoded()))
        XCTAssertEqual(destination.players, source.players); XCTAssertEqual(destination.matches, source.matches)
        XCTAssertEqual(PlayerStats(playerID: source.players[1].id, matches: destination.matches).highestBreak, 8)
    }
    func testMalformedImportMakesNoChanges() throws {
        let store = try makeStore(); try store.addPlayer("Existing")
        let before = store.players
        let p = Player(name: "Duplicate")
        XCTAssertThrowsError(try store.merge(Backup(players: [p,p], matches: [])))
        XCTAssertEqual(store.players, before); XCTAssertEqual(store.matches.count, 0)
    }
    func testRenameAndArchiveKeepStatistics() throws {
        let store = try makeStore(); try store.addPlayer("A"); try store.addPlayer("B")
        let player = store.players[0]
        let id = try store.start(players: store.players, bestOf: 1, reds: 15, starter: 0, traditional: false)
        store.act(.pot(.red), matchID: id); store.act(.pot(.black), matchID: id); store.act(.awardFrame(0), matchID: id)
        try store.editPlayer(player, name: "Renamed", archived: true)
        XCTAssertEqual(store.visiblePlayers.count, 1); XCTAssertEqual(store.names(store.matches[0])[0], "Renamed")
        XCTAssertEqual(PlayerStats(playerID: player.id, matches: store.matches).matchesWon, 1)
    }
    func testWatchCommandsRejectStaleAndDuplicateScoring() throws {
        let store = try makeStore(); try store.addPlayer("A"); try store.addPlayer("B")
        let id = try store.start(players: store.players, bestOf: 3, reds: 15, starter: 0, traditional: false)
        let original = store.activeMatch!
        let command = WatchCommand(matchID: id, frameID: original.frame.id, revision: 0, action: .pot(.red))
        XCTAssertNil(store.watch.onCommand?(command))
        XCTAssertEqual(store.activeMatch!.frame.state.scores[0], 1)
        XCTAssertNil(store.watch.onCommand?(command))
        XCTAssertEqual(store.activeMatch!.frame.state.scores[0], 1)
        let stale = WatchCommand(matchID: id, frameID: original.frame.id, revision: 0, action: .pot(.black))
        XCTAssertNotNil(store.watch.onCommand?(stale))
        XCTAssertEqual(store.activeMatch!.frame.state.scores[0], 1)
        let current = WatchCommand(matchID: id, frameID: original.frame.id, revision: 1, action: .pot(.black))
        XCTAssertNil(store.watch.onCommand?(current)); XCTAssertEqual(store.activeMatch!.frame.state.scores[0], 8)
    }
    func testPastFrameEditingUndoRedoAndDeletionUpdateStatistics() throws {
        let store = try makeStore(); try store.addPlayer("A"); try store.addPlayer("B")
        let id = try store.start(players: store.players, bestOf: 3, reds: 15, starter: 0, traditional: false)
        store.act(.awardFrame(0), matchID: id); store.nextFrame(id); store.act(.awardFrame(0), matchID: id)
        let first = store.matches[0].frames[0]
        try store.editFrame(id, frameID: first.id, action: .correctFrame(scores: [10,30], winner: 1, breaks: [BreakEntry(player: 1, points: 20)], date: first.startedAt))
        XCTAssertEqual(store.matches[0].wins,[1,1]); XCTAssertEqual(PlayerStats(playerID: store.players[1].id, matches: store.matches).highestBreak,20)
        try store.editFrame(id, frameID: first.id, undo: true); XCTAssertEqual(store.matches[0].wins,[2,0])
        try store.editFrame(id, frameID: first.id, redo: true); XCTAssertEqual(store.matches[0].wins,[1,1])
        _ = try Backup.decode(store.backup().encoded())
        try store.deleteMatch(id); XCTAssertTrue(store.matches.isEmpty); XCTAssertNil(store.activeID)
    }
    func testWatchRedoAndNextFrameCommands() throws {
        let store = try makeStore(); try store.addPlayer("A"); try store.addPlayer("B")
        let id = try store.start(players: store.players, bestOf: 0, reds: 15, starter: 0, traditional: false)
        store.act(.pot(.red), matchID: id); store.undo(id)
        var match = store.activeMatch!
        XCTAssertNil(store.watch.onCommand?(WatchCommand(matchID: id, frameID: match.frame.id, revision: match.revision, action: nil, redo: true)))
        XCTAssertEqual(store.activeMatch!.frame.state.scores,[1,0])
        store.act(.awardFrame(0), matchID: id); match = store.activeMatch!
        XCTAssertNil(store.watch.onCommand?(WatchCommand(matchID: id, frameID: match.frame.id, revision: match.revision, action: nil, nextFrame: true)))
        XCTAssertEqual(store.activeMatch!.frames.count,2)
    }
    func testWatchSnapshotStaysSmallAndKeepsScore() throws {
        var match = Match(players: [Player(name: "A"), Player(name: "B")], bestOf: 35, reds: 15, firstPlayer: 0, traditional: false)
        for _ in 0..<500 { try match.record(.endTurn) }
        let snapshot = WatchSnapshot(match: match, names: ["A", "B"])
        XCTAssertLessThan(try JSONEncoder().encode(snapshot).count, 2000)
        XCTAssertEqual(snapshot.match!.revision, 500)
        XCTAssertTrue(snapshot.match!.canUndo)
        XCTAssertEqual(snapshot.match!.frame.state.scores, match.frame.state.scores)
    }
    func testWatchRejectsMalformedSnapshotsAndAcceptsEmptyState() throws {
        let match = Match(players: [Player(name: "A"), Player(name: "B")], bestOf: 3, reds: 15, firstPlayer: 0, traditional: false)
        var snapshot = WatchSnapshot(match: match, names: ["A", "B"])
        XCTAssertTrue(snapshot.isValid)
        snapshot.names = []; XCTAssertFalse(snapshot.isValid)
        snapshot.names = ["A", "B"]; snapshot.match!.frame.state.scores = [0]; XCTAssertFalse(snapshot.isValid)
        XCTAssertTrue(WatchSnapshot(match: nil, names: []).isValid)
    }
}
#endif
