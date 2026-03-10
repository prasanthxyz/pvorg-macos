#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

from common import iter_video_files, load_config, parse_args, validate_filename


def main() -> None:
    args = parse_args("Validate video filenames")
    config = load_config(args.config)
    videos_dir = Path(config["videosPath"])

    if not videos_dir.is_dir():
        print(f"Videos directory not found: {videos_dir}")
        raise SystemExit(1)

    valid = 0
    invalid = 0

    for vf in iter_video_files(videos_dir):
        ok, reasons = validate_filename(vf.name)
        if ok:
            valid += 1
        else:
            invalid += 1
            print(f"INVALID: {vf.name} ({', '.join(reasons)})")

    print("\nValidation Report")
    print("-----------------")
    print(f"Valid:   {valid}")
    print(f"Invalid: {invalid}")


if __name__ == "__main__":
    main()
