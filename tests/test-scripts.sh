#!/usr/bin/env bash
# Tests for scripts/run-resqui.sh and scripts/check-result.sh, using a stub
# resqui so they run in seconds without Docker or network access.
#
#   bash tests/test-scripts.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
failures=0

assert_eq() {
  if [[ "$2" != "$3" ]]; then
    echo "FAIL: $1: expected [$3], got [$2]"
    failures=$((failures + 1))
  else
    echo "ok: $1"
  fi
}

output() {  # output <file> <key>: value of key=... in a GITHUB_OUTPUT file
  grep -E "^$2=" "$1" | tail -1 | cut -d= -f2-
}

# A stub resqui: records its arguments, writes reports according to
# STUB_OUTCOMES (space separated, e.g. "pass fail not_run") and exits with
# STUB_EXIT. With STUB_NO_REPORT=1 it writes nothing, like a fatal error.
cat > "$WORK/resqui" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$STUB_ARGS"
out=""; md=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) out="$2"; shift ;;
    --md) md="$2"; shift ;;
  esac
  shift
done
if [[ -z "${STUB_NO_REPORT:-}" ]]; then
  python3 -c '
import json, sys
outcomes = sys.argv[2].split()
json.dump({"checks": [{"outcome": o} for o in outcomes]}, open(sys.argv[1], "w"))
' "$out" "${STUB_OUTCOMES:-}"
  echo "# report" > "$md"
fi
exit "${STUB_EXIT:-0}"
EOF
chmod +x "$WORK/resqui"

run_case() {  # run_case <name>; uses STUB_* and RESQUI_* from the caller
  export GITHUB_OUTPUT="$WORK/$1.out" STUB_ARGS="$WORK/$1.args"
  export RESQUI_BIN="$WORK/resqui" RESQUI_OUTPUT_DIR="$WORK/$1-report"
  : > "$GITHUB_OUTPUT"
  bash "$ROOT/scripts/run-resqui.sh" > /dev/null
  assert_eq "$1: step itself succeeds" "$?" "0"
}

echo "--- run-resqui.sh"

RESQUI_CONFIG=cfg.json RESQUI_GITHUB_TOKEN=tok RESQUI_FAIL_ON=fail,not_run \
  STUB_OUTCOMES="pass pass fail not_run" STUB_EXIT=2 run_case gate
assert_eq "gate: exit code" "$(output "$WORK/gate.out" exit-code)" "2"
assert_eq "gate: passed" "$(output "$WORK/gate.out" passed)" "2"
assert_eq "gate: failed" "$(output "$WORK/gate.out" failed)" "1"
assert_eq "gate: not-run" "$(output "$WORK/gate.out" not-run)" "1"
assert_eq "gate: json path" "$(output "$WORK/gate.out" report-json)" "$WORK/gate-report/resqui_summary.json"
assert_eq "gate: markdown path" "$(output "$WORK/gate.out" report-markdown)" "$WORK/gate-report/resqui_summary.md"
assert_eq "gate: arguments" "$(tr '\n' ' ' < "$WORK/gate.args")" \
  "-c cfg.json -o $WORK/gate-report/resqui_summary.json --md $WORK/gate-report/resqui_summary.md -t tok --fail-on fail,not_run "

RESQUI_CONFIG=cfg.json RESQUI_GITHUB_TOKEN='' RESQUI_FAIL_ON='' \
  STUB_OUTCOMES="pass" STUB_EXIT=0 run_case plain
assert_eq "plain: no token or fail-on passed" "$(tr '\n' ' ' < "$WORK/plain.args")" \
  "-c cfg.json -o $WORK/plain-report/resqui_summary.json --md $WORK/plain-report/resqui_summary.md "
assert_eq "plain: exit code" "$(output "$WORK/plain.out" exit-code)" "0"

RESQUI_CONFIG=cfg.json RESQUI_GITHUB_TOKEN='' RESQUI_FAIL_ON='' \
  STUB_NO_REPORT=1 STUB_EXIT=1 run_case fatal
assert_eq "fatal: exit code" "$(output "$WORK/fatal.out" exit-code)" "1"
assert_eq "fatal: no report outputs" "$(grep -cE '^(report-|passed)' "$WORK/fatal.out")" "0"

echo "--- check-result.sh"

check() {  # check <exit-code>; prints "<status>|<stdout>"
  local out
  out="$(EXIT_CODE="$1" FAILED=1 NOT_RUN=2 FAIL_ON=fail,not_run bash "$ROOT/scripts/check-result.sh")"
  echo "$?|$out"
}

assert_eq "0 passes silently" "$(check 0)" "0|"
assert_eq "2 fails with a quality annotation" "$(check 2)" \
  "2|::error title=Software quality checks::1 failed, 2 not run (fail-on: fail,not_run). See the job summary for details."
assert_eq "1 fails with an error annotation" "$(check 1)" \
  "1|::error title=resqui error::resqui did not complete (exit code 1). See the 'Run resqui' step log."
assert_eq "missing exit code fails" "$(check "" | cut -d'|' -f1)" "1"

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
