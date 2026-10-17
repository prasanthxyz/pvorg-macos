# pvorg — Functionality Reference

pvorg is a native macOS app for browsing a personal library of videos paired
with image galleries. It shows one **combination** (a video plus a gallery) at
a time: the video's contact sheet or the video itself on the left, and the
gallery as a slideshow on the right. Around that viewer are tools to narrow
which combinations appear, to decide which galleries and tags belong to which
videos, and to remove unwanted videos.

This document describes everything the app does. The reasoning behind the
interface is in [DESIGN.md](DESIGN.md).

---

## 1. Library on disk

### Configuration file

pvorg reads `~/pvorg.json`. Set the `PVORG_CONFIG` environment variable to use
a different file, which is useful for testing against a sample library.

```json
{
  "videosPath": "/Volumes/Media/videos",
  "galleriesPath": "/Volumes/Media/galleries",
  "tags": ["4k", "outdoor", "travel"],
  "videoRelations": {
    "acme-jane_doe-harbor_lights.mp4": {
      "galleries": ["Beach Days"],
      "excludedGalleries": ["Portraits"],
      "tags": ["outdoor"],
      "excludedTags": ["4k"]
    }
  }
}
```

| Field | Meaning |
|---|---|
| `videosPath` | Folder of video files. Generated previews live in `<videosPath>/img/`, cached metadata in `<videosPath>/cache.json`. |
| `galleriesPath` | Folder whose subfolders are galleries. Each subfolder's images form one gallery. |
| `tags` | The tag vocabulary used for filtering and tag mapping. |
| `videoRelations` | Per-video decisions. Videos without an entry belong to every gallery and have no tags. |

If the file is missing or invalid, pvorg shows an error screen. For invalid
JSON it names the missing key or the offending path, and it offers **Try Again**.

### Video filenames

Videos must be named `studio-cast-…-title.ext`: lowercase, no spaces, at least
three dash-separated parts. The first part is the studio, the last is the
title, and everything between is cast. Supported extensions are mp4, mkv, avi,
mov, wmv and webm. Files that don't follow the convention are **skipped**, and
the Library lists them with the reason (see §5).

The UI shows names in readable form: `jane_doe` becomes "Jane Doe" and
`harbor_lights` becomes "Harbor Lights". The raw values remain the identifiers
in the config, and lists sort by the readable name.

### Galleries

A gallery is a subfolder of `galleriesPath`. Its png, jpg, jpeg, bmp and gif
files are its images. The gallery's name is the folder name, shown as-is.

---

## 2. Startup

When the app launches, or when you choose **File › Reload Library (⌘R)**, it
runs these steps behind a progress screen:

1. **Loading Configuration**: reads pvorg.json.
2. **Scanning Library**: lists galleries and videos and validates filenames.
3. **Updating pvorg.json**: fills in missing relation arrays (`null` becomes
   `[]`) and saves only if anything changed.
4. **Cleaning Up Previews**: deletes contact sheets in `img/` whose video no
   longer exists.
5. **Preparing Previews**: for each video, generates a 4×4 contact sheet with
   ffmpeg if one is missing and records duration, size, frame rate and file
   size in `cache.json`. This step shows a determinate progress bar and the
   current file ("6 of 22 · filename").

The loading screen reports each step. On failure the error screen shows the
message, where pvorg looks for its configuration, **Try Again**, and **Show in
Finder** when the config file exists.

Reloading resets the filters to their defaults. Unsaved mapping changes survive
a reload, except for videos that no longer exist.

---

## 3. Combinations and filters

A combination pairs one video with one gallery. It is included when **all** of
these hold:

- the gallery is **included** in Filters;
- the video isn't **excluded** from that gallery in Gallery Mapping (both "Yes"
  and "Undecided" count as belonging);
- the video's studio is **included** in Filters;
- the video is marked **Yes for every required tag** in Tag Mapping. With no
  tags required (the default) there is no tag filter, and tagged and untagged
  videos alike appear;
- the video features **every required cast member**.

Galleries and tags deliberately work in opposite directions:

- **Galleries are opt-out.** A video pairs with every gallery unless it is
  excluded, which is why all galleries start included. Selecting several
  galleries shows each video with *any* of them.
- **Tags are opt-in.** A video has a tag only when it is explicitly marked Yes.
  Undecided and No both mean it doesn't, so a required tag narrows the list to
  videos you have actually tagged, and requiring several tags needs *all* of
  them.

