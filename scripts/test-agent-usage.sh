#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/giraffy-agent-usage.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc NotchBuddy/Sources/App/AgentUsage.swift \
    tests/AgentUsageTests.swift -o "$TEST_DIR/agent-usage-tests"
GIRAFFY_USAGE_TEST_HOME="$TEST_DIR/home" "$TEST_DIR/agent-usage-tests"
