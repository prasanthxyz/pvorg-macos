# pvorg-native

The macOS app of PP Video Organizer, built with SwiftUI and Swift Concurrency.

**What the app does and how it should look and behave is defined in
[docs/SPEC.md](docs/SPEC.md)**, the product spec shared with pvorg-web,
pvorg-android and pvorg-electron. This README covers building, running and
developer tooling only.

## Requirements

- macOS 14+
- Xcode
- `ffmpeg` and `ffprobe` in `PATH` (for preview generation)
- A library configuration at `~/pvorg.json` (see the spec, §1), or another
  file named by the `PVORG_CONFIG` environment variable

## Build and run

```bash
swift build
swift run pvorg-native
```

If the active command-line toolchain and SDK don't match, use Xcode's:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
```

You can also open `Package.swift` in Xcode and run the `pvorg-native` target.

### App bundle

```bash
./Scripts/build_app_bundle.sh    # produces "dist/PP Video Organizer.app"
open "dist/PP Video Organizer.app"
```

`CONFIGURATION=debug` builds a debug bundle, and `DIST_DIR=<dir>` chooses where
it goes.

## Tests

```bash
swift test
```

## Visual QA

| Tool | Purpose |
|---|---|
| `Scripts/make_ui_fixture.sh <dir>` | Builds a synthetic library with ffmpeg: 21 valid videos (one with a very long title), one .mkv (exercises the playback-error state), two badly named files, eight galleries plus an empty one, and stale config entries. |
| `PVORG_CONFIG=<file>` | Runs the app against another configuration file. |
| `PVORG_UI_TOUR=<dir>` (debug builds only) | Walks every screen and state, saves PNG screenshots of the app's own windows, presses real keys through the event queue to check every shortcut, writes `results.txt` (PASS/FAIL per check), and quits. `PVORG_UI_TOUR_APPEARANCES=dark,light` chooses the appearances. |

Screenshots need no Screen Recording permission. Shortcut checks need the app
to be frontmost, which macOS won't allow while the screen is locked; they are
then reported as SKIP.

```bash
Scripts/make_ui_fixture.sh /tmp/pvorg-fixture
CONFIGURATION=debug DIST_DIR=/tmp/pvorg-debug ./Scripts/build_app_bundle.sh
open -W --env PVORG_CONFIG=/tmp/pvorg-fixture/pvorg.json \
        --env PVORG_UI_TOUR=/tmp/pvorg-tour "/tmp/pvorg-debug/PP Video Organizer.app"
cat /tmp/pvorg-tour/results.txt
```

## Project layout

- `Sources/PvorgNative/App`: app entry, pages, menu commands, single-key commands
- `Sources/PvorgNative/State`: app state and startup pipeline, plus UI models (viewer, library, mapping sessions, keyboard)
- `Sources/PvorgNative/Services`: scanning, preprocessing, deletion, cleanup
- `Sources/PvorgNative/DesignSystem`: tokens, image pipeline, shared components
- `Sources/PvorgNative/Views`: Viewer, Filters, Library, Gallery/Tag Mapping, Settings, shared sheets
- `Sources/PvorgNative/Models`: configuration, domain and cache models
- `Sources/PvorgNative/Debug`: the debug-only UI tour
- `Scripts`: standalone Python maintenance scripts (filename validation, orphan
  and config cleanup, contact sheet and sprite generation, re-encoding), the app
  bundle builder and the QA fixture generator
- `docs/SPEC.md`: the shared product spec
