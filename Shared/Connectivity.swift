import Foundation
import WatchConnectivity
import Observation

struct WatchSnapshot: Codable, Sendable {
    var match: WatchMatch?
    var names: [String]
    init(match: Match?, names: [String]) { self.match = match.map(WatchMatch.init); self.names = names }
    var isValid: Bool {
        guard let match else { return names.isEmpty }
        let state = match.frame.state
        return names.count == 2 && match.wins.count == 2 && state.scores.count == 2 && (0...1).contains(state.activePlayer) && (state.winner == nil || (0...1).contains(state.winner!)) && (match.winner == nil || (0...1).contains(match.winner!)) && (1...1000).contains(match.framesCount) && state.elapsed.isFinite && state.elapsed >= 0 && (2...7).contains(state.nextColour) && (0...15).contains(state.redsRemaining)
    }
}
struct WatchFrame: Codable, Sendable {
    var id: UUID
    var state: FrameState
}
struct WatchMatch: Codable, Sendable {
    var id: UUID
    var revision: Int
    var framesCount: Int
    var wins: [Int]
    var winner: Int?
    var traditional: Bool
    var frame: WatchFrame
    var canUndo: Bool
    var closed: Bool?
    var canRedo: Bool?
    var isComplete: Bool { closed == true || winner != nil }
    init(_ match: Match) {
        id = match.id; revision = match.revision; framesCount = match.frames.count
        wins = match.wins; winner = match.winner; traditional = match.traditional
        var state = match.frame.state
        state.breaks = [] // Historical shots and breaks stay on the phone, keeping wrist updates small.
        frame = WatchFrame(id: match.frame.id, state: state)
        canUndo = match.canUndo; canRedo = match.canRedo; closed = match.isComplete
    }
}
struct WatchCommand: Codable, Sendable {
    var id = UUID()
    var matchID: UUID
    var frameID: UUID
    var revision: Int
    var action: ScoringAction?
    var undo = false
    var redo: Bool?
    var nextFrame: Bool?
}

@MainActor @Observable final class Connectivity: NSObject, WCSessionDelegate {
    var snapshot = WatchSnapshot(match: nil, names: [])
    var reachable = false
    var sending = false
    var message: String?
    var onCommand: ((WatchCommand) -> String?)?
    var onRefresh: (() -> Void)?
    private let session: WCSession? = WCSession.isSupported() ? .default : nil
    func activate() { session?.delegate = self; session?.activate() }
    func publish(_ snapshot: WatchSnapshot) {
        self.snapshot = snapshot
        guard let session, session.activationState == .activated, let data = try? JSONEncoder().encode(snapshot) else { return }
        #if os(iOS)
        guard session.isPaired, session.isWatchAppInstalled else { return }
        try? session.updateApplicationContext(["snapshot": data])
        if session.isReachable { session.sendMessage(["snapshot": data], replyHandler: nil, errorHandler: nil) }
        #endif
    }
    func refresh() {
        #if os(watchOS)
        guard let session, session.isReachable else { return }
        session.sendMessage(["refresh": true], replyHandler: { [weak self] response in
            let data = response["snapshot"] as? Data
            Task { @MainActor in self?.accept(data) }
        }, errorHandler: { [weak self] _ in Task { @MainActor in self?.reachable = false } })
        #endif
    }
    func send(_ action: ScoringAction?, undo: Bool = false, redo: Bool = false, nextFrame: Bool = false) {
        guard let match = snapshot.match, let session, session.isReachable, !sending else { message = "Open BaizeBook on your iPhone to reconnect."; return }
        let command = WatchCommand(matchID: match.id, frameID: match.frame.id, revision: match.revision, action: action, undo: undo, redo: redo, nextFrame: nextFrame)
        guard let data = try? JSONEncoder().encode(command) else { return }
        sending = true
        session.sendMessage(["command": data], replyHandler: { [weak self] response in
            let data = response["snapshot"] as? Data; let error = response["error"] as? String
            Task { @MainActor in self?.sending = false; self?.accept(data); self?.message = error }
        }, errorHandler: { [weak self] _ in Task { @MainActor in self?.sending = false; self?.message = "Connection interrupted. Check the score on your phone before trying again." } })
    }
    private func accept(_ data: Data?) {
        if let data, let snapshot = try? JSONDecoder().decode(WatchSnapshot.self, from: data), snapshot.isValid { self.snapshot = snapshot }
    }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let data = session.receivedApplicationContext["snapshot"] as? Data; let reachable = session.isReachable
        Task { @MainActor in self.reachable = reachable; self.accept(data); self.onRefresh?(); self.refresh() }
    }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.reachable = reachable; if reachable { self.onRefresh?(); self.refresh() } }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let data = applicationContext["snapshot"] as? Data
        Task { @MainActor in self.accept(data) }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let data = message["snapshot"] as? Data
        Task { @MainActor in self.accept(data) }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        let commandData = message["command"] as? Data
        Task { @MainActor in
            var response: [String: Any] = [:]
            if let commandData, let command = try? JSONDecoder().decode(WatchCommand.self, from: commandData) {
                if let error = self.onCommand?(command) { response["error"] = error }
            }
            self.onRefresh?()
            response["snapshot"] = try? JSONEncoder().encode(self.snapshot)
            replyHandler(response)
        }
    }
    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
