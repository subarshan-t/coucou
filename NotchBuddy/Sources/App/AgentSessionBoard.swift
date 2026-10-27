import Foundation

// MARK: - AgentSessionBoard

/// One row per agent session behind a pill, for the pill's session list.
///
/// `PillSessionRegistry` decides whether an event may touch the pill; this
/// board only remembers what each session is doing, so a pill that many
/// agents share (Grok Build runs a dozen at once) can list them all instead
/// of showing only the last step any of them took.
///
/// A value type for the same reason as the registry: the hook server owns
/// the one copy and publishes the rows to `AppState` after each change.
struct AgentSessionBoard {

    enum Status: Equatable {
        /// `idle`: started, no turn yet (or interrupted).
        case idle, thinking, working, finished, error

        var isActive: Bool { self == .thinking || self == .working }
    }

    struct Row: Identifiable, Equatable {
        /// The session id the agent sent.
        let id: String
        var label: String
        var status: Status
        /// Last prompt, tool step or closing line, one line.
        var step: String
        var started: Date
        var updated: Date
    }

    /// A row unheard of for this long while active counts as stopped:
    /// its `Stop` went missing. Same reasoning as the registry's turn silence.
    static let maxTurnSilence: TimeInterval = 30 * 60
    /// A row that stopped this long ago leaves the list.
    static let finishedLifetime: TimeInterval = 15 * 60
    /// The list never grows past this, oldest stopped rows go first.
    static let maxRows = 40

    private var pills: [String: [Row]] = [:]

    // MARK: - Recording

    /// Records an event from `session`. `label` names the row the first time
    /// the session is seen; a later non-empty label (a rename) replaces it.
    mutating func record(pill: String, session: String, label: String,
                         status: Status, step: String?, now: Date = Date()) {
        var rows = pills[pill] ?? []
        sweep(&rows, now: now)
        let trimmed = step.map { String($0.prefix(80)) }
        if let i = rows.firstIndex(where: { $0.id == session }) {
            if !label.isEmpty, label != rows[i].label {
                rows[i].label = uniqueLabel(label, in: rows, excluding: session)
            }
            if !rows[i].status.isActive && status.isActive { rows[i].started = now }
            rows[i].status = status
            if let trimmed, !trimmed.isEmpty { rows[i].step = trimmed }
            rows[i].updated = now
        } else {
            let base = label.isEmpty ? String(session.prefix(8)) : label
            rows.append(Row(id: session, label: uniqueLabel(base, in: rows, excluding: session),
                            status: status, step: trimmed ?? "", started: now, updated: now))
        }
        trim(&rows)
        pills[pill] = rows
    }

    /// Drops a session for good (`SessionEnd`).
    mutating func remove(pill: String, session: String) {
        pills[pill]?.removeAll { $0.id == session }
        if pills[pill]?.isEmpty == true { pills.removeValue(forKey: pill) }
    }

    // MARK: - Reading

    /// Rows for the list: active sessions first, oldest start first so a row
    /// does not jump while it works, then stopped ones, latest first.
    func rows(pill: String, now: Date = Date()) -> [Row] {
        var rows = pills[pill] ?? []
        sweep(&rows, now: now)
        let active = rows.filter { $0.status.isActive }.sorted { $0.started < $1.started }
        let done = rows.filter { !$0.status.isActive }.sorted { $0.updated > $1.updated }
        return active + done
    }

    func activeCount(pill: String, now: Date = Date()) -> Int {
        rows(pill: pill, now: now).filter { $0.status.isActive }.count
    }

    // MARK: - Housekeeping

    private func sweep(_ rows: inout [Row], now: Date) {
        rows.removeAll { !$0.status.isActive && now.timeIntervalSince($0.updated) > Self.finishedLifetime }
        for i in rows.indices where rows[i].status.isActive
            && now.timeIntervalSince(rows[i].updated) > Self.maxTurnSilence {
            rows[i].status = .finished
        }
    }

    private func trim(_ rows: inout [Row]) {
        while rows.count > Self.maxRows {
            let stopped = rows.indices.filter { !rows[$0].status.isActive }
            guard let oldest = stopped.min(by: { rows[$0].updated < rows[$1].updated }) else {
                rows.removeFirst()
                continue
            }
            rows.remove(at: oldest)
        }
    }

    /// Two sessions in the same folder would read the same: "api", "api 2".
    private func uniqueLabel(_ label: String, in rows: [Row], excluding session: String) -> String {
        let taken = Set(rows.filter { $0.id != session }.map(\.label))
        guard taken.contains(label) else { return label }
        var n = 2
        while taken.contains("\(label) \(n)") { n += 1 }
        return "\(label) \(n)"
    }
}
