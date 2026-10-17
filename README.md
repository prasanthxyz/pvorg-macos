# pvorg-native

Native macOS implementation of PVORG (SwiftUI + Swift Concurrency), originally based on `SPECIFICATION-NATIVE.md`.

- [docs/FUNCTIONALITY.md](docs/FUNCTIONALITY.md): what the app does, screen by screen, including data semantics, states, menus and shortcuts.
- [docs/DESIGN.md](docs/DESIGN.md): design direction, design system, and the reasoning behind each UX decision.

Where these docs and the original specification differ on the interface, the docs describe the current app.

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

- `Sources/PvorgNative/App`: app entry, pages, menu commands
- `Sources/PvorgNative/State`: app state and startup pipeline, plus UI models (viewer, library, mapping sessions, keyboard)
- `Sources/PvorgNative/Services`: scanning, preprocessing, deletion, cleanup
- `Sources/PvorgNative/DesignSystem`: tokens, image pipeline, shared components
- `Sources/PvorgNative/Views`: Viewer, Filters, Library, Gallery/Tag Mapping, Settings, shared sheets
- `Sources/PvorgNative/Models`: config/domain/cache models
- `Sources/PvorgNative/Debug`: debug-only UI tour for visual QA
- `Scripts`: standalone CLI helper scripts and the QA fixture generator

## Visual QA

`Scripts/make_ui_fixture.sh` builds a synthetic library. A debug build launched with `PVORG_UI_TOUR=<dir>` walks every screen and state and saves screenshots there. See [docs/FUNCTIONALITY.md §6](docs/FUNCTIONALITY.md#6-developer-tooling).

## Notes

- Startup pipeline includes config load, scan, normalization, cleanup, preprocessing, and report logging.
- Gallery/tag mapper saves preserve existing relation fields and keep unknown/manual values intact.
- Config path is `~/pvorg.json` (override with the `PVORG_CONFIG` environment variable).
- `ffmpeg` and `ffprobe` are expected to be available in `PATH`.
