#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/coucou-agent-session-board.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc NotchBuddy/Sources/App/AgentSessionBoard.swift \
    tests/AgentSessionBoardTests.swift -o "$TEST_DIR/agent-session-board-tests"
"$TEST_DIR/agent-session-board-tests"
