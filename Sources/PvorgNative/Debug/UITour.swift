#if DEBUG
import AppKit
import SwiftUI

/// Developer tool for visual QA (debug builds only). Launch with
/// `PVORG_UI_TOUR=<output-dir>` (and usually `PVORG_CONFIG` pointing at a
/// library from `Scripts/make_ui_fixture.sh`). The app walks every screen and
/// state, saves screenshots of its own windows, checks keyboard behavior with
/// real key presses, writes `results.txt`, and quits.
@MainActor
enum UITour {
    static func runIfRequested(
        appState: AppState,
        navigation: AppNavigation,
        viewer: ViewerModel,
        library: LibraryModel,
        mappings: MappingStore,
        keyboard: KeyboardContext,
        toasts: ToastCenter
    ) async {
        guard let path = ProcessInfo.processInfo.environment["PVORG_UI_TOUR"], !path.isEmpty else { return }
        let tour = Tour(
            output: URL(fileURLWithPath: path, isDirectory: true),
            appState: appState,
            navigation: navigation,
            viewer: viewer,
            library: library,
            mappings: mappings,
            keyboard: keyboard,
            toasts: toasts
        )
        await tour.run()
        NSApp.terminate(nil)
    }
}

@MainActor
private final class Tour {
    let output: URL
    let appState: AppState
    let navigation: AppNavigation
    let viewer: ViewerModel
    let library: LibraryModel
    let mappings: MappingStore
    let keyboard: KeyboardContext
    let toasts: ToastCenter
    private var results: [String] = []

    init(output: URL, appState: AppState, navigation: AppNavigation, viewer: ViewerModel, library: LibraryModel, mappings: MappingStore, keyboard: KeyboardContext, toasts: ToastCenter) {
        self.output = output
        self.appState = appState
        self.navigation = navigation
        self.viewer = viewer
        self.library = library
        self.mappings = mappings
        self.keyboard = keyboard
        self.toasts = toasts
    }

    func run() async {
        try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        NSApp.activate()

        let appearances = (ProcessInfo.processInfo.environment["PVORG_UI_TOUR_APPEARANCES"] ?? "dark,light")
            .split(separator: ",")
            .compactMap { AppearancePreference(rawValue: String($0)) }

        await wait(0.8)
        if !appState.isReady && appState.fatalError == nil {
            NSApp.appearance = appearances.first?.nsAppearance
            await shot("loading")
        }
        while !appState.isReady && appState.fatalError == nil {
            await wait(0.2)
        }

        if appState.fatalError != nil {
            for appearance in appearances {
                NSApp.appearance = appearance.nsAppearance
                await shot("\(appearance.rawValue)-startup-error")
            }
            finish()
            return
        }

        resizeMainWindow(to: NSSize(width: 1280, height: 820))
        // Keyboard checks need the key window, which the app is most likely to have right after launch.
        NSApp.appearance = appearances.first?.nsAppearance
        await keyboardChecks()

        for appearance in appearances {
            NSApp.appearance = appearance.nsAppearance
            await tourScreens(prefix: appearance.rawValue)
        }

        NSApp.appearance = appearances.first?.nsAppearance
        await compactWindow(prefix: appearances.first?.rawValue ?? "dark")
        finish()
    }

    // MARK: Screens

