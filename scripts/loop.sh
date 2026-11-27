#!/bin/bash
# Repeats grab.sh until a VM is launched/exists or MAX_MINUTES pass.
# Final status goes to $GITHUB_OUTPUT: launched | exists | failed (time up, retry next round) | error (stop).
set -u
MAX_MINUTES=${MAX_MINUTES:-325}
PAUSE_SECONDS=${PAUSE_SECONDS:-120}
deadline=$(( $(date +%s) + MAX_MINUTES * 60 ))
errors=0
n=0

while [ "$(date +%s)" -lt "$deadline" ]; do
  n=$((n + 1))
  echo "::group::Attempt $n ($(date -u +%H:%M) UTC)"
  out=$(mktemp)
  GITHUB_OUTPUT="$out" bash scripts/grab.sh
  status=$(grep '^status=' "$out" | tail -1 | cut -d= -f2)
  echo "::endgroup::"
  echo "attempt $n: ${status:-unknown}"

  case "$status" in
    launched|exists)
      cat "$out" >> "$GITHUB_OUTPUT"
      exit 0 ;;
    error)
      errors=$((errors + 1))
      if [ "$errors" -ge 5 ]; then
        echo "5 errors in a row - stopping (check secrets / OCI setup)."
        echo "status=error" >> "$GITHUB_OUTPUT"
        exit 1
      fi ;;
    *)
      errors=0 ;;
  esac
  rm -f "$out"
  sleep "$PAUSE_SECONDS"
done

echo "Time is up after $n attempts - next round will be started."
echo "status=failed" >> "$GITHUB_OUTPUT"
exit 0
