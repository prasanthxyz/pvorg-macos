# pvorg — Design and UX Decisions

This document records the design direction, the design system, and the
reasoning behind the interface. Functionality is described in
[FUNCTIONALITY.md](FUNCTIONALITY.md).

## Direction: quiet native chrome, immersive media

pvorg is a single-user, keyboard-driven media browser. The imagery (contact
sheets, galleries, video) is the content; everything else should recede.

- **Native macOS structure.** A sidebar split view, a unified toolbar per page,
  native search fields, menus, sheets, alerts and inspectors. Standard
  components keep the app consistent with the system and let it adopt the
  macOS 26+ glass styling automatically. It also runs on the macOS 14
  deployment target.
- **A dark stage for media.** The viewer, the slideshow and video playback sit
  on a near-black stage in both appearances, the way Photos and QuickTime
  present media. The chrome around it follows the system appearance.
- **Restraint.** One accent color (the user's system accent), semantic system
  colors, system text styles, and decoration only where it carries meaning.

The app previously had a forced dark theme with custom navy colors and
capsule tabs. Dark remains the default appearance to preserve that choice, and
light and system appearances are now fully supported (Settings › Appearance).

## Design system

All tokens and shared components live in `Sources/PvorgNative/DesignSystem/`.

### Tokens (`Theme.swift`)

| Token | Values | Use |
|---|---|---|
| `Spacing` | 2, 4, 8, 12, 16, 24, 32 | Every padding and stack spacing (4pt grid). |
| `Radius` | small 5, medium 8, large 12 | Cells/chips, thumbnails/cards, floating surfaces. |
| Chrome colors | `subtleFill`, `subtleFillHover`, `hairline`, `thumbnailPlaceholder` | Built on `.primary` and system separators, so they adapt to both appearances. |
| Stage colors | `stage`, `stageRaised`, `stageHairline`, `stagePrimary`, `stageSecondary` | Fixed dark values for media surfaces. |
| Decision colors | `decisionYes`, `decisionNo`, `pendingChange` | Mapping states. Yes and No are tuned per appearance so glyphs keep 3:1 contrast (system green and red are too light on white). |
| `AppearancePreference` | System / Light / Dark | Applied app-wide through `NSApp.appearance`, so sheets, alerts, menus and the hover panel agree. |

Typography uses system text styles only (`.title3`, `.headline`, `.callout`,
`.caption`…) with monospaced digits wherever numbers change in place (counts,
timecodes, positions).

### Components

| Component | Purpose |
|---|---|
| `ImagePipeline` + `AsyncThumbnail` | Decodes images off the main thread at display size (ImageIO thumbnails) into a memory-bounded cache with in-flight de-duplication. Views read the cache synchronously, so recreated views never flash a placeholder. Four size buckets let screens share cache entries. |
| `FlowLayout` | Wraps chips at their natural width. |
| `FilterChip` | Toggle token. State is shown by the symbol (filled check vs. empty circle) as well as the tint, and both states have the same width so toggling never reflows the layout. |
| `Callout` | Inline warning or critical notice (skipped files, risky cleanup). |
| `ToastCenter` / `ToastOverlay` | Brief confirmation of completed actions, also announced to VoiceOver. Errors use alerts, because they need acknowledgement. |
| `FloatingSurface` | Glass on macOS 26+, material with hairline and shadow before that. |
| `ProminentToolbarButton` | The one emphasized toolbar action (Save). |
| `TriStateBadge` / `TriStateCell` | Mapping cell glyph, shared by the matrix and its legend. |

Empty, error and no-results states use the system `ContentUnavailableView`
throughout, each with a specific explanation and the action that resolves it.

## Decision log

### Navigation and structure

| Decision | Why |
|---|---|
| Replaced the in-content capsule tab bar with a `NavigationSplitView` sidebar grouped into **Browse** (Viewer, Filters) and **Organize** (Library, Gallery Mapping, Tag Mapping). | The sidebar is the native pattern for a multi-section Mac app. It frees the toolbar for page actions, carries badges, and can be hidden to give the viewer more room. |
| Renamed pages: Home → **Viewer**, Config → **Filters**, Deleter → **Library**, Mapper → **Gallery Mapping**, Tag Mapper → **Tag Mapping**. | "Config" suggested editable settings, but the page filters combinations. "Deleter" named the action, not the thing. "Mapper" was ambiguous next to "Tag Mapper". The menu already said "Viewer". |
| Kept the V and C single-key shortcuts, and removed the "(V)" and "(C)" hints from labels. | Muscle memory matters in a keyboard-driven app. Hints now appear where macOS users look for them: the menus and tooltips. |
| Page-specific actions live in each page's toolbar; window title and subtitle describe the page or current item. | Standard macOS hierarchy: the title says where you are, the toolbar says what you can do. |
| Single window (File › New Window removed). | All windows would share one library and state; a second window could only confuse. |
| Settings window with Appearance and library paths. | Gives appearance a home and shows the paths, which were previously invisible in the UI. |

### Keyboard

| Decision | Why |
|---|---|
| Single-key shortcuts are defined once (`PlainKeyCommand`) and dispatched by a local key monitor (`KeyboardContext`) against live state. Menus show the same shortcuts and call the same actions, but never handle those keys themselves. | Two problems with leaving them to menu key equivalents. First, unmodified menu shortcuts are matched before text fields see the key, so with search fields you couldn't type "v", "c", "n" or a space. Second, SwiftUI refreshes command menus lazily, so key equivalents act on stale state; in testing, Space did nothing right after P started a video. The monitor sends keys to the focused control while typing or while a sheet or Settings has focus, and performs the command otherwise. |
| Viewer keys (P, B, N, Space, arrows, digits) only act while the viewer is showing. | Previously they were global and swallowed Space and arrow keys on every page. |
| Replaced NotificationCenter command dispatch with direct calls on a shared `ViewerModel`. | Menu items reflect live state ("Play" vs. "Pause", "Play Video" vs. "Show Contact Sheet") and enable only when meaningful. |
| ⌘A, Esc and ⌘⌫ on the Library's Select All, Deselect All and Delete buttons; ⌘S and ⌘R in File. | Standard Mac equivalents for select all, deselect, delete, save and reload. They step aside while typing, so they edit or clear the search text instead. |

### Viewer

| Decision | Why |
|---|---|
| Title shows the video title; subtitle shows studio and cast; the gallery name moved onto the slideshow caption. | Clear hierarchy: what you're watching, who made it, and what it's paired with, where it applies. The raw filename was the old title. |
| Segmented control with icons (contact sheet / video) instead of a "VID"/"TGP" button that named the *other* mode. | Shows the current state and the alternative at once, with no jargon. |
| ‹ › controls with a "12 of 188" position in the toolbar. | Compact, native, and the position is always visible. |
| Kept the 75/25 split and the 2-second shuffled slideshow. | Core to the product; only the presentation changed. |
| Custom transport bar: skip ±10s, play/pause, timecodes, and a scrubber with frame preview and live drag seeking. | The old bar was an unlabeled 8pt strip that seeked only on release and decoded preview frames on the main thread. Frames are now generated asynchronously and cached per second. |
| Resume on returning to the same video; reset when the combination changes. | Toggling to check the contact sheet shouldn't lose your place. |
| Explicit failure state for unplayable files (.mkv, .avi, .wmv…) with **Open in Default App**. | Previously a silent black rectangle. |
| **Exclude Pairing** in the viewer (thumbs-down, ⌫, menu, right-click) marks the gallery as "No" for the video and moves on. | Spotting a bad pairing happens while browsing, so the fix should happen there rather than after a trip to Gallery Mapping. |
| It's called *Exclude*, not *Delete*. | Library › Delete permanently removes video files, so a second "Delete" that only changes a pairing would be dangerous. "Excluded" is also the state's name in Gallery Mapping. |
| No confirmation; Undo through a toast, ⌘Z and ⇧⌘Z instead. | The action is reversible and frequent, so a dialog would only slow down a browsing session. Undo restores pvorg.json exactly. |
| The pairing is removed in place, without reshuffling the list. | A regular save regenerates and reshuffles every combination and jumps to the start. Excluding should feel like "next", not like losing your place. |
| Distinct empty states for no videos, no galleries, filters excluding everything, and mappings excluding everything. | Each has a different cause and a different fix. |

### Filters

| Decision | Why |
|---|---|
| Each section states its rule: Galleries and Studios **include**; Tags and Cast **require all**. Header summaries ("8 of 9", "Any", "2 required") and one-line explanations. | The two semantics were invisible before, so "everything highlighted" and "nothing highlighted" looked like opposite states of the same control. |
| Flow layout at natural width instead of an equal-width grid. | Names were truncated to fit 110pt cells. |
| Tinted selected state with a check, not solid accent fills. | Galleries and Studios default to all selected; a wall of saturated blue chips was the loudest thing on screen and said nothing. |
| Tags are opt-in: a video has a tag only when marked Yes. Galleries stay opt-out. No required tags means no tag filter. | A required tag should narrow the list to videos you actually tagged. Previously "has the tag" meant "not excluded", so requiring a tag matched every untouched video and barely filtered. Opt-in is also how the original V1 app behaved. Galleries stay opt-out so new videos pair with everything by default and Exclude Pairing can veto single pairings. |
| Section-level Include All / Include None / Clear, and context menus on every chip (previously galleries only). | Common edits take one click; the same affordances behave the same way everywhere. |
| Search field that filters chip names. | Cast lists grow to hundreds of names. |
| The sample list moved into a native inspector: a large combination count, **Open Viewer**, and **Up Next** rows that open the viewer at that combination. | It answers "what will I see?" and lets you jump straight to it. "Up Next" follows the viewer's position instead of always listing the first ten. |

### Library

| Decision | Why |
|---|---|
| Continuous lazy grid instead of 24-item pages. | Pagination is a web pattern; with asynchronous, downsampled thumbnails a single scrolling grid stays fast, and selection works across the whole library. |
| Search across title, studio, cast and filename; Select All applies to what's shown, and searching drops hidden videos from the selection. | Bulk cleanup becomes: search, ⌘A, ⌘⌫. "What you see is what you delete": a selection made before searching can't silently include hidden videos. |
| Selection uses the system accent (ring and check badge); red is reserved for the Delete action itself. | One selection language across the app. Destructive color signals the consequence, not the selection. |
| Select All, Deselect All and Delete are always in the toolbar and enable when they apply, instead of appearing and disappearing. | No layout jumps; the actions stay discoverable. |
| Confirmation says what is removed and names the videos (up to six); Cancel is the default; success is a toast and partial failures an alert. | Permanent deletion should be explicit and hard to trigger by accident. |
| Skipped files are surfaced in the page with the reason for each. | They were only written to the log, so a misnamed file simply vanished. |
| Hover preview: short initial delay, then instant swaps between neighbors; sized to the image and the screen; glass HUD styling; asynchronous decoding. | Sweeping the pointer across a grid used to flash a 920pt panel on every card. |

Deletion remains permanent rather than moving files to the Trash. That is a
deliberate product behavior (video files are large and the old app said "This
cannot be undone"), so it was kept and made clearer rather than changed.

### Mapping

| Decision | Why |
|---|---|
| Pending changes live in an app-level `MappingSession` and survive page switches, search, the Undecided/All toggle and reloads; the sidebar shows a badge. | Previously, toggling "Hide fully decided" or leaving the page silently discarded unsaved work. |
| Continuous matrix with a pinned header instead of 20-row pages. | Column names stay visible while scrolling; no page buttons. |
| "Show: Undecided / All" segmented control instead of a "Hide fully decided" checkbox. | States what's shown rather than what's hidden. |
| Tinted cells with ✓ ✗ – glyphs; orange ring and dot for unsaved cells; full-cell click targets; a legend in the status bar. | A dense matrix of solid red and green blocks was overwhelming. State never relies on color alone, and the target is easier to hit. |
| Column header menus (set all shown) and row context menus (set every column). | Mapping a new gallery used to take one click per video. |
| Save writes once and confirms with a toast; Revert asks first, from the toolbar and the File menu alike; ⌘S works from the File menu. | Clear, recoverable editing with standard commands. |
| Save semantics are unchanged: unknown values preserved, the other relation pair untouched. | Data compatibility with existing pvorg.json files and the Python scripts. |

### Startup, errors and maintenance

| Decision | Why |
|---|---|
| Loading screen names each step, with a determinate bar and the current file during preview generation. | The old screen showed "0 videos, 0 galleries" throughout, because counts are only known at the end. |
| Error screen explains where pvorg looks for its config and offers **Try Again**; invalid JSON errors name the problem key. | Previously a red message with no way forward except relaunching. |
| Reload Library (⌘R) in File. | The reload capability existed in code but had no UI; new files required a relaunch. |
| Stale-entry cleanup moved from a separate Maintenance menu into File; the sheet uses a structured summary, a critical callout when nothing is on disk, and never makes the destructive button default in that case. | Fewer top-level menus, and the risky case can't be confirmed with Return. |
| Contact sheets for Matroska and WebM files. | ffprobe reports no per-stream duration for those containers, so preview generation failed for them; it now falls back to the container duration. |

## Accessibility

- VoiceOver labels and values on icon-only controls, cards (title and credits,
  selected trait), chips (selected trait), mapping cells ("Title, Gallery":
  "Yes, unsaved"), and the scrubber (position, adjustable in 10-second steps).
- State is never conveyed by color alone: chips use symbols, mapping cells use
  glyphs plus a ring and dot for unsaved changes, and selected cards use a
  check badge.
- Reduce Motion removes the slideshow crossfade and the toast's slide.
- Text uses system styles and wraps or truncates deliberately (middle
  truncation for paths and filenames, tail for titles).
- Hit targets: full-cell targets in the matrix and 32pt transport buttons.

## Validation approach

Screens and states are verified with the debug-only UI tour
(`PVORG_UI_TOUR`, see FUNCTIONALITY.md §6) against the fixture library:

- It captures every page and state in Dark and Light at 1280×820 and at the
  960×600 minimum, plus the delete confirmation, the cleanup sheet, a toast,
  and Settings.
- It presses real keys through the event queue to check every shortcut,
  including that shortcut keys typed into a search field reach the field.

Logic is covered by unit tests in `Tests/PvorgNativeTests`.
