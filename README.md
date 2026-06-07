# Automation Suite Updates

Public release feed for external users of the automation apps.

This repository intentionally contains no source code and no customer assets.
It only publishes signed-off ZIP packages through GitHub Releases, so external
Macs can download updates without GitHub accounts, private-repo access, Git,
Python, Homebrew or Xcode.

## Latest Download URLs

These URLs always point to the newest GitHub Release:

- Manifest: `https://github.com/musticode187/automation-suite-updates/releases/latest/download/version.json`
- Beilagen-Video macOS: `https://github.com/musticode187/automation-suite-updates/releases/latest/download/beilagen-video-mac_latest.zip`
- Beilagen-Video Windows: `https://github.com/musticode187/automation-suite-updates/releases/latest/download/beilagen-video-windows_latest.zip`
- Beilagen-Video Legacy macOS: `https://github.com/musticode187/automation-suite-updates/releases/latest/download/beilagen-video_latest.zip`
- Produktclips: `https://github.com/musticode187/automation-suite-updates/releases/latest/download/produktclips_latest.zip`
- Newsletter-Grafiken: `https://github.com/musticode187/automation-suite-updates/releases/latest/download/newsletter-grafiken_latest.zip`

`beilagen-video_latest.zip` is a compatibility alias for older macOS builds. It is not the combined Mac+Windows distribution package.

The Windows URL is only live after a Windows release ZIP with `app/Beilagen-Video/Beilagen-Video.exe` has been built and published. The publish script refuses incomplete Windows ZIPs.

The app updater should read `version.json`, compare the installed module version,
download the matching ZIP, verify SHA-256, then replace the installed module
after the running app has exited.

## Release Workflow

From this local checkout:

```bash
./scripts/publish_release.sh
```

Recommended local layout:

```text
~/Documents/GitHub/
  automation-suite-updates/
  beilagen-video-automation/
  beilagen-video-windows/
  produktclips-native-automation/
  newsletter-grafiken-automation/
```

The script expects current ZIPs in the sibling private working
checkouts under `../<repo>/dist/`. If your local layout is different, set
`REPOS_BASE` or pass explicit ZIP paths:

```bash
REPOS_BASE="$HOME/Documents/Codex/work" ./scripts/publish_release.sh
MAC_BEILAGEN_ZIP="/path/to/beilagen-mac.zip" ./scripts/publish_release.sh
WINDOWS_BEILAGEN_ZIP="/path/to/beilagen-windows.zip" ./scripts/publish_release.sh
PRODUKTCLIPS_ZIP="/path/to/produktclips.zip" ./scripts/publish_release.sh
NEWSLETTER_ZIP="/path/to/newsletter.zip" ./scripts/publish_release.sh
```

It publishes Beilagen-Video as separate platform assets:

- `beilagen-video-mac_latest.zip` from `MAC_BEILAGEN_ZIP` or `beilagen-video-automation/dist/`
- `beilagen-video-windows_latest.zip` from `WINDOWS_BEILAGEN_ZIP` or `beilagen-video-windows/dist/`
- `beilagen-video_latest.zip` as a legacy macOS alias for old installed builds

By default all available modules are required. For local/internal workflows where
one or more module repos are not yet available, use:

```bash
SKIP_MISSING_ZIPS=1 ./scripts/publish_release.sh
```

This publishes only modules with a matching ZIP and omits missing modules
from the feed entry.

Use `--dry-run` to prepare `release_assets/`, generate `version.json`, and validate package structure without creating or editing a GitHub Release:

```bash
SKIP_MISSING_ZIPS=1 ./scripts/publish_release.sh --dry-run
```

## Security Model

- Private development stays in the private working repositories.
- External users only receive packaged ZIP files.
- SHA-256 checksums in `version.json` protect against incomplete or wrong
  downloads.
- No GitHub token is embedded in any shipped app.
