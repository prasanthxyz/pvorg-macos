# pvorg-macos

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

## Releasing

A release is a version tag plus a GitHub release carrying an unsigned DMG for
Apple silicon. You need Xcode selected (`xcode-select -p` prints
`/Applications/Xcode.app/Contents/Developer`) and the
[GitHub CLI](https://cli.github.com) (`brew install gh`, then `gh auth login`).
Start from an up-to-date `main` with nothing uncommitted.

1. **Test and build** with the new version number:

   ```bash
   export VERSION=1.1.0
   swift test
   ./Scripts/build_app_bundle.sh      # must print "Assets compiled.", or the app has no icon
   ```

2. **Check the app**, then open it once on your library:

   ```bash
   APP="dist/PP Video Organizer.app"
   plutil -p "$APP/Contents/Info.plist" | grep ShortVersion   # the new version
   lipo -archs "$APP/Contents/MacOS/pvorg"                     # arm64
   codesign -dv "$APP" 2>&1 | grep Signature                   # Signature=adhoc
   open "$APP"
   ```

3. **Package a DMG** with the usual "drag to Applications" link, and its
   checksum:

   ```bash
   rm -rf dist/dmg && mkdir dist/dmg
   cp -R "$APP" dist/dmg/ && ln -s /Applications dist/dmg/Applications
   hdiutil create -volname "PP Video Organizer" -srcfolder dist/dmg -ov -format UDZO "dist/pvorg-macos-$VERSION.dmg"
   shasum -a 256 "dist/pvorg-macos-$VERSION.dmg" > "dist/pvorg-macos-$VERSION.dmg.sha256"
   ```

4. **Write the release notes** in `dist/release-notes.md`: what changed, then
   the standing notes below.

   ```markdown
   **Requirements:** macOS 14 or later on Apple silicon. Install ffmpeg
   (`brew install ffmpeg`) for contact sheets and video details.

   **Unsigned build.** On first launch macOS blocks it: open System Settings ›
   Privacy & Security and click **Open Anyway**, or run
   `xattr -dr com.apple.quarantine "/Applications/PP Video Organizer.app"`
   ```

5. **Tag and publish:**

   ```bash
   git tag "v$VERSION" && git push origin "v$VERSION"
   gh release create "v$VERSION" "dist/pvorg-macos-$VERSION.dmg" "dist/pvorg-macos-$VERSION.dmg.sha256" \
     --title "PP Video Organizer for macOS $VERSION" --notes-file dist/release-notes.md
   ```

6. **Try it as a user would:** download the DMG from the release page in a
   browser, drag the app to Applications and open it. Only a downloaded copy
   gets the unsigned-app block, so this is the one step a local build can't
   check.

`dist/` is ignored by git. Clean it up with `rm -rf dist`: `dist/dmg/Applications`
is only a link, so this never touches the real Applications folder.

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
