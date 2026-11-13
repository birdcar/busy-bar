#!/usr/bin/env bash
# Scaffolds a BUSY Bar JS app in apps/<slug> with the monorepo adjustments applied.
#
#   scripts/new-app.sh <slug> "<Display Name>" "<one-line description>" [api-version]
set -euo pipefail

ID_PREFIX="io.github.birdcar"
MAX_ID_LENGTH=32
MAX_NAME_LENGTH=32
DEFAULT_API_VERSION="27.12.0"

if [[ $# -lt 3 || $# -gt 4 ]]; then
  echo "usage: scripts/new-app.sh <slug> \"<Display Name>\" \"<one-line description>\" [api-version]" >&2
  exit 2
fi

slug="$1"
name="$2"
description="$3"
api_version="${4:-$DEFAULT_API_VERSION}"
id="$ID_PREFIX.$slug"

if [[ ! "$slug" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
  echo "slug must be lowercase letters, digits, _ or -: $slug" >&2
  exit 2
fi
if (( ${#id} > MAX_ID_LENGTH )); then
  echo "app id $id is ${#id} characters; the bar allows $MAX_ID_LENGTH. Shorten the slug." >&2
  exit 2
fi
if (( ${#name} > MAX_NAME_LENGTH )); then
  echo "display name is ${#name} characters; the catalog allows $MAX_NAME_LENGTH." >&2
  exit 2
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="$root/apps/$slug"

if [[ -e "$app_dir" ]]; then
  echo "apps/$slug already exists" >&2
  exit 1
fi

cd "$root/apps"
npm create @busy-app/app@latest "$slug" -- \
  --author "$(git config user.name)" \
  --id "$id" \
  --name "$name" \
  --description "$description" \
  --api-version "$api_version" \
  --no-git

# GitHub only runs workflows from the repository root; the root CI covers every app.
rm -rf "$app_dir/.github"
mkdir -p "$app_dir/screenshots"

node "$root/scripts/normalize-lock.mjs" "$app_dir/package-lock.json"

echo
echo "Created apps/$slug ($id). Next: cd apps/$slug && npm run build"