    private func tourScreens(prefix p: String) async {
        // Viewer
        navigation.page = .viewer
        appState.showCombination(at: 0)
        await shot("\(p)-viewer-contact-sheet", settle: 1.6)

        viewer.show(.video, for: appState.currentCombination)
        await wait(1.5)
        viewer.player.pause()
        viewer.player.seekToPercent(0.4)
        await shot("\(p)-viewer-video")

        if let mkv = appState.combinations.firstIndex(where: { $0.video.fileURL.pathExtension == "mkv" }) {
            appState.showCombination(at: mkv)
            await wait(0.3)
            viewer.show(.video, for: appState.currentCombination)
            await shot("\(p)-viewer-unplayable", settle: 1.5)
        }

        if let empty = appState.combinations.firstIndex(where: { $0.gallery.imageFiles.isEmpty }) {
            appState.showCombination(at: empty)
            await shot("\(p)-viewer-empty-gallery", settle: 1.2)
        }

        appState.showCombination(at: 0)
        await wait(0.8)
        commands.excludeCurrentPairing()
        await shot("\(p)-viewer-excluded-toast", settle: 1.2)
        toasts.dismiss()
        keyboard.mainWindow?.undoManager?.undo()
        await wait(0.6)

        commands.toggleCurrentPairingInclusion()
        await shot("\(p)-viewer-included-toast", settle: 1.2)
        toasts.dismiss()
        await shot("\(p)-viewer-included", settle: 0.6)
        keyboard.mainWindow?.undoManager?.undo()
        toasts.dismiss()
        await wait(0.6)

        appState.selectedStudios = []
        appState.regenerateCombinations()
        await shot("\(p)-viewer-no-matches")
        appState.resetFilters()

        // Filters
        navigation.page = .filters
        await shot("\(p)-filters", settle: 1.2)
        appState.selectedGalleries.remove(appState.allGalleryNames.first ?? "")
        appState.selectedTags = ["outdoor"]
        appState.regenerateCombinations()
        await shot("\(p)-filters-narrowed", settle: 1.0)
        appState.resetFilters()

        // Library
        navigation.page = .library
        library.query = ""
        library.selection = []
        await shot("\(p)-library", settle: 1.5)
        library.selection = Set(appState.sortedVideos.prefix(3).map(\.filename))
        await shot("\(p)-library-selection")
        library.query = "acme"
        await shot("\(p)-library-search")
        library.query = "zzzz"
        await shot("\(p)-library-no-results")
        library.query = ""
        // Searching pruned the selection to what was shown; select again for the dialog.
        library.selection = Set(appState.sortedVideos.prefix(3).map(\.filename))
        library.pendingDeletion = Array(library.selection)
        await shot("\(p)-library-delete-confirm", settle: 1.0)
        library.pendingDeletion = []
        library.selection = []
        await wait(0.6)

        // Mapping
        navigation.page = .galleryMapping
        let galleries = mappings.galleries
        await shot("\(p)-gallery-mapping", settle: 1.2)
        for row in galleries.rows.prefix(3) {
            for column in galleries.columns.prefix(2) {
                galleries.cycle(row, column: column)
            }
        }
        await shot("\(p)-gallery-mapping-changes")
        galleries.showsDecidedVideos = true
        await shot("\(p)-gallery-mapping-all")
        galleries.revert()
        galleries.showsDecidedVideos = false

        navigation.page = .tagMapping
        await shot("\(p)-tag-mapping", settle: 1.2)

        // Sheets, toasts, settings
        navigation.page = .viewer
        await wait(0.6)
        appState.showStaleConfigCleanupPreview()
        await shot("\(p)-stale-cleanup", settle: 1.0)
        appState.dismissStaleConfigCleanupPreview()
        await wait(0.6)

        toasts.show("Deleted 2 videos", systemImage: "trash")
        await shot("\(p)-toast", settle: 0.6)

        openSettings()
        await wait(1.0)
        if let settings = NSApp.windows.first(where: { $0.isVisible && $0 !== mainWindow && $0.sheetParent == nil && $0.level == .normal }) {
            capture(settings, name: "\(p)-settings")
            settings.close()
        }
        await wait(0.4)
    }

    private func compactWindow(prefix p: String) async {
        resizeMainWindow(to: NSSize(width: 960, height: 600))
        for page in [Page.viewer, .filters, .library, .galleryMapping] {
            navigation.page = page
            await shot("\(p)-compact-\(page.rawValue)", settle: 1.2)
        }
    }

    // MARK: Keyboard

