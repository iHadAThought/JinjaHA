#!/usr/bin/env bash
# Fails if Docs/COMPAT.md "Last reviewed" is older than COMPAT_MAX_AGE_DAYS (default 90).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPAT="${ROOT}/Docs/COMPAT.md"
MAX_AGE_DAYS="${COMPAT_MAX_AGE_DAYS:-90}"

if [[ ! -f "$COMPAT" ]]; then
  echo "error: missing $COMPAT" >&2
  exit 1
fi

line="$(grep -E '^\| Last reviewed \|' "$COMPAT" | head -n1 || true)"
if [[ -z "$line" ]]; then
  echo "error: Docs/COMPAT.md has no '| Last reviewed |' row" >&2
  exit 1
fi

# Extract YYYY-MM-DD from the table cell.
date_str="$(printf '%s\n' "$line" | grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -n1 || true)"
if [[ -z "$date_str" ]]; then
  echo "error: could not parse Last reviewed date from: $line" >&2
  exit 1
fi

# Portable epoch seconds (GNU date and BSD date).
if reviewed_epoch="$(date -j -f '%Y-%m-%d' "$date_str" '+%s' 2>/dev/null)"; then
  :
elif reviewed_epoch="$(date -d "$date_str" '+%s' 2>/dev/null)"; then
  :
else
  echo "error: unable to parse date '$date_str' with system date(1)" >&2
  exit 1
fi

now_epoch="$(date '+%s')"
age_days=$(( (now_epoch - reviewed_epoch) / 86400 ))

if (( age_days < 0 )); then
  echo "error: Last reviewed date $date_str is in the future" >&2
  exit 1
fi

if (( age_days > MAX_AGE_DAYS )); then
  echo "error: Docs/COMPAT.md Last reviewed ($date_str) is ${age_days}d old (max ${MAX_AGE_DAYS}d)" >&2
  echo "Re-check Pallets Jinja + HA template docs, then update the Last reviewed cell." >&2
  exit 1
fi

echo "ok: COMPAT Last reviewed $date_str (${age_days}d old, max ${MAX_AGE_DAYS}d)"
