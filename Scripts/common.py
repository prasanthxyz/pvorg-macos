#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path
from typing import Iterable

VIDEO_EXTENSIONS = {".mp4", ".mkv", ".avi", ".mov", ".wmv", ".webm"}
IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".bmp", ".gif"}


def parse_args(description: str) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument("--config", type=Path, default=Path.home() / "pvorg.json")
    return parser.parse_args()


def load_config(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def save_config(path: Path, config: dict) -> None:
    text = json.dumps(config, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    path.write_text(text, encoding="utf-8")


def validate_filename(filename: str) -> tuple[bool, list[str]]:
    reasons: list[str] = []
    if filename != filename.lower():
        reasons.append("uppercase characters")
    if " " in filename:
        reasons.append("spaces")

    stem = Path(filename).stem
    if len(stem.split("-")) < 3:
        reasons.append("fewer than 3 dash-separated parts (need studio-actor-title)")

    return (len(reasons) == 0, reasons)


def iter_video_files(videos_dir: Path) -> Iterable[Path]:
    for entry in sorted(videos_dir.iterdir()):
        if (
            entry.is_file()
            and not entry.name.startswith(".")
            and entry.suffix.lower() in VIDEO_EXTENSIONS
        ):
            yield entry


def valid_video_files(videos_dir: Path) -> list[Path]:
    valid: list[Path] = []
    for vf in iter_video_files(videos_dir):
        is_valid, _ = validate_filename(vf.name)
        if is_valid:
            valid.append(vf)
    return valid


def ensure_tool(name: str) -> str:
    return shutil.which(name) or name
