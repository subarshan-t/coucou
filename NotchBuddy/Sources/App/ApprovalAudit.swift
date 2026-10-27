import Foundation

// MARK: - Approval audit log
// A local, append-only record of every permission decision, so the user can see what their
// agents were allowed to do. JSON Lines in ~/Library/Application Support/Giraffy/Audit
// (folder 0700, file 0600). Never sent anywhere. Pure Foundation: tests/ApprovalAuditTests.swift
// checks redaction, retention, CSV and the file itself.

enum AuditDecision: String, Codable, CaseIterable, Sendable {
    case allow, deny, always
    /// The agent's own prompt was answered (the tool ran or the turn ended) before a click.
    case terminal
    /// Nobody answered in time; the agent asked again itself.
    case timeout
}

enum AuditVia: String, Codable, Sendable {
    /// A click on the approval card.
    case notch
    /// A keyboard shortcut.
    case shortcut
    /// Not decided in Giraffy (answered in the terminal, or timed out).
    case none
}

struct AuditEntry: Codable, Equatable, Sendable {
    var timestamp: Date
    /// Agent name as shown to the user ("Claude Code", "Codex"…).
    var agent: String
    /// Project folder name.
    var project: String
    var tool: String
    /// The command or file, with secrets redacted.
    var target: String
    var decision: AuditDecision
    var via: AuditVia
}

// MARK: - Redaction

enum AuditRedactor {
    static let mask = "[REDACTED]"

    /// Patterns that look like keys, tokens or passwords. Matched text is replaced by `mask`;
    /// for `name=value` pairs only the value is masked so the log still says what was set.
    private static let valuePatterns: [String] = [
        #"sk-(?:ant-|proj-)?[A-Za-z0-9_\-]{16,}"#,          // Anthropic / OpenAI
        #"gh[pousr]_[A-Za-z0-9]{20,}"#,                      // GitHub tokens
        #"github_pat_[A-Za-z0-9_]{20,}"#,
        #"xox[abposr]-[A-Za-z0-9\-]{10,}"#,                  // Slack
        #"AKIA[0-9A-Z]{16}"#,                                // AWS access key id
        #"AIza[0-9A-Za-z_\-]{30,}"#,                         // Google API key
        #"(?:sk|rk|pk)_(?:live|test)_[A-Za-z0-9]{10,}"#,     // Stripe-style
        #"eyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}"#, // JWT
        #"-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?(?:-----END [A-Z ]*PRIVATE KEY-----|$)"#,
        #"(?<=://)[^/\s:@]+:[^/\s@]+(?=@)"#,                 // user:password@ in URLs
    ]
    /// `Authorization: Bearer x`, `--password x`, `API_KEY=x`, `"token": "x"`…
    private static let assignmentPattern =
        #"(?i)((?:bearer|basic)\s+|(?:--?)?[a-z0-9_]*(?:api[_-]?key|token|secret|passw(?:or)?d|pwd)["']?(?:\s*[:=]\s*|\s+)["']?)([^\s"'&;|]{6,})"#

    nonisolated(unsafe) private static let compiled: [NSRegularExpression] = valuePatterns.compactMap {
        try? NSRegularExpression(pattern: $0)
    }
    nonisolated(unsafe) private static let assignment = try? NSRegularExpression(pattern: assignmentPattern)
    /// Long unbroken runs of hex or base64 (40+ chars) are almost always secrets or hashes.
    nonisolated(unsafe) private static let longBlob = try? NSRegularExpression(pattern: #"(?<![A-Za-z0-9/+_\-])[A-Za-z0-9+/_\-]{40,}={0,2}(?![A-Za-z0-9/+_\-])"#)

    static func redact(_ text: String) -> String {
        var s = text
        for re in compiled {
            s = re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: mask)
        }
        if let assignment {
            s = assignment.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s),
                                                    withTemplate: "$1\(mask)")
        }
        if let longBlob {
            // Paths are long too: only mask a run that has no "/" or has digits and letters mixed.
            let ns = s as NSString
            var out = ""
            var last = 0
            for m in longBlob.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
                let piece = ns.substring(with: m.range)
                let hasDigit = piece.rangeOfCharacter(from: .decimalDigits) != nil
                let hasLetter = piece.rangeOfCharacter(from: .letters) != nil
                guard hasDigit && hasLetter && !piece.contains("/") else { continue }
                out += ns.substring(with: NSRange(location: last, length: m.range.location - last)) + mask
                last = m.range.location + m.range.length
            }
            out += ns.substring(from: last)
            s = out
        }
        return s
    }
}

