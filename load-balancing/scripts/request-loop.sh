#!/usr/bin/env sh
set -eu

URL="${1:-http://localhost:8080/}"
REQUESTS="${2:-30}"
PAUSE_SECONDS="${3:-0.25}"
COUNTS_FILE="$(mktemp)"

cleanup() {
  rm -f "$COUNTS_FILE"
}
trap cleanup EXIT

i=1
while [ "$i" -le "$REQUESTS" ]; do
  started_ms="$(python -c 'import time; print(int(time.time() * 1000))')"
  body="$(curl -fsS --max-time 10 "$URL")"
  ended_ms="$(python -c 'import time; print(int(time.time() * 1000))')"

  server="$(printf '%s' "$body" | python -c 'import json, sys; print(json.load(sys.stdin)["server"])')"
  delay_ms="$(printf '%s' "$body" | python -c 'import json, sys; print(json.load(sys.stdin)["delay_ms"])')"
  client_ms=$((ended_ms - started_ms))

  printf '%2d/%s: %s backend_delay=%sms client_time=%sms\n' "$i" "$REQUESTS" "$server" "$delay_ms" "$client_ms"
  printf '%s\n' "$server" >> "$COUNTS_FILE"

  i=$((i + 1))
  sleep "$PAUSE_SECONDS"
done

printf '\nVerteilung:\n'
sort "$COUNTS_FILE" | uniq -c | awk '{ printf "%s: %s\n", $2, $1 }'
