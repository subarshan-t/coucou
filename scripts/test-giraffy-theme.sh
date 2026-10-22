#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/giraffy-theme.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc NotchBuddy/Sources/CoucouKit/GiraffyTheme.swift NotchBuddy/Sources/CoucouKit/ColorHex.swift \
    tests/GiraffyThemeTests.swift -o "$TEST_DIR/giraffy-theme-tests"
"$TEST_DIR/giraffy-theme-tests"
