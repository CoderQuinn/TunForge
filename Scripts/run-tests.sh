#!/usr/bin/env bash
# Canonical XCTest entrypoint for local runs and CI.
# Policy: see docs/TESTING.md
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE="${1:-all}"

case "$MODE" in
  all)
    FILTER=""
    LABEL="all XCTest suites"
    ;;
  unit)
    FILTER='TFGlobalSchedulerTests|TFTCPConnectionPublicAPITests|TunForgeSwiftSurfaceTests'
    LABEL="unit tests"
    ;;
  regression)
    # Keep this gate non-empty before the TCP lifecycle suites land on main.
    FILTER='TFIPStackAcceptTests|TFIPStackLifecycleTests|TunForgeLwIPRuntimeTests|TunForgeSwiftSurfaceTests'
    LABEL="regression tests"
    ;;
  *)
    # Backwards-compatible custom XCTest filter.
    FILTER="$MODE"
    LABEL="custom filter: $MODE"
    ;;
esac

echo "==> swift --version"
swift --version

echo "==> swift build"
swift build

if [[ -n "$FILTER" ]]; then
  echo "==> swift test (${LABEL})"
  echo "==> filter: ${FILTER}"
  swift test --filter "$FILTER"
else
  echo "==> swift test (${LABEL})"
  swift test
fi