// MARK: - Retention, filters, CSV

enum AuditRetention: Int, CaseIterable, Sendable {
    case days30 = 30, days90 = 90, forever = 0

    /// Entries older than this are dropped; nil keeps everything.
    func cutoff(now: Date) -> Date? {
        self == .forever ? nil : now.addingTimeInterval(-Double(rawValue) * 86_400)
    }
}

enum AuditLogic {
    static func kept(_ entries: [AuditEntry], retention: AuditRetention, now: Date) -> [AuditEntry] {
        guard let cutoff = retention.cutoff(now: now) else { return entries }
        return entries.filter { $0.timestamp >= cutoff }
    }

    static func filtered(_ entries: [AuditEntry], agent: String?, decision: AuditDecision?) -> [AuditEntry] {
        entries.filter { (agent == nil || $0.agent == agent) && (decision == nil || $0.decision == decision) }
    }

    static func csvField(_ s: String) -> String {
        // Quote every field; double the quotes inside. A leading = + - @ is prefixed so a
        // spreadsheet never runs a logged command as a formula.
        var v = s.replacingOccurrences(of: "\"", with: "\"\"")
        if let first = v.first, "=+-@\t\r".contains(first) { v = "'" + v }
        return "\"\(v)\""
    }

    static func csv(_ entries: [AuditEntry]) -> String {
        let iso = ISO8601DateFormatter()
        var lines = ["timestamp,agent,project,tool,command_or_file,decision,decided_in"]
        for e in entries {
            lines.append([iso.string(from: e.timestamp), e.agent, e.project, e.tool, e.target,
                          e.decision.rawValue, e.via.rawValue].map(csvField).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func encodeLine(_ e: AuditEntry) -> String? {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? enc.encode(e) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    /// Lines that don't parse (a crash mid-write) are skipped, never fatal.
    static func decode(_ text: String) -> [AuditEntry] {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return text.split(separator: "\n").compactMap { try? dec.decode(AuditEntry.self, from: Data($0.utf8)) }
    }
}

// MARK: - File

/// The log file. Writes append one line; only the retention prune rewrites the file.
final class AuditFile: @unchecked Sendable {
    let directory: URL
    var url: URL { directory.appendingPathComponent("approvals.jsonl") }
    private let lock = NSLock()

    init(directory: URL) { self.directory = directory }

    /// ~/Library/Application Support/Giraffy/Audit
    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Giraffy/Audit", isDirectory: true)
    }

    private func prepare() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true,
                               attributes: [.posixPermissions: 0o700])
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        if !fm.fileExists(atPath: url.path) {
            fm.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
    }

    func append(_ entry: AuditEntry) throws {
        guard let line = AuditLogic.encodeLine(entry) else { return }
        lock.lock(); defer { lock.unlock() }
        try prepare()
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data((line + "\n").utf8))
    }

    func readAll() -> [AuditEntry] {
        lock.lock(); defer { lock.unlock() }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return AuditLogic.decode(text)
    }

    /// Drops entries older than the retention. Rewrites the file only when something goes.
    func prune(retention: AuditRetention, now: Date = Date()) {
        lock.lock(); defer { lock.unlock() }
        guard retention != .forever, let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        let all = AuditLogic.decode(text)
        let kept = AuditLogic.kept(all, retention: retention, now: now)
        guard kept.count != all.count else { return }
        let body = kept.compactMap(AuditLogic.encodeLine).map { $0 + "\n" }.joined()
        let tmp = directory.appendingPathComponent("approvals.jsonl.tmp")
        FileManager.default.createFile(atPath: tmp.path, contents: Data(body.utf8), attributes: [.posixPermissions: 0o600])
        _ = try? FileManager.default.replaceItemAt(url, withItemAt: tmp)
    }
}
