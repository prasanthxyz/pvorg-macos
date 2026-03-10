#!/usr/bin/env python3
from __future__ import annotations

import math
import subprocess
from pathlib import Path

from common import ensure_tool, load_config, parse_args, valid_video_files

FFMPEG = ensure_tool("ffmpeg")
FFPROBE = ensure_tool("ffprobe")


def duration(video: Path) -> float | None:
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


def write_vtt(vtt: Path, frame_count: int, cols: int, tile_w: int, tile_h: int, sprite_name: str, total_duration: float) -> None:
    lines = ["WEBVTT", ""]
    for i in range(frame_count):
        start = i * 2
        end = min((i + 1) * 2, total_duration)
        x = (i % cols) * tile_w
        y = (i // cols) * tile_h
        lines.append(f"{fmt(start)} --> {fmt(end)}")
        lines.append(f"{sprite_name}#xywh={x},{y},{tile_w},{tile_h}")
        lines.append("")
    vtt.write_text("\n".join(lines), encoding="utf-8")


def fmt(sec: float) -> str:
    h = int(sec // 3600)
    m = int((sec % 3600) // 60)
    s = int(sec % 60)
    ms = int((sec % 1) * 1000)
    return f"{h:02d}:{m:02d}:{s:02d}.{ms:03d}"


def generate_sprite(video: Path, sprite: Path, vtt: Path) -> bool:
    dur = duration(video)
    if not dur or dur < 1:
        return False

    cols = 10
    tile_w = 160
    frame_count = max(1, int(math.floor(dur / 2)))
    rows = max(1, math.ceil(frame_count / cols))

    cmd = [
        FFMPEG,
        "-i",
        str(video),
        "-vf",
        f"fps=1/2,scale={tile_w}:-1,tile={cols}x{rows}",
        "-frames:v",
        "1",
        "-y",
        str(sprite),
    ]

    if subprocess.run(cmd, capture_output=True).returncode != 0:
        return False

    tile_h = round(tile_w * 9 / 16)
    write_vtt(vtt, frame_count, cols, tile_w, tile_h, sprite.name, dur)
    return True


def main() -> None:
    args = parse_args("Generate sprite sheets for web compatibility")
    config = load_config(args.config)
    videos_dir = Path(config["videosPath"])
    sprite_dir = videos_dir / "sprite"
    sprite_dir.mkdir(parents=True, exist_ok=True)

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
        sprite = sprite_dir / f"{vf.name}_sprite.jpg"
        vtt = sprite_dir / f"{vf.name}_sprite.vtt"
        if sprite.exists() and vtt.exists():
            skipped_existing += 1
            continue
        if generate_sprite(vf, sprite, vtt):
            generated += 1

    print("\nSprite Report")
    print("-------------")
    print(f"Generated: {generated}")
    print(f"Skipped (existing): {skipped_existing}")
    print(f"Skipped (invalid name): {skipped_invalid}")


if __name__ == "__main__":
    main()