    /// Presses keys through the app's real event queue (local monitors, then
    /// menu key equivalents, then the first responder) and checks the result.
    /// SwiftUI disables all commands while the app has no key window (for
    /// example when the screen is locked), so command checks need focus.
    private func keyboardChecks() async {
        navigation.page = .library
        await wait(0.8)
        let isLive = NSApp.isActive && mainWindow?.isKeyWindow == true
        results.append("INFO  app active: \(NSApp.isActive), main window key: \(mainWindow?.isKeyWindow == true)")

        // Shortcut keys typed into a search field must reach the field.
        if let field = searchField(in: mainWindow?.contentView?.superview) {
            mainWindow?.makeFirstResponder(field)
            await wait(0.5)
            check(keyboard.isEditingText, "Focusing search marks text editing")
            for character in ["v", "c", "n", " ", "2"] {
                post(character)
            }
            await wait(0.6)
            check(navigation.page == .library, "Shortcut keys typed in search don't navigate")
            check(library.query == "vcn 2", "Shortcut keys typed in search reach the field (got “\(library.query)”)")
            mainWindow?.makeFirstResponder(nil)
            library.query = ""
            await wait(0.5)
            check(!keyboard.isEditingText, "Leaving search ends text editing")
        } else {
            check(false, "Found the Library search field")
        }

        // Deleting acts only on what's shown: searching drops hidden videos from the selection.
        library.selection = Set(appState.videos.map(\.filename))
        library.query = "acme"
        await wait(0.6)
        let shown = Set(library.visibleVideos(in: appState).map(\.filename))
        check(!library.selection.isEmpty && library.selection == shown, "Searching narrows the selection to shown videos (\(library.selection.count) selected, \(shown.count) shown)")
        library.query = ""
        library.selection = []
        await wait(0.4)

        guard isLive else {
            results.append("SKIP  Menu command checks: the app isn't active, so SwiftUI disables its commands. Re-run with the screen unlocked.")
            return
        }

        // Library: ⌘A selects every video, Esc clears, viewer keys are inert.
        post("a", modifiers: .command)
        await wait(0.5)
        check(library.selection.count == appState.videos.count, "⌘A selects every video (\(library.selection.count) of \(appState.videos.count))")
        post("\u{1b}", keyCode: 53)
        await wait(0.5)
        check(library.selection.isEmpty, "Esc clears the selection")
        check(menuItem("Viewer", "Next Combination")?.isEnabled == false, "Viewer commands are disabled outside the viewer")
        let index = appState.combinationIndex
        post("n")
        await wait(0.4)
        check(appState.combinationIndex == index, "N does nothing outside the viewer")

        // Navigation.
        check(key("Go", "Viewer") == "v" && key("Go", "Filters") == "c", "V and C are assigned in the Go menu")
        post("c")
        await wait(0.6)
        check(navigation.page == .filters, "C opens Filters")
        post("v")
        await wait(0.8)
        check(navigation.page == .viewer, "V opens the viewer")

        // Viewer.
        check(key("Viewer", "Next Combination") == "n" && key("Viewer", "Previous Combination") == "b", "N and B are assigned in the viewer")
        let before = appState.combinationIndex
        post("n")
        await wait(0.4)
        check(appState.combinationIndex == (before + 1) % max(appState.combinations.count, 1), "N advances to the next combination")
        post("b")
        await wait(0.4)
        check(appState.combinationIndex == before, "B returns to the previous combination")

        if let playable = appState.combinations.firstIndex(where: { $0.video.fileURL.pathExtension == "mp4" }) {
            appState.showCombination(at: playable)
            await wait(0.5)
        }
        post("p")
        await wait(1.5)
        check(viewer.mode == .video && viewer.player.isPlaying, "P plays the video")
        post(" ")
        await wait(0.5)
        check(!viewer.player.isPlaying, "Space pauses")
        post("5")
        await wait(0.5)
        let half = viewer.player.duration * 0.5
        check(abs(viewer.player.currentTime - half) < 0.5, "5 jumps to 50% (\(String(format: "%.1f", viewer.player.currentTime))s of \(String(format: "%.1f", viewer.player.duration))s)")
        post(String(UnicodeScalar(NSLeftArrowFunctionKey)!), keyCode: 123)
        await wait(0.5)
        check(viewer.player.currentTime < half - 0.5, "← skips back")
        post("p")
        await wait(0.5)
        check(viewer.mode == .contactSheet, "P returns to the contact sheet")

        // Exclude Pairing: ⌫ writes "No" and shows the next combination in place; ⌘Z / ⇧⌘Z undo and redo.
        appState.showCombination(at: 0)
        await wait(0.5)
        if let target = appState.currentCombination {
            let count = appState.combinations.count
            let isExcluded = { self.appState.config?.videoRelations[target.video.filename]?.noGalleries.contains(target.gallery.name) == true }
            let onDisk = { (try? ConfigService.loadConfig())?.videoRelations[target.video.filename]?.noGalleries.contains(target.gallery.name) == true }

            post("\u{7f}", keyCode: 51)
            await wait(0.6)
            check(appState.combinations.count == count - 1 && appState.combinationIndex == 0 && appState.currentCombination?.id != target.id, "⌫ removes the pairing and shows the next one in place")
            check(isExcluded() && onDisk(), "⌫ writes the gallery to excludedGalleries in pvorg.json")
            check(toasts.current?.actionTitle == "Undo", "Excluding shows a toast with Undo")

            post("z", keyCode: 6, modifiers: .command)
            await wait(0.6)
            check(appState.combinations.count == count && appState.currentCombination?.id == target.id && !isExcluded() && !onDisk(), "⌘Z restores the pairing and its saved decision")

            // Synthesized shift-combos don't match menu key equivalents reliably, so
            // redo goes through the real Edit menu item that carries ⇧⌘Z.
            let redo = menuItem("Edit", "Redo \(CommandContext.undoActionName)")
            check(redo?.isEnabled == true && redo?.keyEquivalent == "z" && redo?.keyEquivalentModifierMask == [.command, .shift], "Edit › Redo Exclude Pairing is enabled on ⇧⌘Z")
            if let redo, let menu = redo.menu {
                menu.performActionForItem(at: menu.index(of: redo))
            }
            await wait(0.6)
            check(appState.combinations.count == count - 1 && isExcluded(), "Redo excludes it again")

            post("z", keyCode: 6, modifiers: .command)
            await wait(0.6)
            check(!isExcluded() && !onDisk(), "⌘Z again leaves pvorg.json as it was")
            toasts.dismiss()
        }

        // Include Pairing: I writes "Yes" and keeps the pairing on screen; I again
        // marks it undecided; ⌘Z undoes each step.
        appState.showCombination(at: 0)
        await wait(0.5)
        if let target = appState.currentCombination {
            let count = appState.combinations.count
            let before = appState.config?.videoRelations[target.video.filename]
            let onDisk = { (try? ConfigService.loadConfig())?.videoRelations[target.video.filename]?.yesGalleries.contains(target.gallery.name) == true }
            let menuTitle = "Include “\(target.gallery.name)” for This Video"

            check(menuItem("Viewer", menuTitle)?.state == .off && menuItem("Viewer", menuTitle)?.keyEquivalent == "i", "Viewer › Include Pairing is unchecked and shows I")
            post("i")
            await wait(0.6)
            check(commands.isCurrentPairingIncluded && onDisk(), "I writes the gallery to galleries in pvorg.json")
            check(appState.combinations.count == count && appState.currentCombination?.id == target.id, "Including keeps the pairing on screen")
            check(toasts.current?.actionTitle == "Undo", "Including shows a toast with Undo")
            check(menuItem("Viewer", menuTitle)?.state == .on, "Viewer › Include Pairing is checked once included")

            post("i")
            await wait(0.6)
            check(!commands.isCurrentPairingIncluded && !onDisk(), "I again marks the pairing undecided")

            post("z", keyCode: 6, modifiers: .command)
            await wait(0.6)
            check(commands.isCurrentPairingIncluded && onDisk(), "⌘Z includes it again")
            post("z", keyCode: 6, modifiers: .command)
            await wait(0.6)
            let now = appState.config?.videoRelations[target.video.filename]
            let unchanged = (now == nil) == (before == nil) && now?.galleries == before?.galleries
                && now?.excludedGalleries == before?.excludedGalleries && now?.tags == before?.tags && now?.excludedTags == before?.excludedTags
            check(!onDisk() && unchanged, "⌘Z again leaves pvorg.json as it was")
            toasts.dismiss()
        }

        // Mapping save is reachable from the File menu.
        navigation.page = .galleryMapping
        await wait(0.8)
        check(menuItem("File", "Save Mapping Changes")?.keyEquivalent == "s", "⌘S is assigned to Save Mapping Changes")
        navigation.page = .viewer
        await wait(0.5)
    }

