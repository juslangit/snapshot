#!/usr/bin/env bash
# Run every check in dev/checks and report.
#
# Two of the four need a real window: _light measures the rendered frame and
# _flow takes real photographs, and neither can be done headless. The other two
# are pure arithmetic and run with no display at all.
set -uo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"

declare -a HEADLESS=(_optics _judge _scene)
declare -a WINDOWED=(_light _flow)

failed=0
total=0

run() {
  local name="$1"; shift
  total=$((total + 1))
  printf '\n\033[1m%s\033[0m\n' "$name"
  if "$GODOT" "$@" --path . "dev/checks/$name.tscn" 2>&1 | grep -E '^  (ok|FAIL)|^[A-Z]+: ' ; then
    :
  fi
  local status=${PIPESTATUS[0]}
  if [[ $status -ne 0 ]]; then
    failed=$((failed + 1))
  fi
}

for name in "${HEADLESS[@]}"; do
  run "$name" --headless
done
for name in "${WINDOWED[@]}"; do
  run "$name" --resolution 1280x720
done

printf '\n'
if [[ $failed -eq 0 ]]; then
  printf '\033[32mall %d check suites passed\033[0m\n' "$total"
else
  printf '\033[31m%d of %d check suites FAILED\033[0m\n' "$failed" "$total"
  exit 1
fi
