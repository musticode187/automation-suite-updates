#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO="${REPO:-musticode187/automation-suite-updates}"
TAG="${TAG:-suite-$(date '+%Y.%m.%d-%H%M')}"
ASSETS_DIR="$ROOT_DIR/release_assets"

latest_zip(){
  local dir="$1"
  local pattern="$2"
  find "$dir" -maxdepth 1 -type f -name "$pattern" -print0 \
    | xargs -0 ls -t 2>/dev/null \
    | head -n 1
}

BEILAGEN_ZIP="${BEILAGEN_ZIP:-$(latest_zip /Users/mustafakazhai/Downloads/beilagen-video-automation/dist 'beilagen-video-automation_portable_*.zip')}"
PRODUKTCLIPS_ZIP="${PRODUKTCLIPS_ZIP:-$(latest_zip /Users/mustafakazhai/Downloads/produktclips-native-automation/dist 'produktclips-native-automation_portable_*.zip')}"
NEWSLETTER_ZIP="${NEWSLETTER_ZIP:-$(latest_zip /Users/mustafakazhai/Downloads/newsletter-grafiken-automation/dist 'newsletter-grafiken-automation_portable_*.zip')}"

for file in "$BEILAGEN_ZIP" "$PRODUKTCLIPS_ZIP" "$NEWSLETTER_ZIP"; do
  if [ ! -f "$file" ]; then
    echo "Package not found: $file" >&2
    exit 1
  fi
done

rm -rf "$ASSETS_DIR"
mkdir -p "$ASSETS_DIR"
cp "$BEILAGEN_ZIP" "$ASSETS_DIR/beilagen-video_latest.zip"
cp "$PRODUKTCLIPS_ZIP" "$ASSETS_DIR/produktclips_latest.zip"
cp "$NEWSLETTER_ZIP" "$ASSETS_DIR/newsletter-grafiken_latest.zip"

python3 "$ROOT_DIR/scripts/build_version_manifest.py" \
  --repo "$REPO" \
  --tag "$TAG" \
  --output "$ASSETS_DIR/version.json" \
  "beilagen-video:beilagen-video_latest.zip:$ASSETS_DIR/beilagen-video_latest.zip" \
  "produktclips:produktclips_latest.zip:$ASSETS_DIR/produktclips_latest.zip" \
  "newsletter-grafiken:newsletter-grafiken_latest.zip:$ASSETS_DIR/newsletter-grafiken_latest.zip"

(
  cd "$ASSETS_DIR"
  shasum -a 256 *.zip > checksums.sha256
)

NOTES="$ASSETS_DIR/release_notes.md"
{
  echo "# Automation Suite Update $TAG"
  echo
  echo "Public update package for external users."
  echo
  echo "## Assets"
  echo
  python3 - "$ASSETS_DIR/version.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
for module_id, module in data["modules"].items():
    mb = module["size_bytes"] / 1024 / 1024
    print(f"- {module['label']}: `{module['asset_name']}` ({mb:.1f} MB)")
PY
} > "$NOTES"

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release upload "$TAG" "$ASSETS_DIR/version.json" "$ASSETS_DIR/checksums.sha256" "$ASSETS_DIR/"*.zip --repo "$REPO" --clobber
  gh release edit "$TAG" --repo "$REPO" --title "Automation Suite Update $TAG" --notes-file "$NOTES" --latest
else
  gh release create "$TAG" "$ASSETS_DIR/version.json" "$ASSETS_DIR/checksums.sha256" "$ASSETS_DIR/"*.zip \
    --repo "$REPO" \
    --title "Automation Suite Update $TAG" \
    --notes-file "$NOTES" \
    --latest
fi

echo "Published: https://github.com/$REPO/releases/tag/$TAG"
echo "Manifest: https://github.com/$REPO/releases/latest/download/version.json"

