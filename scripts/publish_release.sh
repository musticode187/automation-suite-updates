#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO="${REPO:-musticode187/automation-suite-updates}"
TAG="${TAG:-suite-$(date '+%Y.%m.%d-%H%M')}"
ASSETS_DIR="$ROOT_DIR/release_assets"
REPOS_BASE="${REPOS_BASE:-$(cd "$ROOT_DIR/.." && pwd)}"
SKIP_MISSING_ZIPS="${SKIP_MISSING_ZIPS:-0}"
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    *) echo "Unknown argument: $arg" >&2; echo "Usage: $0 [--dry-run]" >&2; exit 2 ;;
  esac
done

latest_zip(){
  local dir="$1"
  local pattern="$2"
  [ -d "$dir" ] || return 1
  find "$dir" -maxdepth 1 -type f -name "$pattern" -print0 | xargs -0 ls -t 2>/dev/null | head -n 1
}

zip_contains(){
  local zip="$1"
  local needle="$2"
  python3 - "$zip" "$needle" <<'PY'
import sys, zipfile
zip_path, needle = sys.argv[1], sys.argv[2]
try:
    with zipfile.ZipFile(zip_path) as z:
        ok = any(name.endswith(needle) for name in z.namelist())
except Exception:
    ok = False
raise SystemExit(0 if ok else 1)
PY
}

MAC_BEILAGEN_ZIP="${MAC_BEILAGEN_ZIP:-$(latest_zip "$REPOS_BASE/beilagen-video-automation/dist" 'beilagen-video-automation_release_*.zip' || true)}"
MAC_BEILAGEN_ZIP="${MAC_BEILAGEN_ZIP:-$(latest_zip "$REPOS_BASE/beilagen-video-automation/dist" 'beilagen-video-automation_portable_*.zip' || true)}"
WINDOWS_BEILAGEN_ZIP="${WINDOWS_BEILAGEN_ZIP:-$(latest_zip "$REPOS_BASE/beilagen-video-windows/dist" 'beilagen-video-windows_release_*.zip' || true)}"
WINDOWS_BEILAGEN_ZIP="${WINDOWS_BEILAGEN_ZIP:-$(latest_zip "$REPOS_BASE/beilagen-video-windows/dist" 'beilagen-video_latest.zip' || true)}"
PRODUKTCLIPS_ZIP="${PRODUKTCLIPS_ZIP:-$(latest_zip "$REPOS_BASE/produktclips-native-automation/dist" 'produktclips-native-automation_portable_*.zip' || true)}"
NEWSLETTER_ZIP="${NEWSLETTER_ZIP:-$(latest_zip "$REPOS_BASE/newsletter-grafiken-automation/dist" 'newsletter-grafiken-automation_portable_*.zip' || true)}"

MODULE_ARGS=()
rm -rf "$ASSETS_DIR"
mkdir -p "$ASSETS_DIR"

if [ -f "$MAC_BEILAGEN_ZIP" ]; then
  cp "$MAC_BEILAGEN_ZIP" "$ASSETS_DIR/beilagen-video-mac_latest.zip"
  cp "$MAC_BEILAGEN_ZIP" "$ASSETS_DIR/beilagen-video_latest.zip"
  MODULE_ARGS+=(
    "beilagen-video-mac:beilagen-video-mac_latest.zip:$ASSETS_DIR/beilagen-video-mac_latest.zip"
    "beilagen-video:beilagen-video_latest.zip:$ASSETS_DIR/beilagen-video_latest.zip"
  )
else
  echo "WARN: mac beilagen-package not found: ${MAC_BEILAGEN_ZIP}" >&2
  [ "$SKIP_MISSING_ZIPS" = "1" ] || exit 1
fi

if [ -f "$WINDOWS_BEILAGEN_ZIP" ] && zip_contains "$WINDOWS_BEILAGEN_ZIP" "app/Beilagen-Video/Beilagen-Video.exe"; then
  cp "$WINDOWS_BEILAGEN_ZIP" "$ASSETS_DIR/beilagen-video-windows_latest.zip"
  MODULE_ARGS+=("beilagen-video-windows:beilagen-video-windows_latest.zip:$ASSETS_DIR/beilagen-video-windows_latest.zip")
else
  echo "WARN: windows beilagen-package missing or incomplete: ${WINDOWS_BEILAGEN_ZIP}" >&2
  [ "$SKIP_MISSING_ZIPS" = "1" ] || exit 1
fi

if [ -f "$PRODUKTCLIPS_ZIP" ]; then
  cp "$PRODUKTCLIPS_ZIP" "$ASSETS_DIR/produktclips_latest.zip"
  MODULE_ARGS+=("produktclips:produktclips_latest.zip:$ASSETS_DIR/produktclips_latest.zip")
else
  echo "WARN: produktclips-package not found: ${PRODUKTCLIPS_ZIP}" >&2
  [ "$SKIP_MISSING_ZIPS" = "1" ] || exit 1
fi

if [ -f "$NEWSLETTER_ZIP" ]; then
  cp "$NEWSLETTER_ZIP" "$ASSETS_DIR/newsletter-grafiken_latest.zip"
  MODULE_ARGS+=("newsletter-grafiken:newsletter-grafiken_latest.zip:$ASSETS_DIR/newsletter-grafiken_latest.zip")
else
  echo "WARN: newsletter-package not found: ${NEWSLETTER_ZIP}" >&2
  [ "$SKIP_MISSING_ZIPS" = "1" ] || exit 1
fi

if [ "${#MODULE_ARGS[@]}" -eq 0 ]; then
  echo "No publishable module packages found." >&2
  exit 1
fi

[ "$SKIP_MISSING_ZIPS" = "1" ] && echo "Publishing subset mode: ${#MODULE_ARGS[@]} module(s)." >&2

python3 "$ROOT_DIR/scripts/build_version_manifest.py" \
  --repo "$REPO" \
  --tag "$TAG" \
  --output "$ASSETS_DIR/version.json" \
  "${MODULE_ARGS[@]}"

(cd "$ASSETS_DIR" && shasum -a 256 *.zip > checksums.sha256)

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

if [ "$DRY_RUN" = "1" ]; then
  echo "Dry run OK. Assets prepared under: $ASSETS_DIR"
  echo "Manifest: $ASSETS_DIR/version.json"
  exit 0
fi

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
