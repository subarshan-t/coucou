import Foundation

@main
enum ApprovalAuditTests {
    static func entry(_ daysAgo: Double, agent: String = "Claude Code", decision: AuditDecision = .allow,
                      target: String = "npm test", now: Date) -> AuditEntry {
        AuditEntry(timestamp: now.addingTimeInterval(-daysAgo * 86_400), agent: agent, project: "site",
                   tool: "Bash", target: target, decision: decision, via: .notch)
    }

    static func redacted(_ s: String) -> Bool { AuditRedactor.redact(s).contains(AuditRedactor.mask) }

    static func main() {
        // Secrets that look like keys or tokens never reach the file
        let secrets = [
            "export ANTHROPIC_API_KEY=sk-ant-api03-abcdefghijklmnopqrstuvwx",
            "curl -H 'Authorization: Bearer abcdef1234567890' https://api.example.com",
            "git push https://bob:hunter2pass@github.com/acme/site.git",
            "echo ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123",
            "aws configure set aws_access_key_id AKIAABCDEFGHIJKLMNOP",
            "mysql -u root --password hunter2pass",
            #"{"token": "abcdef1234"}"#,
            "STRIPE_SECRET=sk_live_abcdefghijklmnop node app.js",
            "deploy --jwt eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U",
            "echo 3f8a9c0e1b2d4f6a8c0e2b4d6f8a0c2e4b6d8f0a1c3e",
        ]
        for s in secrets { precondition(redacted(s), "not redacted: \(s)") }
        // …and the secret itself is gone, not just tagged
        precondition(!AuditRedactor.redact(secrets[0]).contains("abcdefghijklmnop"))
        precondition(!AuditRedactor.redact(secrets[2]).contains("hunter2pass"))
        precondition(AuditRedactor.redact(secrets[5]).hasPrefix("mysql -u root --password "))

        // Ordinary commands and paths stay readable
        let plain = [
            "npm test", "python tokenizer.py", "cat docs/secrets.md", "git commit -m \"Fix login\"",
            "ls /Users/me/Projects/purple-giraffe/website/src/components/navigation",
            "rm -rf build", "swift build -c release",
        ]
        for s in plain { precondition(AuditRedactor.redact(s) == s, "over-redacted: \(s)") }

        // Retention keeps 30 / 90 days, or everything
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let all = [entry(1, now: now), entry(40, now: now), entry(120, now: now)]
        precondition(AuditLogic.kept(all, retention: .days30, now: now).count == 1)
        precondition(AuditLogic.kept(all, retention: .days90, now: now).count == 2)
        precondition(AuditLogic.kept(all, retention: .forever, now: now).count == 3)

        // Filters by agent and decision
        let mixed = [entry(1, agent: "Claude Code", decision: .allow, now: now),
                     entry(1, agent: "Codex", decision: .deny, now: now),
                     entry(1, agent: "Codex", decision: .timeout, now: now)]
        precondition(AuditLogic.filtered(mixed, agent: "Codex", decision: nil).count == 2)
        precondition(AuditLogic.filtered(mixed, agent: nil, decision: .deny).count == 1)
        precondition(AuditLogic.filtered(mixed, agent: "Claude Code", decision: .deny).isEmpty)
        precondition(AuditLogic.filtered(mixed, agent: nil, decision: nil).count == 3)

        // CSV: header, quoting, and a command can't run as a spreadsheet formula
        let csv = AuditLogic.csv([entry(0, target: "=HYPERLINK(\"x\")", now: now),
                                  entry(0, target: "echo \"a,b\"", now: now)])
        let lines = csv.split(separator: "\n")
        precondition(lines.count == 3)
        precondition(lines[0] == "timestamp,agent,project,tool,command_or_file,decision,decided_in")
        precondition(lines[1].contains(#""'=HYPERLINK(""x"")""#))
        precondition(lines[2].contains(#""echo ""a,b""""#))
        precondition(lines[1].hasSuffix(#""allow","notch""#))

        // JSON Lines round trip; a broken line (crash mid-write) is skipped, not fatal
        let e = entry(0, now: now)
        guard let line = AuditLogic.encodeLine(e) else { preconditionFailure("encode") }
        precondition(!line.contains("\n"))
        let decoded = AuditLogic.decode(line + "\n{not json\n" + line + "\n")
        precondition(decoded.count == 2 && decoded[0] == e)

        // The file: private folder and file, append-only, prune drops old entries
        let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["GIRAFFY_AUDIT_TEST_DIR"]
                      ?? NSTemporaryDirectory() + "giraffy-audit-\(UUID().uuidString)")
        let file = AuditFile(directory: dir)
        do {
            try file.append(entry(120, now: Date()))
            let afterOne = try String(contentsOf: file.url, encoding: .utf8)
            try file.append(entry(1, now: Date()))
            let afterTwo = try String(contentsOf: file.url, encoding: .utf8)
            precondition(afterTwo.hasPrefix(afterOne), "appending must not rewrite earlier lines")
            precondition(file.readAll().count == 2)
            let dirMode = (try FileManager.default.attributesOfItem(atPath: dir.path)[.posixPermissions] as? NSNumber)?.intValue
            let fileMode = (try FileManager.default.attributesOfItem(atPath: file.url.path)[.posixPermissions] as? NSNumber)?.intValue
            precondition(dirMode == 0o700, "folder mode \(String(dirMode ?? 0, radix: 8))")
            precondition(fileMode == 0o600, "file mode \(String(fileMode ?? 0, radix: 8))")
            file.prune(retention: .days90)
            precondition(file.readAll().count == 1)
            file.prune(retention: .forever)
            precondition(file.readAll().count == 1)
        } catch {
            preconditionFailure("file: \(error)")
        }

        print("Approval audit: redaction, retention, filters, CSV, JSON Lines and file checks passed")
    }
}
