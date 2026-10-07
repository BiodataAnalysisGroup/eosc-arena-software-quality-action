#!/usr/bin/env bash
# Runs resqui and exposes its results as step outputs.
#
# This step never fails on its own: the job summary and artifact steps must
# still run, so the exit code is passed on and check-result.sh decides.
#
# Inputs (environment): RESQUI_BIN, RESQUI_CONFIG, RESQUI_GITHUB_TOKEN,
# RESQUI_FAIL_ON, RESQUI_OUTPUT_DIR, GITHUB_OUTPUT.
set -uo pipefail

mkdir -p "$RESQUI_OUTPUT_DIR"
json="$RESQUI_OUTPUT_DIR/resqui_summary.json"
md="$RESQUI_OUTPUT_DIR/resqui_summary.md"

args=(-c "$RESQUI_CONFIG" -o "$json" --md "$md")
if [[ -n "${RESQUI_GITHUB_TOKEN:-}" ]]; then
  args+=(-t "$RESQUI_GITHUB_TOKEN")
fi
if [[ -n "${RESQUI_FAIL_ON:-}" ]]; then
  args+=(--fail-on "$RESQUI_FAIL_ON")
fi

"$RESQUI_BIN" "${args[@]}"
code=$?
echo "exit-code=$code" >> "$GITHUB_OUTPUT"

if [[ -f "$json" ]]; then
  echo "report-json=$json" >> "$GITHUB_OUTPUT"
  python3 - "$json" >> "$GITHUB_OUTPUT" <<'EOF'
import json
import sys

checks = json.load(open(sys.argv[1])).get("checks", [])
outcomes = [check.get("outcome") for check in checks]
print(f"passed={outcomes.count('pass')}")
print(f"failed={outcomes.count('fail')}")
print(f"not-run={outcomes.count('not_run')}")
EOF
fi
if [[ -f "$md" ]]; then
  echo "report-markdown=$md" >> "$GITHUB_OUTPUT"
fi
exit 0
