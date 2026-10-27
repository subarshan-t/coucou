import Foundation

// MARK: - Agent usage (Usage page)
// How much each coding-agent account used, read from the files the agents already keep on this
// Mac: Claude Code's session transcripts (<config>/projects/**/*.jsonl) and Codex's session
// rollouts (<codex home>/sessions/**/rollout-*.jsonl). No API key, nothing sent anywhere.
// Pure Foundation: tests/AgentUsageTests.swift checks the parsers on sample lines.

struct TokenTotals: Codable, Equatable, Sendable {
    var input = 0
    var output = 0
    var cacheRead = 0
    var cacheWrite = 0

    var total: Int { input + output + cacheRead + cacheWrite }

    static func + (a: TokenTotals, b: TokenTotals) -> TokenTotals {
        TokenTotals(input: a.input + b.input, output: a.output + b.output,
                    cacheRead: a.cacheRead + b.cacheRead, cacheWrite: a.cacheWrite + b.cacheWrite)
    }
}

/// One rate-limit window as a percentage of the plan.
struct UsageWindow: Codable, Equatable, Sendable {
    var usedPct: Double
    var resetsAt: Date
}

struct UsageLimits: Codable, Equatable, Sendable {
    var fiveHour: UsageWindow?
    var weekly: UsageWindow?
    var updatedAt: Date
}

enum AgentKind: String, Codable, Sendable { case claude, codex }

/// One signed-in agent setup on this Mac (a config folder).
struct AgentAccount: Equatable, Sendable {
    var kind: AgentKind
    /// The config folder (~/.claude, ~/.claude-work, ~/.codex…).
    var directory: URL
    /// The signed-in email when the agent saved it, else the folder name.
    var label: String
}

/// What one session file contributed: tokens per local day, and the newest limits it saw.
struct FileUsage: Sendable {
    var days: [String: TokenTotals] = [:]
    var limits: UsageLimits?
}

