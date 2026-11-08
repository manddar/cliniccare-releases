#!/usr/bin/env bash
# Usage: scripts/release.sh <path-to-signed.apk> [notes-file]
# Builds dist/<apk> and latest.json from the app repo's current version. Does not push or upload.
set -euo pipefail
cd "$(dirname "$0")/.."
source config.env

apk=${1:?usage: release.sh <apk> [notes-file]}
notes_file=${2:-}
[[ $OWNER != CHANGE_ME ]] || { echo "Set OWNER in config.env first" >&2; exit 1; }
[[ -f $apk ]] || { echo "APK not found: $apk" >&2; exit 1; }

line=$(grep -E '^version:' "$APP_DIR/pubspec.yaml" | head -1 | awk '{print $2}')
version=${line%%+*}
build=${line##*+}
[[ $line == *+* && $build =~ ^[0-9]+$ ]] || { echo "pubspec version must look like X.Y.Z+BUILD" >&2; exit 1; }
schema=$(grep -E 'int get schemaVersion' "$APP_DIR/lib/data/db/app_database.dart" | grep -oE '[0-9]+')

if [[ -f latest.json ]]; then
  prev=$(grep -oE '"build": *[0-9]+' latest.json | grep -oE '[0-9]+')
  (( build > prev )) || { echo "build $build is not higher than published build $prev" >&2; exit 1; }
fi

name="cliniccare-$version-$build.apk"
mkdir -p dist
cp "$apk" "dist/$name"
sha=$(sha256sum "dist/$name" | awk '{print $1}')
size=$(stat -c %s "dist/$name")
notes=""
[[ -n $notes_file ]] && notes=$(python3 -c 'import json,sys;print(json.dumps(open(sys.argv[1]).read().strip()))' "$notes_file") || notes='""'
min=$(grep -oE '"min_supported_build": *[0-9]+' latest.json 2>/dev/null | grep -oE '[0-9]+' || echo 1)

cat > latest.json <<JSON
{
  "version": "$version",
  "build": $build,
  "schema_version": $schema,
  "min_supported_build": $min,
  "apk_url": "https://github.com/$OWNER/$REPO/releases/download/v$version/$name",
  "sha256": "$sha",
  "size_bytes": $size,
  "released_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "notes": $notes
}
JSON

echo "Wrote latest.json for $version+$build (schema v$schema)."
echo
echo "Next, in this order:"
echo "  gh release create v$version dist/$name --title \"ClinicCare $version\" ${notes_file:+--notes-file $notes_file}"
echo "  git add latest.json && git commit -m \"Release $version+$build\" && git push"
