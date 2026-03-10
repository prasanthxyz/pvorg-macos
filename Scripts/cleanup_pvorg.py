#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

from common import load_config, parse_args, save_config


def main() -> None:
    args = parse_args("Remove stale videoRelations entries")
    config = load_config(args.config)
    videos_dir = Path(config["videosPath"])

    if not videos_dir.is_dir():
        print(f"Videos directory not found: {videos_dir}")
        raise SystemExit(1)

    relations = config.get("videoRelations", {})
    stale = [name for name in list(relations.keys()) if not (videos_dir / name).is_file()]

    for key in stale:
        relations.pop(key, None)
        print(f"Removed stale entry: {key}")

    if stale:
        save_config(args.config, config)

    print("\nCleanup Report")
    print("--------------")
    print(f"Stale config entries removed: {len(stale)}")


if __name__ == "__main__":
    main()
