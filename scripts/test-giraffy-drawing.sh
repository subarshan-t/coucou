#!/usr/bin/env bash
# Draws Giraffy in every pose off screen. GIRAFFY_RENDER_DIR=<dir> also saves the PNGs.
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/giraffy-drawing.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -swift-version 6 -strict-concurrency=complete \
    NotchBuddy/Sources/CoucouKit/GiraffyDrawing.swift NotchBuddy/Sources/CoucouKit/GiraffyTheme.swift \
    NotchBuddy/Sources/CoucouKit/ColorHex.swift \
    tests/GiraffyDrawingTests.swift -o "$TEST_DIR/giraffy-drawing-tests"
"$TEST_DIR/giraffy-drawing-tests"
