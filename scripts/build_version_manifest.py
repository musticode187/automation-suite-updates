#!/usr/bin/env python3
import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path


LABELS = {
    "beilagen-video": "Beilagen-Video",
    "produktclips": "Produktclips",
    "newsletter-grafiken": "Newsletter-Grafiken",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_module(value: str):
    parts = value.split(":", 3)
    if len(parts) != 3:
        raise argparse.ArgumentTypeError(
            "module must use module_id:asset_name:/absolute/path/to/package.zip"
        )
    module_id, asset_name, zip_path = parts
    path = Path(zip_path).expanduser()
    if not path.exists():
        raise argparse.ArgumentTypeError(f"package not found: {path}")
    return module_id, asset_name, path


def download_url(repo: str, asset_name: str) -> str:
    return f"https://github.com/{repo}/releases/latest/download/{asset_name}"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default="musticode187/automation-suite-updates")
    parser.add_argument("--tag", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("modules", nargs="+", type=parse_module)
    args = parser.parse_args()

    modules = {}
    for module_id, asset_name, package_path in args.modules:
        modules[module_id] = {
            "label": LABELS.get(module_id, module_id),
            "version": args.tag,
            "asset_name": asset_name,
            "url": download_url(args.repo, asset_name),
            "sha256": sha256(package_path),
            "size_bytes": package_path.stat().st_size,
            "source_package": package_path.name,
        }

    payload = {
        "schema": "automation.update_feed.v1",
        "suite": "automation-suite",
        "repo": args.repo,
        "release_tag": args.tag,
        "published_at": dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z"),
        "manifest_url": download_url(args.repo, "version.json"),
        "modules": modules,
    }

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