    // MARK: Helpers

    private var commands: CommandContext {
        CommandContext(appState: appState, navigation: navigation, viewer: viewer, mappings: mappings, toasts: toasts, keyboard: keyboard)
    }

    private var mainWindow: NSWindow? {
        NSApp.windows.first { $0.isVisible && $0.sheetParent == nil && $0.level == .normal && $0.toolbar != nil }
            ?? NSApp.windows.first { $0.isVisible && $0.sheetParent == nil && $0.level == .normal }
    }

    private func wait(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    private func shot(_ name: String, settle: Double = 0.8) async {
        await wait(settle)
        guard let window = mainWindow else { return }
        capture(window, name: name)
        for sheet in NSApp.windows where sheet.isVisible && sheet.sheetParent === window {
            capture(sheet, name: "\(name)-sheet")
        }
    }

    /// Captures one of the app's own windows. Own-window capture needs no
    /// Screen Recording permission, and unlike view snapshots it includes
    /// window-server materials such as the glass sidebar.
    private func capture(_ window: NSWindow, name: String) {
        typealias CreateImage = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
        guard let symbol = dlsym(dlopen(nil, RTLD_NOW), "CGWindowListCreateImage") else { return }
        let createImage = unsafeBitCast(symbol, to: CreateImage.self)
        // kCGWindowListOptionIncludingWindow, kCGWindowImageBoundsIgnoreFraming.
        guard let image = createImage(.null, 1 << 3, UInt32(window.windowNumber), 1 << 0)?.takeRetainedValue() else { return }
        let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        try? data?.write(to: output.appendingPathComponent("\(name).png"))
    }

    private func resizeMainWindow(to size: NSSize) {
        guard let window = mainWindow else { return }
        var frame = window.frame
        frame.origin.y += frame.height - size.height
        frame.size = size
        window.setFrame(frame, display: true, animate: false)
    }

    /// Posts a key press through the app's event queue, so it takes the real path.
    private func post(_ characters: String, keyCode: UInt16? = nil, modifiers: NSEvent.ModifierFlags = []) {
        guard let window = mainWindow else { return }
        let codes: [String: UInt16] = ["a": 0, "b": 11, "c": 8, "i": 34, "n": 45, "p": 35, "v": 9, " ": 49, "2": 19, "5": 23]
        for type in [NSEvent.EventType.keyDown, .keyUp] {
            guard let event = NSEvent.keyEvent(
                with: type,
                location: .zero,
                modifierFlags: modifiers,
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber,
                context: nil,
                characters: characters,
                charactersIgnoringModifiers: characters,
                isARepeat: false,
                keyCode: keyCode ?? codes[characters] ?? 0
            ) else { continue }
            NSApp.postEvent(event, atStart: false)
        }
    }

    /// Reads a menu item after letting SwiftUI refresh the menu, as AppKit
    /// does before showing a menu or matching a key equivalent.
    private func menuItem(_ menuTitle: String, _ title: String) -> NSMenuItem? {
        guard let menu = NSApp.mainMenu?.items.first(where: { $0.title == menuTitle })?.submenu else { return nil }
        menu.delegate?.menuNeedsUpdate?(menu)
        menu.update()
        return menu.items.first { $0.title == title }
    }

    private func key(_ menuTitle: String, _ title: String) -> String? {
        menuItem(menuTitle, title)?.keyEquivalent
    }

    private func openSettings() {
        let appMenu = NSApp.mainMenu?.items.first?.submenu
        guard let item = appMenu?.items.first(where: { $0.title.hasPrefix("Settings") }), let menu = item.menu else { return }
        menu.performActionForItem(at: menu.index(of: item))
    }

    private func searchField(in view: NSView?) -> NSSearchField? {
        guard let view else { return nil }
        if let field = view as? NSSearchField { return field }
        for subview in view.subviews {
            if let found = searchField(in: subview) { return found }
        }
        return nil
    }

    private func check(_ condition: Bool, _ description: String) {
        results.append("\(condition ? "PASS" : "FAIL")  \(description)")
    }

    private func finish() {
        let text = results.joined(separator: "\n") + "\n"
        try? text.write(to: output.appendingPathComponent("results.txt"), atomically: true, encoding: .utf8)
    }
}
#endif