The list is shuffled whenever it is regenerated, which happens on every filter
change and every reload.

---

## 4. Screens

The window has a sidebar with two groups:

- **Browse:** Viewer, Filters
- **Organize:** Library, Gallery Mapping, Tag Mapping

The sidebar footer shows the library size ("22 videos · 9 galleries"). You can
hide the sidebar with the toolbar button or **View › Hide Sidebar**.

### 4.1 Viewer

The main browsing surface. The toolbar title is the video's title, and the
subtitle shows its studio and cast.

**Stage (left, 75%)**: two modes, switched with the toolbar's segmented
control or **P**:

- **Contact sheet** (default for every new combination): the 4×4 preview
  image. Double-click it to play the video.
- **Video**: the video plays immediately. Click the video to play or pause.
  The transport bar below it has:
  - Skip back 10s, Play/Pause, and Skip forward 10s buttons.
  - Elapsed time and duration.
  - A scrubber. Hovering shows the frame and timecode under the pointer.
    Dragging seeks live; releasing seeks exactly. VoiceOver reads the
    position and adjusts it in 10-second steps.

  Switching back to the contact sheet pauses playback. Returning to the video
  of the same combination resumes where it paused. Moving to another
  combination stops playback and returns to the contact sheet.

**Slideshow (right, 25%)**: the gallery's images in a random order, advancing
every 2 seconds with a short crossfade (no animation with Reduce Motion). A
caption shows the gallery name and position ("3 of 11"). The next image is
decoded before switching, so the fade never shows a blank frame.

**Navigation**: the toolbar's ‹ › buttons, or **B** / **N**, move through
combinations and wrap at either end. The toolbar shows the position
("12 of 188"). The next combination's contact sheet is prefetched.

**Exclude Pairing** (toolbar thumbs-down, **⌫**, **Viewer › Exclude "Gallery"
from This Video**, or right-click the stage) says this gallery should never be
paired with this video:

- It writes the gallery to the video's `excludedGalleries` in pvorg.json (and
  removes it from `galleries` if it was there). This is the same as setting
  the cell to ✗ in Gallery Mapping, and any unsaved Gallery Mapping edit of
  that cell is dropped.
- The pairing leaves the list and the next combination appears in its place.
  Nothing is reshuffled, and the count drops by one.
- There is no confirmation. A toast ("Excluded "Beach Days" from "Harbor
  Lights"") offers **Undo**, and **Edit › Undo Exclude Pairing** (⌘Z) and
  **Redo** (⇧⌘Z) work too. Undo restores the earlier decision exactly,
  including removing the pvorg.json entry if excluding created it. If the
  filters still allow the pairing, Undo also puts it back where it was and
  shows it.
- Only the pairing is affected: the video stays in every other gallery and no
  files are touched. To delete video files, use the Library.

The stage's right-click menu also has **Reveal Video in Finder** and **Reveal
Gallery in Finder**.

**States**

| Situation | What you see |
|---|---|
| No contact sheet for this video | "No Contact Sheet" with a **Play Video** button. |
| Video can't be played (e.g. .mkv, .avi, .wmv) | "Can't Play This Video" with the likely cause, **Open in Default App**, and **Show Contact Sheet**. |
| Gallery folder is empty | "No Images" in the slideshow area. |
| No videos in the library | "No Videos" with the videos folder path and **Reload Library**. |
| No galleries | "No Galleries" with the galleries folder path and **Reload Library**. |
| Filters exclude everything | "No Matching Combinations" with **Edit Filters** and **Reset Filters**. |
| Filters are at defaults but every video is excluded from every gallery | "No Combinations" with **Open Gallery Mapping**. |

### 4.2 Filters

Four sections decide which combinations the viewer shows. Each section header
says how its selection works:

| Section | Mode | Default | Header summary |
|---|---|---|---|
| Galleries | **Include**: pair videos only with included galleries | all included | "All 9" / "8 of 9" |
| Studios | **Include**: only videos from included studios | all included | "All 6" / "5 of 6" |
| Tags | **Require**: only videos marked Yes for every selected tag | none | "Any" / "2 required" |
| Cast | **Require**: only videos featuring everyone selected | none | "Any" / "1 required" |

