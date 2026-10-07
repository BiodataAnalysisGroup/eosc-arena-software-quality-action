#!/usr/bin/env bash
# Turns resqui's exit code into the step result, with an annotation.
#
# Inputs (environment): EXIT_CODE, FAILED, NOT_RUN, FAIL_ON.
set -uo pipefail

case "${EXIT_CODE:-}" in
  0)
    exit 0
    ;;
  2)
    echo "::error title=Software quality checks::${FAILED:-?} failed, ${NOT_RUN:-?} not run (fail-on: ${FAIL_ON}). See the job summary for details."
    exit 2
    ;;
  *)
    echo "::error title=resqui error::resqui did not complete (exit code ${EXIT_CODE:-unknown}). See the 'Run resqui' step log."
    exit 1
    ;;
esac
