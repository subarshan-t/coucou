import Foundation

@main
enum AgentSessionBoardTests {

    static var failures = 0

    static func check(_ label: String, _ got: Bool) {
        if got { print("  ✓ \(label)") }
        else   { print("  ✗ \(label)"); failures += 1 }
    }

    static let grok = "agent_grok"
    static let t0 = Date(timeIntervalSince1970: 1_000_000)

    static func main() {

        print("\nOne row per session")
        do {
            var board = AgentSessionBoard()
            board.record(pill: grok, session: "a", label: "api", status: .thinking, step: "fix the tests", now: t0)
            board.record(pill: grok, session: "b", label: "web", status: .working, step: "Edit App.tsx", now: t0 + 1)
            board.record(pill: grok, session: "a", label: "api", status: .working, step: "Bash npm test", now: t0 + 2)
            let rows = board.rows(pill: grok, now: t0 + 3)
            check("two rows", rows.count == 2)
            check("both active", board.activeCount(pill: grok, now: t0 + 3) == 2)
            check("a keeps its latest step", rows.first { $0.id == "a" }?.step == "Bash npm test")
            check("other pills untouched", board.rows(pill: "agent_amp").isEmpty)
        }

        print("\nOrder: working first, in start order; stopped after, latest first")
        do {
            var board = AgentSessionBoard()
            board.record(pill: grok, session: "a", label: "a", status: .working, step: nil, now: t0)
            board.record(pill: grok, session: "b", label: "b", status: .working, step: nil, now: t0 + 1)
            board.record(pill: grok, session: "c", label: "c", status: .working, step: nil, now: t0 + 2)
            board.record(pill: grok, session: "a", label: "a", status: .finished, step: "done", now: t0 + 3)
            board.record(pill: grok, session: "c", label: "c", status: .error, step: nil, now: t0 + 4)
            // b gets a newer event: it must not jump ahead of nothing, it stays first active
            board.record(pill: grok, session: "b", label: "b", status: .working, step: "Read x", now: t0 + 5)
            let ids = board.rows(pill: grok, now: t0 + 6).map(\.id)
            check("b, then c (stopped last), then a", ids == ["b", "c", "a"])
            check("one active", board.activeCount(pill: grok, now: t0 + 6) == 1)
        }

        print("\nA new turn restarts the row's clock")
        do {
            var board = AgentSessionBoard()
            board.record(pill: grok, session: "a", label: "a", status: .working, step: nil, now: t0)
            board.record(pill: grok, session: "b", label: "b", status: .working, step: nil, now: t0 + 1)
            board.record(pill: grok, session: "a", label: "a", status: .finished, step: nil, now: t0 + 2)
            board.record(pill: grok, session: "a", label: "a", status: .thinking, step: "next", now: t0 + 3)
            check("a now starts after b", board.rows(pill: grok, now: t0 + 4).map(\.id) == ["b", "a"])
        }

        print("\nSame folder, two sessions")
        do {
            var board = AgentSessionBoard()
            board.record(pill: grok, session: "a", label: "api", status: .working, step: nil, now: t0)
            board.record(pill: grok, session: "b", label: "api", status: .working, step: nil, now: t0 + 1)
            board.record(pill: grok, session: "c", label: "api", status: .working, step: nil, now: t0 + 2)
            let labels = board.rows(pill: grok, now: t0 + 3).map(\.label)
            check("api, api 2, api 3", labels == ["api", "api 2", "api 3"])
            board.record(pill: grok, session: "b", label: "api", status: .working, step: nil, now: t0 + 4)
            check("a repeat event keeps api 2",
                  board.rows(pill: grok, now: t0 + 5).first { $0.id == "b" }?.label == "api 2")
        }

        print("\nNo label falls back to the session id")
        do {
            var board = AgentSessionBoard()
            board.record(pill: grok, session: "0123456789abcdef", label: "", status: .working, step: nil, now: t0)
            check("first 8 chars", board.rows(pill: grok, now: t0).first?.label == "01234567")
        }

        print("\nSilence and lifetime")
        do {
            var board = AgentSessionBoard()
            board.record(pill: grok, session: "a", label: "a", status: .working, step: nil, now: t0)
            board.record(pill: grok, session: "b", label: "b", status: .finished, step: nil, now: t0)
            let later = t0 + AgentSessionBoard.maxTurnSilence + 1
            check("a silent row stops counting as working", board.activeCount(pill: grok, now: later) == 0)
            let gone = t0 + AgentSessionBoard.finishedLifetime + 1
            check("b leaves after its lifetime",
                  !board.rows(pill: grok, now: gone).contains { $0.id == "b" })
            check("a working row is not dropped by the lifetime",
                  board.rows(pill: grok, now: gone).contains { $0.id == "a" })
        }

        print("\nSessionEnd removes the row")
        do {
            var board = AgentSessionBoard()
            board.record(pill: grok, session: "a", label: "a", status: .working, step: nil, now: t0)
            board.remove(pill: grok, session: "a")
            check("empty", board.rows(pill: grok, now: t0).isEmpty)
            board.remove(pill: grok, session: "zzz")
            check("removing an unknown session is harmless", board.rows(pill: grok, now: t0).isEmpty)
        }

        print("\nThe list is capped, stopped rows go first")
        do {
            var board = AgentSessionBoard()
            for i in 0..<AgentSessionBoard.maxRows {
                board.record(pill: grok, session: "s\(i)", label: "s\(i)",
                             status: i == 0 ? .finished : .working, step: nil, now: t0 + Double(i))
            }
            board.record(pill: grok, session: "new", label: "new", status: .working, step: nil, now: t0 + 100)
            let rows = board.rows(pill: grok, now: t0 + 101)
            check("capped", rows.count == AgentSessionBoard.maxRows)
            check("the stopped row went", !rows.contains { $0.id == "s0" })
            check("the new row is in", rows.contains { $0.id == "new" })
        }

        print("\nLong steps are cut")
        do {
            var board = AgentSessionBoard()
            board.record(pill: grok, session: "a", label: "a", status: .working,
                         step: String(repeating: "x", count: 500), now: t0)
            check("80 chars", board.rows(pill: grok, now: t0).first?.step.count == 80)
            board.record(pill: grok, session: "a", label: "a", status: .working, step: "", now: t0 + 1)
            check("an empty step keeps the last one", board.rows(pill: grok, now: t0 + 1).first?.step.count == 80)
        }

        print(failures == 0 ? "\nAll passed" : "\n\(failures) failed")
        exit(failures == 0 ? 0 : 1)
    }
}
