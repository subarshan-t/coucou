import AppKit
import Foundation

/// Usage per agent account for the Usage page (AgentUsage.swift does the reading). Scans only
/// when asked (the page is open), off the main thread, re-reading only files that changed.
@MainActor
final class UsageStore: ObservableObject {
    static let shared = UsageStore()

    struct AccountUsage: Identifiable {
        var account: AgentAccount
        var today = TokenTotals()
        var week = TokenTotals()
        /// The last 7 days, oldest first: (day, total tokens).
        var days: [(day: String, total: Int)] = []
        var limits: UsageLimits?
        var id: String { account.directory.path }
    }

    @Published private(set) var accounts: [AccountUsage] = []
    @Published private(set) var refreshing = false
    @Published private(set) var lastRefresh: Date?

    /// Claude plan limits per config folder, from the status line. Saved so they survive a restart.
    private var claudeLimits: [String: UsageLimits] = {
        guard let d = UserDefaults.standard.data(forKey: "usageClaudeLimits"),
              let v = try? JSONDecoder().decode([String: UsageLimits].self, from: d) else { return [:] }
        return v
    }()
    private var knownClaude: [AgentAccount] = []
    private var lastSaved = Date.distantPast
    private let cache = UsageScanCache()

    private init() {}

    /// From HookServer: one status line update of a Claude Code session.
    func recordStatusLine(rateLimits: [String: Any], configDir: String, transcriptPath: String) {
        guard let limits = AgentUsage.claudeLimits(rateLimits, now: Date()) else { return }
        if knownClaude.isEmpty {
            knownClaude = AgentUsage.claudeAccounts(home: FileManager.default.homeDirectoryForCurrentUser)
        }
        let key = AgentUsage.claudeAccount(configDir: configDir, transcriptPath: transcriptPath,
                                           accounts: knownClaude)?.directory.path
            ?? (configDir.isEmpty ? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude").path : configDir)
        let old = claudeLimits[key]
        // The status line fires several times a second: keep the numbers, save at most every 30 s.
        claudeLimits[key] = limits
        if old?.fiveHour != limits.fiveHour || old?.weekly != limits.weekly || Date().timeIntervalSince(lastSaved) > 30 {
            lastSaved = Date()
            if let d = try? JSONEncoder().encode(claudeLimits) { UserDefaults.standard.set(d, forKey: "usageClaudeLimits") }
            if let i = accounts.firstIndex(where: { $0.id == key }) { accounts[i].limits = limits }
        }
    }

    /// Re-reads the agents' session files. Cheap when nothing changed.
    func refresh() {
        guard !refreshing else { return }
        refreshing = true
        let cache = self.cache
        let limits = claudeLimits
        Task.detached(priority: .utility) {
            let result = Self.scan(cache: cache, claudeLimits: limits)
            await MainActor.run {
                self.knownClaude = result.map(\.account).filter { $0.kind == .claude }
                self.accounts = result
                self.lastRefresh = Date()
                self.refreshing = false
            }
        }
    }

    nonisolated private static func scan(cache: UsageScanCache, claudeLimits: [String: UsageLimits]) -> [AccountUsage] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let cal = Calendar.current
        let now = Date()
        let startToday = cal.startOfDay(for: now)
        let since = cal.date(byAdding: .day, value: -6, to: startToday) ?? now.addingTimeInterval(-6 * 86_400)
        let dayKeys = (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: startToday) }
            .map { AgentUsage.dayKey($0, calendar: cal) }
        let today = AgentUsage.dayKey(now, calendar: cal)

        var out: [AccountUsage] = []
        let accounts = AgentUsage.claudeAccounts(home: home) + AgentUsage.codexAccounts(home: home)
        for account in accounts {
            let root = account.directory.appendingPathComponent(account.kind == .claude ? "projects" : "sessions")
            let files = AgentUsage.sessionFiles(under: root, since: since)
            let merged = AgentUsage.merge(files.map { cache.usage(of: $0, kind: account.kind, since: since, calendar: cal) })
            var u = AccountUsage(account: account)
            u.today = merged.days[today] ?? TokenTotals()
            u.week = dayKeys.reduce(TokenTotals()) { $0 + (merged.days[$1] ?? TokenTotals()) }
            u.days = dayKeys.map { (day: $0, total: merged.days[$0]?.total ?? 0) }
            u.limits = account.kind == .claude ? claudeLimits[account.directory.path] : merged.limits
            out.append(u)
        }
        return out
    }
}

/// Parsed session files, keyed by path, size and date: an unchanged file is never read twice.
final class UsageScanCache: @unchecked Sendable {
    private struct Entry { let size: Int; let modified: Date; let since: Date; let usage: FileUsage }
    private var entries: [String: Entry] = [:]
    private let lock = NSLock()

    func usage(of url: URL, kind: AgentKind, since: Date, calendar: Calendar) -> FileUsage {
        let v = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let size = v?.fileSize ?? -1, modified = v?.contentModificationDate ?? .distantPast
        lock.lock()
        if let e = entries[url.path], e.size == size, e.modified == modified, e.since == since {
            lock.unlock(); return e.usage
        }
        lock.unlock()
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return FileUsage() }
        let usage = kind == .claude
            ? AgentUsage.claudeTranscript(text, since: since, calendar: calendar)
            : AgentUsage.codexRollout(text, since: since, calendar: calendar)
        lock.lock(); entries[url.path] = Entry(size: size, modified: modified, since: since, usage: usage); lock.unlock()
        return usage
    }
}
