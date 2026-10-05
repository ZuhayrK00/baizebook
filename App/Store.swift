import SwiftUI
import SwiftData
import UniformTypeIdentifiers

@Model final class LocalRecord {
    @Attribute(.unique) var key: String
    var kind: String
    var payload: Data
    init(key: String, kind: String, payload: Data) { self.key = key; self.kind = kind; self.payload = payload }
}

@MainActor @Observable final class AppStore {
    let container: ModelContainer
    private let context: ModelContext
    var players: [Player] = []
    var matches: [Match] = []
    var activeID: UUID?
    var message: String?
    var importPreview: ImportDraft?
    var importLoading = false
    var dataResetID = UUID()
    var watch = Connectivity()
    private var commands: Set<UUID> = []
    private let defaults: UserDefaults
    private let connectsWatch: Bool
    private var importGeneration = UUID()
    var activeMatch: Match? { matches.first { $0.id == activeID } }
    var visiblePlayers: [Player] { players.filter { !$0.archived }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }

    init(configuration suppliedConfiguration: ModelConfiguration? = nil, defaults: UserDefaults = .standard, connectWatch: Bool = true) throws {
        self.defaults = defaults
        self.connectsWatch = connectWatch
        try FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
        var configuration = ModelConfiguration("BaizeBook", cloudKitDatabase: .none)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-tests") {
            let directory = URL.applicationSupportDirectory.appending(path: "BaizeBookUITests", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appending(path: "Tests.store")
            if ProcessInfo.processInfo.arguments.contains("--reset-testdata") {
                for suffix in ["", "-wal", "-shm"] { let file = URL(fileURLWithPath: url.path + suffix); if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) } }
            }
            configuration = ModelConfiguration("UITests", url: url, cloudKitDatabase: .none)
        }
        #endif
        if let suppliedConfiguration { configuration = suppliedConfiguration }
        container = try ModelContainer(for: LocalRecord.self, configurations: configuration)
        context = ModelContext(container); context.autosaveEnabled = false
        let rows = try context.fetch(FetchDescriptor<LocalRecord>())
        for row in rows {
            if row.kind == "player" { players.append(try JSONDecoder().decode(Player.self, from: row.payload)) }
            else if row.kind == "match" { let match = try JSONDecoder().decode(Match.self, from: row.payload); try match.validate(); matches.append(match) }
        }
        matches.sort { $0.createdAt > $1.createdAt }
        activeID = defaults.string(forKey: "activeMatch").flatMap(UUID.init(uuidString:))
        if activeMatch == nil { activeID = matches.first(where: { !$0.isComplete })?.id }
        watch.onCommand = { [weak self] command in
            guard let self else { return "The phone is unavailable." }
            return self.receive(command)
        }
        watch.onRefresh = { [weak self] in self?.publish() }
        if connectWatch { watch.activate(); publish() }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--demo") && players.isEmpty { try seedDemo() }
        #endif
    }
    func save<T: Encodable>(_ value: T, id: UUID, kind: String) throws {
        let data = try JSONEncoder().encode(value)
        do {
            let key = id.uuidString
            let descriptor = FetchDescriptor<LocalRecord>(predicate: #Predicate { $0.key == key })
            if let record = try context.fetch(descriptor).first { record.payload = data }
            else { context.insert(LocalRecord(key: key, kind: kind, payload: data)) }
            try context.save()
        } catch { context.rollback(); throw error }
    }
    func addPlayer(_ name: String) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 40 else { throw ScoringError("Use a player name of 1–40 characters.") }
        let player = Player(name: name); try save(player, id: player.id, kind: "player"); players.append(player)
    }
    func editPlayer(_ player: Player, name: String, archived: Bool) throws {
        var updated = player; updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines); updated.archived = archived
        guard !updated.name.isEmpty, updated.name.count <= 40 else { throw ScoringError("Use a player name of 1–40 characters.") }
        try save(updated, id: updated.id, kind: "player")
        players[players.firstIndex(where: { $0.id == updated.id })!] = updated
        publish()
    }
    func start(players selected: [Player], bestOf: Int, reds: Int, starter: Int, traditional: Bool) throws -> UUID {
        let match = Match(players: selected, bestOf: bestOf, reds: reds, firstPlayer: starter, traditional: traditional)
        try match.validate(); try save(match, id: match.id, kind: "match")
        matches.insert(match, at: 0); select(match.id); return match.id
    }
    func select(_ id: UUID) { activeID = id; defaults.set(id.uuidString, forKey: "activeMatch"); publish() }
    func update(_ match: Match) throws {
        try save(match, id: match.id, kind: "match")
        matches[matches.firstIndex(where: { $0.id == match.id })!] = match
        publish()
    }
    func act(_ action: ScoringAction, matchID: UUID) {
        perform { guard var match = self.matches.first(where: { $0.id == matchID }) else { return }; try match.record(action); try self.update(match) }
    }
    func reviseRedPot(_ id: UUID, total: Int, shotID: UUID) {
        perform {
            guard var match = self.matches.first(where: { $0.id == id }), !match.isComplete, !match.traditional else { throw ScoringError("This frame is no longer available for scoring.") }
            try match.frames[match.frames.count-1].reviseRedPot(total: total, shotID: shotID)
            match.redoNewFrame = nil; match.redoClosedAt = nil; match.redoDeclaredWinner = nil; match.revision += 1
            try match.validate(); try self.update(match)
        }
    }
    func undo(_ id: UUID) { perform { guard var match = self.matches.first(where: { $0.id == id }) else { return }; match.undo(); try self.update(match) } }
    func redo(_ id: UUID) { perform { guard var match = self.matches.first(where: { $0.id == id }) else { return }; try match.redo(); try self.update(match) } }
    func closeMatch(_ id: UUID) { perform { guard var match = self.matches.first(where: { $0.id == id }) else { return }; if match.frame.state.phase != .finished && match.frame.state.resumedAt != nil { try match.record(.pause(true)) }; match.closedAt = Date(); match.revision += 1; try self.update(match) } }
    func editFrame(_ matchID: UUID, frameID: UUID, action: ScoringAction? = nil, undo: Bool = false, redo: Bool = false) throws {
        guard var match = matches.first(where: { $0.id == matchID }), let index = match.frames.firstIndex(where: { $0.id == frameID }) else { throw ScoringError("Frame not found.") }
        if undo { match.frames[index].undo() } else if redo { try match.frames[index].redo() } else if let action { try match.frames[index].record(action) }
        match.historyEdited = true; match.declaredWinner = match.sourceWins == match.wins ? match.sourceWinner : nil; match.revision += 1; try match.validate(); try update(match)
    }
    func addPastMatch(_ match: Match) throws { try match.validate(); try save(match, id: match.id, kind: "match"); matches.append(match); matches.sort { $0.createdAt > $1.createdAt }; publish() }
    func deleteMatch(_ id: UUID) throws {
        let key = id.uuidString
        do { let descriptor = FetchDescriptor<LocalRecord>(predicate: #Predicate { $0.key == key }); for row in try context.fetch(descriptor) { context.delete(row) }; try context.save() } catch { context.rollback(); throw error }
        matches.removeAll { $0.id == id }; if activeID == id { activeID = nil; defaults.removeObject(forKey: "activeMatch") }; publish()
    }
    func clearAllData() throws {
        // Commit the deletion before changing the UI or preferences so a failed save keeps the current data intact.
        do {
            for row in try context.fetch(FetchDescriptor<LocalRecord>()) { context.delete(row) }
            try context.save()
        } catch { context.rollback(); throw error }

        players.removeAll(); matches.removeAll(); activeID = nil; commands.removeAll()
        importGeneration = UUID(); importPreview = nil; importLoading = false; message = nil
        for key in ["activeMatch", "defaultReds", "defaultBestOf", "defaultTraditional", "appearance", "haptics", "keepAwake"] {
            defaults.removeObject(forKey: key)
        }
        watch.snapshot = WatchSnapshot(match: nil, names: [])
        publish()
        dataResetID = UUID()
    }
    func nextFrame(_ id: UUID) { perform { guard var match = self.matches.first(where: { $0.id == id }) else { return }; try match.nextFrame(); try self.update(match) } }
    func perform(_ operation: () throws -> Void) { do { try operation() } catch { message = error.localizedDescription } }
    func name(_ id: UUID, fallback: String) -> String { players.first { $0.id == id }?.name ?? fallback }
    func names(_ match: Match) -> [String] { zip(match.playerIDs, match.playerNames).map { name($0.0, fallback: $0.1) } }
    func backup() -> Backup { Backup(players: players, matches: matches) }
    func prepareImport(_ url: URL) {
        guard !importLoading else { return }
        importLoading = true
        let generation = importGeneration
        Task {
            guard generation == importGeneration else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer {
                if access { url.stopAccessingSecurityScopedResource() }
                if generation == importGeneration { importLoading = false }
            }
            do {
                let draft = try await Task.detached(priority: .userInitiated) {
                    if let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 20*1024*1024 { throw ScoringError("Choose a JSON file smaller than 20 MB.") }
                    return try ImportDraft.decode(Data(contentsOf: url))
                }.value
                guard generation == importGeneration else { return }
                importPreview = draft
            } catch { if generation == importGeneration { message = error.localizedDescription } }
        }
    }
    func merge(_ backup: Backup) throws -> String {
        try backup.validate()
        guard !backup.players.contains(where: { p in matches.contains { $0.id == p.id } }), !backup.matches.contains(where: { m in players.contains { $0.id == m.id } }) else { throw ScoringError("This backup has an ID conflict with an entry on this device.") }
        let newPlayers = backup.players.filter { p in !players.contains { $0.id == p.id } }
        let newMatches = backup.matches.filter { m in !matches.contains { $0.id == m.id } }
        // A single database transaction prevents partially imported files.
        do {
            for player in newPlayers { context.insert(LocalRecord(key: player.id.uuidString, kind: "player", payload: try JSONEncoder().encode(player))) }
            for match in newMatches { context.insert(LocalRecord(key: match.id.uuidString, kind: "match", payload: try JSONEncoder().encode(match))) }
            try context.save()
        } catch { context.rollback(); throw error }
        players += newPlayers; matches += newMatches; matches.sort { $0.createdAt > $1.createdAt }; publish()
        return "Imported \(newPlayers.count) players and \(newMatches.count) matches. Existing entries were kept."
    }
    func publish() { if connectsWatch { watch.publish(WatchSnapshot(match: activeMatch, names: activeMatch.map(names) ?? [])) } }
    private func receive(_ command: WatchCommand) -> String? {
        if commands.contains(command.id) { return nil }
        guard var match = activeMatch, match.id == command.matchID, match.frame.id == command.frameID, match.revision == command.revision else { publish(); return "The score changed on your phone. Try again with the updated score." }
        do {
            if command.nextFrame == true { try match.nextFrame() } else if command.redo == true { try match.redo() } else if command.undo { match.undo() } else if let action = command.action { try match.record(action) }
            try update(match); commands.insert(command.id)
            if commands.count > 500 { commands = [command.id] }
            return nil
        } catch { return error.localizedDescription }
    }
    #if DEBUG
    private func seedDemo() throws {
        try addPlayer("Alex"); try addPlayer("Jamie")
        for i in 0..<3 {
            let date = Date().addingTimeInterval(Double(-86400*(i+1)))
            var demo = Match(players: players, bestOf: 3, reds: 15, firstPlayer: 0, traditional: false, date: date)
            for frame in 0..<2 {
                let winner = i == 1 ? 1 : 0
                let base = date.addingTimeInterval(Double(frame*1800))
                if demo.frame.state.activePlayer != winner { try demo.record(.endTurn, date: base) }
                for pot in 0..<[4,7,3][i] {
                    try demo.record(.pot(.red), date: base.addingTimeInterval(Double(pot*30+1)))
                    try demo.record(.pot(.black), date: base.addingTimeInterval(Double(pot*30+15)))
                }
                try demo.record(.awardFrame(winner), date: base.addingTimeInterval(1200))
                if frame == 0 { try demo.nextFrame(date: base.addingTimeInterval(1800)) }
            }
            try save(demo, id: demo.id, kind: "match"); matches.append(demo)
        }
        _ = try start(players: players, bestOf: 5, reds: 15, starter: 0, traditional: false)
        for _ in 0..<3 { act(.pot(.red), matchID: activeID!); act(.pot(.black), matchID: activeID!) }
    }
    #endif
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
