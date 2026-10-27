import Foundation

@main
enum AgentUsageTests {
    static func main() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let since = AgentUsage.parseDate("2026-10-16T00:00:00Z")!

        // Claude Code transcript: a streamed reply written twice counts once; user lines and
        // replies older than the window are ignored; days are split.
        let claude = """
        {"type":"user","message":{"role":"user","content":"hi"},"timestamp":"2026-10-21T09:00:00.000Z"}
        {"type":"assistant","requestId":"req_1","timestamp":"2026-10-21T09:00:01.500Z","message":{"id":"msg_1","usage":{"input_tokens":10,"output_tokens":5,"cache_read_input_tokens":100,"cache_creation_input_tokens":20}}}
        {"type":"assistant","requestId":"req_1","timestamp":"2026-10-21T09:00:02.000Z","message":{"id":"msg_1","usage":{"input_tokens":10,"output_tokens":5,"cache_read_input_tokens":100,"cache_creation_input_tokens":20}}}
        {"type":"assistant","requestId":"req_2","timestamp":"2026-10-22T10:00:00Z","message":{"id":"msg_2","usage":{"input_tokens":1,"output_tokens":2,"cache_read_input_tokens":3,"cache_creation_input_tokens":4}}}
        {"type":"assistant","requestId":"req_0","timestamp":"2026-10-01T10:00:00Z","message":{"id":"msg_0","usage":{"input_tokens":999,"output_tokens":999}}}
        not json at all
        """
        let c = AgentUsage.claudeTranscript(claude, since: since, calendar: utc)
        precondition(c.days["2026-10-21"] == TokenTotals(input: 10, output: 5, cacheRead: 100, cacheWrite: 20), "\(c.days)")
        precondition(c.days["2026-10-22"]?.total == 10)
        precondition(c.days["2026-10-01"] == nil)

        // Claude status line limits
        let limits = AgentUsage.claudeLimits(["five_hour": ["used_percentage": 42, "resets_at": 1_800_000_000],
                                              "seven_day": ["used_percentage": 120.5, "resets_at": 1_800_100_000]], now: since)
        precondition(limits?.fiveHour?.usedPct == 42 && limits?.weekly?.usedPct == 100)
        precondition(AgentUsage.claudeLimits([:], now: since) == nil)

        // Codex rollout: tokens from last_token_usage (cached split out of input), newest limits
        let codex = """
        {"timestamp":"2026-10-21T08:00:00Z","type":"event_msg","payload":{"type":"token_count","info":null,"rate_limits":{"primary":{"used_percent":10.0,"window_minutes":300,"resets_in_seconds":600},"secondary":{"used_percent":3.0,"window_minutes":10080,"resets_in_seconds":86400}}}}
        {"timestamp":"2026-10-21T08:01:00Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":500,"cached_input_tokens":300,"output_tokens":50},"last_token_usage":{"input_tokens":500,"cached_input_tokens":300,"output_tokens":50}},"rate_limits":{"primary":{"used_percent":12.0,"window_minutes":300,"resets_at":1800000000}}}}
        {"timestamp":"2026-10-21T08:02:00Z","type":"response_item","payload":{"type":"message"}}
        """
        let x = AgentUsage.codexRollout(codex, since: since, calendar: utc)
        precondition(x.days["2026-10-21"] == TokenTotals(input: 200, output: 50, cacheRead: 300, cacheWrite: 0), "\(x.days)")
        precondition(x.limits?.fiveHour?.usedPct == 12, "newest limits win")
        precondition(AgentUsage.codexLimits(["secondary": ["used_percent": 7.0, "window_minutes": 10080, "resets_at": 1_800_000_000]],
                                            at: since)?.weekly?.usedPct == 7)

        // Merge sums days and keeps the newest limits
        let m = AgentUsage.merge([c, x])
        precondition(m.days["2026-10-21"]?.total == 135 + 550)
        precondition(m.limits?.fiveHour?.usedPct == 12)

        // JWT email (payload only)
        let payload = Data(#"{"email":"suba@example.com","sub":"x"}"#.utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "").replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        precondition(AgentUsage.jwtEmail("eyJhbGciOiJub25lIn0.\(payload).sig") == "suba@example.com")
        precondition(AgentUsage.jwtEmail("garbage") == nil)

        // Accounts in a home folder: default Claude, a second CLAUDE_CONFIG_DIR, one Codex
        let home = URL(fileURLWithPath: ProcessInfo.processInfo.environment["GIRAFFY_USAGE_TEST_HOME"]
                       ?? NSTemporaryDirectory() + "giraffy-usage-\(UUID().uuidString)")
        let fm = FileManager.default
        func write(_ path: String, _ text: String) {
            let url = home.appendingPathComponent(path)
            try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
        write(".claude/projects/site/s1.jsonl", claude)
        write(".claude.json", #"{"oauthAccount":{"emailAddress":"me@personal.com"}}"#)
        write(".claude-pg/projects/app/s2.jsonl", claude)
        write(".claude-pg/.claude.json", #"{"oauthAccount":{"emailAddress":"suba@purplegiraffe.com.au"}}"#)
        write(".claude-empty/settings.json", "{}")   // no sessions: not an account
        write(".codex/sessions/2026/10/21/rollout-a.jsonl", codex)
        write(".codex/auth.json", #"{"tokens":{"id_token":"h.\#(payload).s"}}"#)

        let accounts = AgentUsage.claudeAccounts(home: home)
        precondition(accounts.map(\.label) == ["me@personal.com", "suba@purplegiraffe.com.au"], "\(accounts.map(\.label))")
        let codexAccounts = AgentUsage.codexAccounts(home: home)
        precondition(codexAccounts.count == 1 && codexAccounts[0].label == "suba@example.com")

        // Which account a status line belongs to
        let pg = home.appendingPathComponent(".claude-pg").path
        precondition(AgentUsage.claudeAccount(configDir: pg, transcriptPath: "", accounts: accounts)?.label == "suba@purplegiraffe.com.au")
        precondition(AgentUsage.claudeAccount(configDir: "", transcriptPath: pg + "/projects/app/s2.jsonl", accounts: accounts)?.label
                     == "suba@purplegiraffe.com.au")
        precondition(AgentUsage.claudeAccount(configDir: "", transcriptPath: "", accounts: accounts)?.label == "me@personal.com")

        // Session files: only .jsonl, only recent
        let files = AgentUsage.sessionFiles(under: home.appendingPathComponent(".claude/projects"), since: Date().addingTimeInterval(-3600))
        precondition(files.count == 1)
        precondition(AgentUsage.sessionFiles(under: home.appendingPathComponent(".claude/projects"), since: Date().addingTimeInterval(3600)).isEmpty)

        print("Agent usage: transcripts, rollouts, limits, accounts and files checks passed")
    }
}
