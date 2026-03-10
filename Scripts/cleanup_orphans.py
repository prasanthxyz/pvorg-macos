#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

from common import load_config, parse_args, valid_video_files


def main() -> None:
    args = parse_args("Remove orphaned TGP assets")
    config = load_config(args.config)
    videos_dir = Path(config["videosPath"])

    if not videos_dir.is_dir():
        print(f"Videos directory not found: {videos_dir}")
        raise SystemExit(1)

    valid_names = {v.name for v in valid_video_files(videos_dir)}
    img_dir = videos_dir / "img"
    removed = 0

    if img_dir.is_dir():
        for f in sorted(img_dir.iterdir()):
            if f.is_file() and f.suffix.lower() == ".jpg":
                video_name = f.stem
                if video_name not in valid_names:
                    f.unlink(missing_ok=True)
                    removed += 1
                    print(f"Removed orphan TGP: {f}")

    print("\nCleanup Report")
    print("--------------")
    print(f"Orphan assets removed: {removed}")


if __name__ == "__main__":
    main()