- Click a chip to toggle it. Selected chips show a filled check and an accent
  tint; others show an empty circle.
- Include sections have **Include All** and **Include None**. Require sections
  have **Clear**.
- Right-click a chip for **Include Only "X"** and **Include All Except "X"**
  (include sections) or **Require Only "X"** (require sections).
- The toolbar search field ("Filter Names") narrows the chips in every section.
  A section with no matches says so.
- **Reset Filters** (toolbar) restores the defaults. It is disabled when the
  filters are already at defaults.
- Changes apply immediately. The subtitle shows the combination count.

**Preview inspector** (toggle with the toolbar's sidebar button) shows:

- The combination count, and how many distinct videos and galleries it spans.
- **Open Viewer**.
- **Up Next**: the next 10 combinations from the viewer's current position,
  with thumbnails. Click one to open it in the viewer.

### 4.3 Library

Every valid video as a grid of contact-sheet cards, sorted by title. Each card
shows the title and "Studio · Cast". The grid scrolls continuously; there are
no pages.

- **Search** (toolbar) matches title, studio, cast or filename, ignoring case
  and diacritics.
- **Selection**: click a card to select or deselect it (accent ring and check
  badge; hovering shows an empty circle).
  - **Select All** (toolbar, ⌘A) selects every video shown, which means every
    match when searching.
  - **Deselect All** (toolbar, Esc) clears the selection.
  - The subtitle shows "3 of 22 videos selected".
  - The selection only ever contains videos you can see. Searching drops
    hidden videos from it, so Delete can never remove something the search is
    hiding.
- **Hover a thumbnail** for a large floating preview near the pointer. The
  first preview appears after a short delay; moving to a neighbor swaps it
  instantly.
- **Context menu**: Select / Deselect, **Reveal in Finder**, and **Delete…**
  (deletes this video, or the whole selection when the card is part of a
  multi-selection).
- **Delete** (toolbar trash, ⌘⌫) asks for confirmation ("Delete 3 Videos?").
  The dialog names the videos when there are six or fewer, and Cancel is the
  default button. Deleting permanently removes, for each video:
  the video file, its contact sheet, its `videoRelations` entry, and its
  `cache.json` entry. Only filenames from the scanned library are accepted.
  - On success, a confirmation appears briefly ("Deleted 3 videos").
  - Partial failures are listed in an alert.
- **Skipped files**: when some filenames don't follow the convention, a notice
  above the grid ("2 files skipped") offers **Show Files**, which lists each
  file and why it was skipped. If every file was skipped, the empty state says
  so and offers the same list.
- **States**: "No Videos" when the folder is empty; a standard "No Results"
  view when a search matches nothing.

### 4.4 Gallery Mapping and Tag Mapping

A matrix for deciding which galleries (or tags) belong to which videos. Rows
are videos (thumbnail, title, "Studio · Cast"); columns are galleries (or
tags). Each cell is one of:

| State | Look | Gallery Mapping | Tag Mapping |
|---|---|---|---|
| Undecided | gray **–** | paired (default) | doesn't have the tag (default) |
| Yes | green **✓** | paired | has the tag |
| No | red **✗** | never paired | doesn't have the tag |

In Tag Mapping, No and Undecided both leave a video untagged. The difference is
bookkeeping: a video counts as "decided" only once every tag is Yes or No, which
is what the Undecided view uses.

- **Click a cell** to cycle Undecided → Yes → No → Undecided. The whole cell is
  the click target.
- **Changed cells** are marked with an orange ring and dot until saved.
  Cycling a cell back to its saved value clears the mark.
- **Click a column header** to set that column for every shown video
  (Yes / No / Undecided).
- **Right-click a row** to set every column for that video, or to reveal the
  video in Finder.
- **Show: Undecided | All** (toolbar) shows only videos missing at least one
  decision (default) or every video. A video moves out of "Undecided" only
  after its decisions are saved.
- **Search** narrows rows by title, studio, cast or filename.
- The column header row stays pinned while scrolling. Many columns scroll
  horizontally.
- The status bar shows a legend, the unsaved-change count, and "21 of 22
  videos shown".
- **Save** (toolbar, **File › Save Mapping Changes**, ⌘S) writes every pending
  change to pvorg.json in one atomic write and confirms "Saved 6 changes".
  Unknown values already in the config (for example a gallery folder that no
  longer exists) are preserved, and the other relation pair is untouched:
  Gallery Mapping never changes tags, and Tag Mapping never changes galleries.
- **Revert** (toolbar, or **File › Revert Mapping Changes…**) discards pending
  changes after confirmation.
- **Pending changes persist** across page switches, filter and search changes,
  and the Undecided/All toggle. The sidebar shows a badge with the count.
  Changes for videos that were deleted are dropped automatically.
- **States**: "No Galleries" / "No Tags" (with where to add them), "No Videos",
  "All Caught Up" with a **Show All Videos** button, and "No Results" for
  searches.

### 4.5 Clean Up Stale Entries

**File › Clean Up Stale Entries…** previews pvorg.json entries whose video file
no longer exists. The sheet shows:

- The videos folder, the number of videos on disk, and the number of entries
  in pvorg.json.
- The stale entries that would be removed.

Removing them touches only pvorg.json, never files. If **no** videos are
visible on disk while mappings exist, for example because a drive is
unplugged, the sheet shows a critical warning, and the remove button is no
longer the default button, so pressing Return can't trigger it. When there is
nothing to remove, the sheet says so and offers **Done**.

### 4.6 Settings (⌘,)

- **Appearance**: System, Light or Dark. Dark is the default. The viewer stage
  stays dark in every appearance.
- **Library**: the configuration file, videos folder and galleries folder,
  each with a button that shows it in Finder.

---

## 5. Menus and keyboard

Single-key shortcuts carry over from the original app. They always act on the
current state, and they never interfere with typing:

- While a text field is being edited, or while a sheet or Settings has focus,
  those keys go to the focused control.
- Viewer keys only act while the viewer is showing. Elsewhere, arrows and
  Space keep their usual behavior.

| Menu | Command | Shortcut |
|---|---|---|
| File | Reload Library | ⌘R |
| File | Clean Up Stale Entries… | — |
| File | Save Mapping Changes | ⌘S |
| File | Revert Mapping Changes… | — |
| View | Show/Hide Sidebar | ⌃⌘S |
| Go | Viewer | V |
| Go | Filters | C |
| Go | Library, Gallery Mapping, Tag Mapping | — |
| Viewer | Play Video / Show Contact Sheet | P |
| Viewer | Previous / Next Combination | B / N |
| Viewer | Exclude "Gallery" from This Video | ⌫ |
| Edit | Undo / Redo Exclude Pairing | ⌘Z / ⇧⌘Z |
| Viewer | Play / Pause | Space |
| Viewer | Skip Back / Forward 10 Seconds | ← / → |
| Viewer | Jump To 0%…90% | 0…9 |
| (Library toolbar) | Select All / Deselect All / Delete | ⌘A / Esc / ⌘⌫ |

The app uses a single window; File › New Window is removed.

---

## 6. Developer tooling

| Tool | Purpose |
|---|---|
| `Scripts/make_ui_fixture.sh <dir>` | Builds a synthetic library with ffmpeg: 21 valid videos (one with a very long title), one .mkv (exercises the playback-error state), two badly named files, eight galleries plus an empty one, and stale config entries. |
| `PVORG_CONFIG=<file>` | Runs the app against another config file. |
| `PVORG_UI_TOUR=<dir>` (debug builds only) | Walks every screen and state in Dark and Light (`PVORG_UI_TOUR_APPEARANCES=dark,light`), saves PNG screenshots of the app's own windows, presses real keys through the event queue to check every shortcut, writes `results.txt` (PASS/FAIL per check), and quits. Screenshots need no Screen Recording permission. Shortcut checks need the app to be frontmost, which macOS won't allow while the screen is locked; in that case they are reported as SKIP. |

Example visual QA run:

```bash
Scripts/make_ui_fixture.sh /tmp/pvorg-fixture
CONFIGURATION=debug DIST_DIR=/tmp/pvorg-debug ./Scripts/build_app_bundle.sh
open -W --env PVORG_CONFIG=/tmp/pvorg-fixture/pvorg.json \
        --env PVORG_UI_TOUR=/tmp/pvorg-tour /tmp/pvorg-debug/pvorg.app
cat /tmp/pvorg-tour/results.txt
```

The Python scripts in `Scripts/` (filename validation, orphan cleanup, contact
sheet and sprite generation, re-encoding) are standalone command-line tools and
are unchanged.
