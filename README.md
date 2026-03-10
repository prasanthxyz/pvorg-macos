# pvorg-native

Native macOS implementation of PVORG (SwiftUI + Swift Concurrency), based on `SPECIFICATION-NATIVE.md`.

## Requirements

- macOS 14+
- Xcode installed
- `ffmpeg` and `ffprobe` in `PATH` (for preprocessing)
- `~/pvorg.json` config file present

## Build

```bash
swift build --package-path .
```

If your active command-line toolchain and SDK mismatch, use the Xcode toolchain explicitly:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --package-path .
```

## Build App Bundle (`pvorg.app`)

```bash
./Scripts/build_app_bundle.sh
```

This produces:

- `dist/pvorg.app`

Then launch:

```bash
open dist/pvorg.app
```

## Run

```bash
swift run --package-path . pvorg-native
```

Or open `Package.swift` in Xcode and run the `pvorg-native` target.

## Project Layout

- `Sources/PvorgNative/App`: app entry and page routing
- `Sources/PvorgNative/State`: app state + startup pipeline
- `Sources/PvorgNative/Services`: scanning, preprocessing, deletion, cleanup
- `Sources/PvorgNative/Views`: Viewer, Config, Deleter, Gallery Mapper, Tag Mapper
- `Sources/PvorgNative/Models`: config/domain/cache models
- `Scripts`: standalone CLI helper scripts

## Notes

- Startup pipeline includes config load, scan, normalization, cleanup, preprocessing, and report logging.
- Gallery/tag mapper saves preserve existing relation fields and keep unknown/manual values intact.
- Config path is fixed to `~/pvorg.json`.
- `ffmpeg` and `ffprobe` are expected to be available in `PATH`.
