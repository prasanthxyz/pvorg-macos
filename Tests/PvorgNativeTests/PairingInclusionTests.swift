import AppKit
import Foundation
import XCTest
@testable import PvorgNative

@MainActor
final class PairingInclusionTests: XCTestCase {
    private var configURL: URL!

    override func setUp() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        configURL = root.appendingPathComponent("pvorg.json")
        setenv("PVORG_CONFIG", configURL.path, 1)
    }

    override func tearDown() async throws {
        unsetenv("PVORG_CONFIG")
        try? FileManager.default.removeItem(at: configURL.deletingLastPathComponent())
    }

    func testIncludingWritesYesAndKeepsTheCombinationInPlace() throws {
        let appState = makeAppState()
        appState.showCombination(at: 1)
        let target = try XCTUnwrap(appState.currentCombination)
        let order = appState.combinations.map(\.id)
        XCTAssertFalse(appState.isPairingIncluded(filename: target.video.filename, galleryName: target.gallery.name))

        let change = try appState.setPairingIncluded(true, filename: target.video.filename, galleryName: target.gallery.name)

        XCTAssertEqual(change.previousState, .undecided)
        XCTAssertTrue(change.included)
        XCTAssertEqual(appState.combinations.map(\.id), order, "The pairing was already shown; nothing moves")
        XCTAssertEqual(appState.currentCombination?.id, target.id)
        XCTAssertTrue(appState.isPairingIncluded(filename: target.video.filename, galleryName: target.gallery.name))
        let relation = try XCTUnwrap(appState.config?.videoRelations[target.video.filename])
        XCTAssertEqual(relation.galleries, [target.gallery.name])
        XCTAssertEqual(relation.excludedGalleries, [])
        XCTAssertEqual(relation.tags, [])
        XCTAssertEqual(relation.excludedTags, [])

        let saved = try ConfigService.loadConfig(from: configURL)
        XCTAssertEqual(saved.videoRelations[target.video.filename]?.galleries, [target.gallery.name])
    }

    func testIncludingKeepsTheVideosOtherDecisions() throws {
        let appState = makeAppState()
        let target = appState.combinations.first { $0.gallery.name == "G1" }!
        appState.config?.videoRelations[target.video.filename] = VideoRelation(
            galleries: ["G2"],
            excludedGalleries: [],
            tags: ["night"],
            excludedTags: ["4k"]
        )

        _ = try appState.setPairingIncluded(true, filename: target.video.filename, galleryName: "G1")

        let relation = try XCTUnwrap(appState.config?.videoRelations[target.video.filename])
        XCTAssertEqual(relation.galleries, ["G1", "G2"], "Gallery Mapping's column order")
        XCTAssertEqual(relation.tags, ["night"])
        XCTAssertEqual(relation.excludedTags, ["4k"])
    }

    func testClearingAnIncludedPairingMarksItUndecided() throws {
        let appState = makeAppState()
        let target = appState.combinations[0]
        appState.config?.videoRelations[target.video.filename] = VideoRelation(
            galleries: [target.gallery.name],
            excludedGalleries: [],
            tags: [],
            excludedTags: []
        )
        let order = appState.combinations.map(\.id)

        let change = try appState.setPairingIncluded(false, filename: target.video.filename, galleryName: target.gallery.name)

        XCTAssertEqual(change.previousState, .yes)
        XCTAssertFalse(change.included)
        XCTAssertEqual(appState.combinations.map(\.id), order, "An undecided pairing is still shown")
        XCTAssertFalse(appState.isPairingIncluded(filename: target.video.filename, galleryName: target.gallery.name))
        XCTAssertEqual(appState.config?.videoRelations[target.video.filename]?.galleries, [])
        XCTAssertEqual(appState.config?.videoRelations[target.video.filename]?.excludedGalleries, [])
        XCTAssertEqual(try ConfigService.loadConfig(from: configURL).videoRelations[target.video.filename]?.galleries, [])
    }

    func testRestoreRemovesTheEntryTheInclusionCreated() throws {
        let appState = makeAppState()
        let target = appState.combinations[2]

        let change = try appState.setPairingIncluded(true, filename: target.video.filename, galleryName: target.gallery.name)
        try appState.restorePairingDecision(change)

        XCTAssertNil(appState.config?.videoRelations[target.video.filename])
        XCTAssertNil(try ConfigService.loadConfig(from: configURL).videoRelations[target.video.filename])
        XCTAssertFalse(appState.isPairingIncluded(filename: target.video.filename, galleryName: target.gallery.name))
    }

    func testRestoreBringsBackTheEarlierYes() throws {
        let appState = makeAppState()
        let target = appState.combinations[0]
        appState.config?.videoRelations[target.video.filename] = VideoRelation(
            galleries: [target.gallery.name],
            excludedGalleries: [],
            tags: [],
            excludedTags: []
        )

        let change = try appState.setPairingIncluded(false, filename: target.video.filename, galleryName: target.gallery.name)
        try appState.restorePairingDecision(change)

        XCTAssertEqual(appState.config?.videoRelations[target.video.filename]?.galleries, [target.gallery.name])
        XCTAssertTrue(appState.isPairingIncluded(filename: target.video.filename, galleryName: target.gallery.name))
    }

    func testRestoreKeepsAnEntryThatOtherDecisionsNowUse() throws {
        let appState = makeAppState()
        let target = appState.combinations[0]
        let change = try appState.setPairingIncluded(true, filename: target.video.filename, galleryName: target.gallery.name)
        appState.config?.videoRelations[target.video.filename]?.excludedTags = ["night"]

        try appState.restorePairingDecision(change)

        XCTAssertEqual(appState.config?.videoRelations[target.video.filename]?.excludedTags, ["night"])
        XCTAssertEqual(appState.config?.videoRelations[target.video.filename]?.galleries, [])
    }

    func testAnExcludedPairingCantBeIncluded() throws {
        let appState = makeAppState()
        let target = appState.combinations[0]
        _ = try appState.excludePairing(filename: target.video.filename, galleryName: target.gallery.name)
        let before = appState.config

        XCTAssertThrowsError(try appState.setPairingIncluded(true, filename: target.video.filename, galleryName: target.gallery.name))
        XCTAssertEqual(appState.config?.videoRelations[target.video.filename]?.excludedGalleries, before?.videoRelations[target.video.filename]?.excludedGalleries)
        XCTAssertEqual(appState.config?.videoRelations[target.video.filename]?.galleries, [])
    }

    // MARK: The viewer command (👍, I, menus)

    func testIncludeCommandTogglesWithToastUndoAndRedo() throws {
        let (context, undo) = try makeViewerContext()
        let target = try XCTUnwrap(context.appState.currentCombination)
        let gallery = target.gallery.name
        let title = DisplayName.title(for: target.video)
        let included = { context.appState.isPairingIncluded(filename: target.video.filename, galleryName: gallery) }

        XCTAssertTrue(context.isAvailable(.includePairing))
        XCTAssertFalse(context.isCurrentPairingIncluded)

        perform(.includePairing, in: context, undo: undo)
        XCTAssertTrue(included())
        XCTAssertTrue(context.isCurrentPairingIncluded)
        XCTAssertEqual(context.appState.currentCombination?.id, target.id, "Including keeps the pairing on screen")
        XCTAssertEqual(context.toasts.current?.message, "Included “\(gallery)” for “\(title)”")
        XCTAssertEqual(context.toasts.current?.systemImage, "hand.thumbsup.fill")
        XCTAssertEqual(context.toasts.current?.actionTitle, "Undo")
        XCTAssertEqual(undo.undoActionName, CommandContext.includeActionName)

        // The toast's Undo is the same as ⌘Z.
        context.toasts.current?.action?()
        XCTAssertFalse(included())
        XCTAssertNil(context.appState.config?.videoRelations[target.video.filename], "pvorg.json is back as it was")
        XCTAssertEqual(context.toasts.current?.message, "Marked “\(gallery)” as undecided for “\(title)”")
        XCTAssertNil(context.toasts.current?.actionTitle, "A stale Undo never lingers")

        undo.redo()
        XCTAssertTrue(included())
        XCTAssertEqual(context.toasts.current?.actionTitle, "Undo")

        // On an included pairing, the same command clears it.
        perform(.includePairing, in: context, undo: undo)
        XCTAssertFalse(included())
        XCTAssertEqual(context.appState.config?.videoRelations[target.video.filename]?.galleries, [])
        XCTAssertEqual(context.toasts.current?.message, "Marked “\(gallery)” as undecided for “\(title)”")
        XCTAssertEqual(context.toasts.current?.systemImage, "hand.thumbsup")
        XCTAssertEqual(context.toasts.current?.actionTitle, "Undo")
        XCTAssertEqual(undo.undoActionName, CommandContext.clearIncludeActionName)

        undo.undo()
        XCTAssertTrue(included())
        XCTAssertEqual(context.toasts.current?.message, "Included “\(gallery)” for “\(title)”")
        XCTAssertNil(context.toasts.current?.actionTitle)
    }

    func testIncludingDiscardsAnUnsavedGalleryMappingEditOfThatCell() throws {
        let (context, undo) = try makeViewerContext()
        let target = try XCTUnwrap(context.appState.currentCombination)
        let session = context.mappings.galleries
        session.refresh(from: context.appState)
        let row = try XCTUnwrap(session.rows.first { $0.filename == target.video.filename })
        session.set(.no, for: row, column: target.gallery.name)
        session.set(.no, for: row, column: "G2" == target.gallery.name ? "G1" : "G2")

        perform(.includePairing, in: context, undo: undo)

        XCTAssertNil(session.pendingChanges[target.video.filename]?[target.gallery.name], "The viewer decision supersedes the unsaved edit")
        XCTAssertEqual(session.pendingChanges[target.video.filename]?.count, 1, "Other unsaved edits stay")
    }

    func testIncludeOnlyAppliesInTheViewer() throws {
        let (context, undo) = try makeViewerContext()
        let target = try XCTUnwrap(context.appState.currentCombination)
        context.navigation.page = .library

        XCTAssertFalse(context.isAvailable(.includePairing))
        perform(.includePairing, in: context, undo: undo)
        XCTAssertFalse(context.appState.isPairingIncluded(filename: target.video.filename, galleryName: target.gallery.name))
        XCTAssertNil(context.toasts.current)
    }

    /// Runs a command as one undo group, the way a key press or click would.
    private func perform(_ command: PlainKeyCommand, in context: CommandContext, undo: UndoManager) {
        undo.beginUndoGrouping()
        context.perform(command)
        undo.endUndoGrouping()
    }

    private func makeViewerContext() throws -> (CommandContext, UndoManager) {
        _ = NSApplication.shared
        let appState = makeAppState()
        appState.isReady = true
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200), styleMask: [.titled], backing: .buffered, defer: true)
        let keyboard = KeyboardContext()
        keyboard.mainWindow = window
        let undo = try XCTUnwrap(window.undoManager)
        undo.groupsByEvent = false
        let navigation = AppNavigation()
        navigation.page = .viewer
        let context = CommandContext(appState: appState, navigation: navigation, viewer: ViewerModel(), mappings: MappingStore(), toasts: ToastCenter(), keyboard: keyboard)
        return (context, undo)
    }

    private func makeAppState() -> AppState {
        let appState = AppState()
        appState.config = AppConfig(videosPath: "/tmp/videos", galleriesPath: "/tmp/galleries", tags: ["4k", "night"], videoRelations: [:])
        appState.galleries = [Gallery(name: "G1", imageFiles: []), Gallery(name: "G2", imageFiles: [])]
        appState.videos = [
            Video(filename: "acme-jane-one.mp4", studio: "acme", actors: ["jane"], title: "one", fileURL: URL(fileURLWithPath: "/tmp/1.mp4"), relatedGalleries: ["G1", "G2"], tags: []),
            Video(filename: "globex-sam-two.mp4", studio: "globex", actors: ["sam"], title: "two", fileURL: URL(fileURLWithPath: "/tmp/2.mp4"), relatedGalleries: ["G1", "G2"], tags: []),
        ]
        appState.resetFilters()
        XCTAssertEqual(appState.combinations.count, 4)
        return appState
    }
}
