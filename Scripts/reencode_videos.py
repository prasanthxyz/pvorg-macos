#!/usr/bin/env python3
from __future__ import annotations

import subprocess
from pathlib import Path

from common import ensure_tool, load_config, parse_args, valid_video_files

FFMPEG = ensure_tool("ffmpeg")


def reencode(video: Path, out: Path) -> bool:
    cmd = [
        FFMPEG,
        "-i",
        str(video),
        "-c:v",
        "libx264",
        "-preset",
        "medium",
        "-crf",
        "23",
        "-c:a",
        "aac",
        "-b:a",
        "128k",
        "-movflags",
        "+faststart",
        "-y",
        str(out),
    ]
    return subprocess.run(cmd, capture_output=True).returncode == 0


def main() -> None:
    args = parse_args("Re-encode videos for playback")
    config = load_config(args.config)
    videos_dir = Path(config["videosPath"])

    if not videos_dir.is_dir():
        print(f"Videos directory not found: {videos_dir}")
        raise SystemExit(1)

    videos = valid_video_files(videos_dir)
    reencoded = 0
    failed = 0
    skipped_invalid = 0

    total_all = sorted(videos_dir.iterdir())
    for p in total_all:
        if p.is_file() and p.suffix.lower() in {".mp4", ".mkv", ".avi", ".mov", ".wmv", ".webm"}:
            if p not in videos:
                skipped_invalid += 1

    for vf in videos:
        temp_out = vf.with_suffix(".reencoded.mp4")
        backup = vf.with_suffix(vf.suffix + ".bak")

        ok = reencode(vf, temp_out)
        if not ok:
            failed += 1
            temp_out.unlink(missing_ok=True)
            continue

        vf.rename(backup)
        temp_out.rename(vf.with_suffix(".mp4"))
        reencoded += 1

    print("\nRe-encode Report")
    print("----------------")
    print(f"Re-encoded: {reencoded}")
    print(f"Failed:     {failed}")
    print(f"Skipped (invalid name): {skipped_invalid}")


if __name__ == "__main__":
    main()