enum AgentUsage {
    // MARK: Dates

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func parseDate(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    private static func int(_ v: Any?) -> Int {
        if let i = v as? Int { return i }
        if let d = v as? Double { return Int(d) }
        if let n = v as? NSNumber { return n.intValue }
        return 0
    }

    private static func double(_ v: Any?) -> Double? {
        if let d = v as? Double { return d }
        if let i = v as? Int { return Double(i) }
        if let n = v as? NSNumber { return n.doubleValue }
        return nil
    }

    // MARK: Claude Code transcripts

    /// Tokens per day from a Claude Code transcript. A reply is written several times while it
    /// streams (same message id and request id): it is counted once.
    static func claudeTranscript(_ text: String, since: Date, calendar: Calendar) -> FileUsage {
        var out = FileUsage()
        var seen = Set<String>()
        for line in text.split(separator: "\n") {
            guard line.contains("\"usage\""),
                  let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  obj["type"] as? String == "assistant",
                  let msg = obj["message"] as? [String: Any],
                  let usage = msg["usage"] as? [String: Any],
                  let ts = (obj["timestamp"] as? String).flatMap(parseDate), ts >= since else { continue }
            let key = "\(msg["id"] as? String ?? "")|\(obj["requestId"] as? String ?? "")"
            if key != "|" {
                guard seen.insert(key).inserted else { continue }
            }
            let t = TokenTotals(input: int(usage["input_tokens"]), output: int(usage["output_tokens"]),
                                cacheRead: int(usage["cache_read_input_tokens"]),
                                cacheWrite: int(usage["cache_creation_input_tokens"]))
            let day = dayKey(ts, calendar: calendar)
            out.days[day, default: TokenTotals()] = out.days[day, default: TokenTotals()] + t
        }
        return out
    }

    /// Claude Code's status line rate_limits (as relayed by the hook) as limits.
    static func claudeLimits(_ rateLimits: [String: Any], now: Date) -> UsageLimits? {
        func window(_ raw: Any?) -> UsageWindow? {
            guard let d = raw as? [String: Any], let pct = double(d["used_percentage"]),
                  let epoch = double(d["resets_at"]), epoch > 0 else { return nil }
            return UsageWindow(usedPct: min(100, max(0, pct)), resetsAt: Date(timeIntervalSince1970: epoch))
        }
        let l = UsageLimits(fiveHour: window(rateLimits["five_hour"]), weekly: window(rateLimits["seven_day"]), updatedAt: now)
        return l.fiveHour == nil && l.weekly == nil ? nil : l
    }

    // MARK: Codex rollouts

    /// Tokens per day from a Codex session rollout (its token_count events), and the newest
    /// rate limits it recorded.
    static func codexRollout(_ text: String, since: Date, calendar: Calendar) -> FileUsage {
        var out = FileUsage()
        for line in text.split(separator: "\n") {
            guard line.contains("token_count"),
                  let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let payload = obj["payload"] as? [String: Any],
                  payload["type"] as? String == "token_count",
                  let ts = (obj["timestamp"] as? String).flatMap(parseDate) else { continue }
            if ts >= since, let info = payload["info"] as? [String: Any],
               let last = info["last_token_usage"] as? [String: Any] {
                let input = int(last["input_tokens"]), cached = int(last["cached_input_tokens"])
                let t = TokenTotals(input: max(0, input - cached), output: int(last["output_tokens"]),
                                    cacheRead: cached, cacheWrite: 0)
                let day = dayKey(ts, calendar: calendar)
                out.days[day, default: TokenTotals()] = out.days[day, default: TokenTotals()] + t
            }
            if let rl = payload["rate_limits"] as? [String: Any], let limits = codexLimits(rl, at: ts),
               (out.limits?.updatedAt ?? .distantPast) <= ts {
                out.limits = limits
            }
        }
        return out
    }

    /// Codex rate_limits: primary/secondary windows, sorted into 5-hour and weekly by length.
    static func codexLimits(_ rl: [String: Any], at ts: Date) -> UsageLimits? {
        var five: UsageWindow?, week: UsageWindow?
        for key in ["primary", "secondary"] {
            guard let w = rl[key] as? [String: Any], let pct = double(w["used_percent"]) else { continue }
            let resets: Date
            if let at = double(w["resets_at"]), at > 0 { resets = Date(timeIntervalSince1970: at) }
            else if let inS = double(w["resets_in_seconds"]) { resets = ts.addingTimeInterval(inS) }
            else { continue }
            let window = UsageWindow(usedPct: min(100, max(0, pct)), resetsAt: resets)
            let minutes = double(w["window_minutes"]) ?? (key == "primary" ? 300 : 10_080)
            if minutes <= 24 * 60 { five = window } else { week = window }
        }
        return five == nil && week == nil ? nil : UsageLimits(fiveHour: five, weekly: week, updatedAt: ts)
    }

    // MARK: Accounts

    /// Claude Code setups: ~/.claude, plus any ~/.claude-* or ~/.claude_* folder with sessions
    /// (one per CLAUDE_CONFIG_DIR). The label is the signed-in email when Claude Code saved it.
    static func claudeAccounts(home: URL, fm: FileManager = .default) -> [AgentAccount] {
        var out: [AgentAccount] = []
        for dir in candidateDirs(home: home, base: ".claude", fm: fm)
        where fm.fileExists(atPath: dir.appendingPathComponent("projects").path) {
            // Default setup keeps its account in ~/.claude.json; a CLAUDE_CONFIG_DIR inside it.
            let isDefault = dir.lastPathComponent == ".claude"
            let json = isDefault ? home.appendingPathComponent(".claude.json") : dir.appendingPathComponent(".claude.json")
            let email = claudeEmail(jsonAt: json)
            out.append(AgentAccount(kind: .claude, directory: dir, label: email ?? folderLabel(dir)))
        }
        return out
    }

    static func claudeEmail(jsonAt url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let acct = obj["oauthAccount"] as? [String: Any] else { return nil }
        return acct["emailAddress"] as? String
    }

    /// Codex setups: ~/.codex, plus any ~/.codex-* or ~/.codex_* folder with sessions (CODEX_HOME).
    static func codexAccounts(home: URL, fm: FileManager = .default) -> [AgentAccount] {
        candidateDirs(home: home, base: ".codex", fm: fm)
            .filter { fm.fileExists(atPath: $0.appendingPathComponent("sessions").path) }
            .map { AgentAccount(kind: .codex, directory: $0,
                                label: codexEmail(authAt: $0.appendingPathComponent("auth.json")) ?? folderLabel($0)) }
    }

    /// The email in Codex's auth.json id_token (a JWT; only its public payload is read).
    static func codexEmail(authAt url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = obj["tokens"] as? [String: Any],
              let idToken = tokens["id_token"] as? String else { return nil }
        return jwtEmail(idToken)
    }

    static func jwtEmail(_ jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var b64 = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj["email"] as? String
    }

    private static func candidateDirs(home: URL, base: String, fm: FileManager) -> [URL] {
        var dirs = [home.appendingPathComponent(base)]
        let names = (try? fm.contentsOfDirectory(atPath: home.path)) ?? []
        for n in names.sorted() where n.hasPrefix(base + "-") || n.hasPrefix(base + "_") {
            dirs.append(home.appendingPathComponent(n))
        }
        return dirs
    }

    private static func folderLabel(_ dir: URL) -> String { "~/" + dir.lastPathComponent }

    /// Which account a status line update belongs to: CLAUDE_CONFIG_DIR when set, else the
    /// account whose folder holds the session's transcript, else the default ~/.claude.
    static func claudeAccount(configDir: String, transcriptPath: String, accounts: [AgentAccount]) -> AgentAccount? {
        let claude = accounts.filter { $0.kind == .claude }
        func norm(_ p: String) -> String { (p as NSString).standardizingPath }
        if !configDir.isEmpty, let a = claude.first(where: { norm($0.directory.path) == norm(configDir) }) { return a }
        if !transcriptPath.isEmpty,
           let a = claude.first(where: { norm(transcriptPath).hasPrefix(norm($0.directory.path) + "/") }) { return a }
        return claude.first { $0.directory.lastPathComponent == ".claude" }
    }

    // MARK: Files

    /// Session files under `root` changed since `since` (older files can't hold recent usage).
    static func sessionFiles(under root: URL, since: Date, fm: FileManager = .default) -> [URL] {
        guard let e = fm.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                                    options: [.skipsHiddenFiles]) else { return [] }
        var out: [URL] = []
        for case let url as URL in e where url.pathExtension == "jsonl" {
            let v = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard v?.isRegularFile == true, (v?.contentModificationDate ?? .distantPast) >= since else { continue }
            out.append(url)
        }
        return out
    }

    /// Sums days across files and keeps the newest limits.
    static func merge(_ files: [FileUsage]) -> FileUsage {
        var out = FileUsage()
        for f in files {
            for (d, t) in f.days { out.days[d, default: TokenTotals()] = out.days[d, default: TokenTotals()] + t }
            if let l = f.limits, (out.limits?.updatedAt ?? .distantPast) <= l.updatedAt { out.limits = l }
        }
        return out
    }
}
