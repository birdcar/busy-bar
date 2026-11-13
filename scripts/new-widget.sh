#!/usr/bin/env bash
# Scaffolds a BUSY Bar widget (a Python program that drives the bar over its HTTP API)
# in widgets/<slug> as a standalone uv project.
#
#   scripts/new-widget.sh <slug>
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: scripts/new-widget.sh <slug>" >&2
  exit 2
fi

slug="$1"

if [[ ! "$slug" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
  echo "slug must be lowercase letters, digits, _ or -: $slug" >&2
  exit 2
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
widget_dir="$root/widgets/$slug"

if [[ -e "$widget_dir" ]]; then
  echo "widgets/$slug already exists" >&2
  exit 1
fi

uv init --app --vcs none --no-workspace "$widget_dir"
cd "$widget_dir"
uv add busylib
uv add --dev pytest ty

echo
echo "Created widgets/$slug. Next: cd widgets/$slug && uv run main.py"
