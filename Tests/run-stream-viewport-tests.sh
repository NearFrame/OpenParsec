#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/stream-viewport-tests.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
xcrun swiftc "$ROOT/OpenParsec/StreamViewport.swift" "$ROOT/Tests/StreamViewportTests.swift" -o "$WORK/tests"
"$WORK/tests"
