#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
from pathlib import Path

from common import ensure_tool, load_config, parse_args, valid_video_files

FFMPEG = ensure_tool("ffmpeg")
FFPROBE = ensure_tool("ffprobe")


def video_duration(video: Path) -> float | None:
    cmd = [
        FFPROBE,
        "-v",
        "error",
        "-select_streams",
        "v:0",
        "-show_entries",
        "stream=duration",
        "-of",
        "default=noprint_wrappers=1:nokey=1",
        str(video),
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    try:
        return float(res.stdout.strip())
    except ValueError:
        return None


def generate_tgp(video: Path, out: Path) -> bool:
    dur = video_duration(video)
    if not dur or dur < 1:
        return False

    cols = 4
    rows = 4
    tiles = cols * rows
    interval = dur / tiles
    offset = interval / 2

    args: list[str] = []
    labels: list[str] = []
    layout: list[str] = []

    for i in range(tiles):
        ts = offset + i * interval
        args += ["-ss", f"{ts:.2f}", "-i", str(video)]
        labels.append(f"[{i}:v]")

        c = i % cols
        r = i // cols
        x = "+".join(["w0"] * c) if c else "0"
        y = "+".join(["h0"] * r) if r else "0"
        layout.append(f"{x}_{y}")

    filter_complex = (
        f"{''.join(labels)}xstack=inputs={tiles}:layout={'|'.join(layout)}[v];"
        f"[v]scale={cols * 480}:-1[scaled]"
    )

    out.parent.mkdir(parents=True, exist_ok=True)
    cmd = [FFMPEG] + args + [
        "-frames:v",
        "1",
        "-y",
        "-filter_complex",
        filter_complex,
        "-map",
        "[scaled]",
        str(out),
    ]
    return subprocess.run(cmd, capture_output=True).returncode == 0


def main() -> None:
    args = parse_args("Generate TGP contact sheets")
    config = load_config(args.config)
    videos_dir = Path(config["videosPath"])
    img_dir = videos_dir / "img"

    if not videos_dir.is_dir():
        print(f"Videos directory not found: {videos_dir}")
        raise SystemExit(1)

    videos = valid_video_files(videos_dir)
    generated = 0
    skipped_existing = 0
    skipped_invalid = 0

    total_all = sorted(videos_dir.iterdir())
    for p in total_all:
        if p.is_file() and p.suffix.lower() in {".mp4", ".mkv", ".avi", ".mov", ".wmv", ".webm"}:
            if p not in videos:
                skipped_invalid += 1

    for vf in videos:
        out = img_dir / f"{vf.name}.jpg"
        if out.exists():
            skipped_existing += 1
            continue
        if generate_tgp(vf, out):
            generated += 1

    print("\nTGP Report")
    print("----------")
    print(f"Generated: {generated}")
    print(f"Skipped (existing): {skipped_existing}")
    print(f"Skipped (invalid name): {skipped_invalid}")


if __name__ == "__main__":
    main()
