# Automation Suite Updates

Public release feed for external users of the automation apps.

This repository intentionally contains no source code and no customer assets.
It only publishes signed-off ZIP packages through GitHub Releases, so external
Macs can download updates without GitHub accounts, private-repo access, Git,
Python, Homebrew or Xcode.

## Latest Download URLs

These URLs always point to the newest GitHub Release:

- Manifest: `https://github.com/musticode187/automation-suite-updates/releases/latest/download/version.json`
- Beilagen-Video: `https://github.com/musticode187/automation-suite-updates/releases/latest/download/beilagen-video_latest.zip`
- Produktclips: `https://github.com/musticode187/automation-suite-updates/releases/latest/download/produktclips_latest.zip`
- Newsletter-Grafiken: `https://github.com/musticode187/automation-suite-updates/releases/latest/download/newsletter-grafiken_latest.zip`

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
  produktclips-native-automation/
  newsletter-grafiken-automation/
```

The script expects current portable ZIPs in the sibling private working
checkouts under `../<repo>/dist/`. If your local layout is different, set
`REPOS_BASE` or pass explicit ZIP paths:

```bash
REPOS_BASE="$HOME/Documents/GitHub" ./scripts/publish_release.sh
BEILAGEN_ZIP="/path/to/beilagen.zip" ./scripts/publish_release.sh
```

It copies the newest portable package for each module into stable asset names,
generates `version.json` with SHA-256 checksums, and creates or updates the
latest GitHub Release.

## Security Model

- Private development stays in the private working repositories.
- External users only receive packaged ZIP files.
- SHA-256 checksums in `version.json` protect against incomplete or wrong
  downloads.
- No GitHub token is embedded in any shipped app.
