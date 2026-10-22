#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/giraffy-approval-audit.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc NotchBuddy/Sources/App/ApprovalAudit.swift \
    tests/ApprovalAuditTests.swift -o "$TEST_DIR/approval-audit-tests"
GIRAFFY_AUDIT_TEST_DIR="$TEST_DIR/audit" "$TEST_DIR/approval-audit-tests"
