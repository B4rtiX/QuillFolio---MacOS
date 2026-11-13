/*
 ╭───────────────────────────────────────────────────────────────────╮
 │   ██████╗     ██╗  ██╗    ██████╗   ████████╗  ██╗  ██╗  ██╗      │
 │   ██╔══██╗    ██║  ██║    ██╔══██╗  ╚══██╔══╝  ██║  ╚██╗██╔╝      │
 │   ██████╔╝    ███████║    ██████╔╝     ██║     ██║   ╚███╔╝       │
 │   ██╔══██╗    ╚════██║    ██╔══██╗     ██║     ██║   ██╔██╗       │
 │   ██████╔╝         ██║    ██║  ██║     ██║     ██║  ██╔╝ ██╗      │
 │   ╚═════╝          ╚═╝    ╚═╝  ╚═╝     ╚═╝     ╚═╝  ╚═╝  ╚═╝      │
 │                                                                   │
 │   Architect & Lead Developer: B4rtiX                              │
 │   Quillfolio (macOS Edition)                                      │
 ╰───────────────────────────────────────────────────────────────────╯
*/

import Foundation
import SwiftUI
import Combine

public final class DataStore: ObservableObject {
    @Published public var categories: [Category] = []
    @Published public var notes: [Note] = []
    
    // Selection state
    @Published public var selectedCategoryId: UUID? = nil
    @Published public var selectedSubcategoryId: UUID? = nil
    @Published public var selectedNoteId: UUID? = nil
    
    // Tool & Canvas State
    @Published public var selectedTool: DrawingTool = .pen
    @Published public var selectedShapeKind: ShapeKind = .auto
    @Published public var selectedColorHex: String = "#1E293B" // Slate 800
    @Published public var selectedWidth: Double = 3.0
    @Published public var autoCorrectShapes: Bool = true
    @Published public var drawAndHoldEnabled: Bool = true
    @Published public var isRulerVisible: Bool = false
    @Published public var zoomScale: CGFloat = 1.0
    
    // Tablet & Stylus State
    @Published public var currentStylusPressure: Double = 0.0
    @Published public var stylusDeviceName: String = "Gotowy (oczekiwanie na rysik)"
    @Published public var isStylusActive: Bool = false
    @Published public var pressureSensitivity: Double = 1.3
    @Published public var simulatePressureIfZero: Bool = true
    
    // Undo / Redo System
    public struct HistoryStep {
        public var noteId: UUID
        public var pageIndex: Int
        public var strokesBefore: [DrawingStroke]
        public var strokesAfter: [DrawingStroke]
    }
    private var undoStack: [HistoryStep] = []
    private var redoStack: [HistoryStep] = []
    @Published public var canUndo: Bool = false
    @Published public var canRedo: Bool = false
    
    // Lasso & Selection State
    @Published public var selectedStrokeIds: Set<UUID> = []
    @Published public var activeEditingStrokeId: UUID? = nil
    @Published public var activeEditingTextBoxId: UUID? = nil
    @Published public var activeEditingStickyId: UUID? = nil
    
    // Search & Filter
    @Published public var searchQuery: String = ""
    @Published public var filterFavoritesOnly: Bool = false
    @Published public var hoveredToolDescription: String? = nil
    @Published public var showHomeDashboard: Bool = false
    @Published public var showSettings: Bool = false
    
    // MARK: - Language & Localization
    @Published public var language: AppLanguage = {
        if let saved = UserDefaults.standard.string(forKey: "notatnik_app_language"),
           let lang = AppLanguage(rawValue: saved) {
            return lang
        }
        return .polish
    }() {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "notatnik_app_language")
            objectWillChange.send()
        }
    }
    
    public func t(_ pl: String, _ en: String) -> String {
        language == .polish ? pl : en
    }
    
    // MARK: - App Preferences
    @Published public var appTheme: String = UserDefaults.standard.string(forKey: "notatnik_app_theme") ?? "system" {
        didSet {
            UserDefaults.standard.set(appTheme, forKey: "notatnik_app_theme")
            applyAppTheme()
            objectWillChange.send()
        }
    }
    
    @Published public var defaultPaperStyle: PaperStyle = {
        if let raw = UserDefaults.standard.string(forKey: "notatnik_def_paper_style"),
           let style = PaperStyle(rawValue: raw) {
            return style
        }
        return .grid
    }() {
        didSet {
            UserDefaults.standard.set(defaultPaperStyle.rawValue, forKey: "notatnik_def_paper_style")
            objectWillChange.send()
        }
    }
    
    @Published public var defaultPaperColor: PaperColor = {
        if let raw = UserDefaults.standard.string(forKey: "notatnik_def_paper_color"),
           let color = PaperColor(rawValue: raw) {
            return color
        }
        return .white
    }() {
        didSet {
            UserDefaults.standard.set(defaultPaperColor.rawValue, forKey: "notatnik_def_paper_color")
            objectWillChange.send()
        }
    }
    
    @Published public var defaultDrawingTool: DrawingTool = {
        if let raw = UserDefaults.standard.string(forKey: "notatnik_def_tool"),
           let tool = DrawingTool(rawValue: raw) {
            return tool
        }
        return .pen
    }() {
        didSet {
            UserDefaults.standard.set(defaultDrawingTool.rawValue, forKey: "notatnik_def_tool")
            objectWillChange.send()
        }
    }
    
    @Published public var strokeSmoothingEnabled: Bool = UserDefaults.standard.object(forKey: "notatnik_stroke_smoothing") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(strokeSmoothingEnabled, forKey: "notatnik_stroke_smoothing")
            objectWillChange.send()
        }
    }
    
    @Published public var autoCorrectDelay: Double = UserDefaults.standard.double(forKey: "notatnik_autocorrect_delay") > 0 ? UserDefaults.standard.double(forKey: "notatnik_autocorrect_delay") : 0.45 {
        didSet {
            UserDefaults.standard.set(autoCorrectDelay, forKey: "notatnik_autocorrect_delay")
            objectWillChange.send()
        }
    }
    
    @Published public var defaultFontSize: Double = UserDefaults.standard.double(forKey: "notatnik_def_font_size") > 0 ? UserDefaults.standard.double(forKey: "notatnik_def_font_size") : 16.0 {
        didSet {
            UserDefaults.standard.set(defaultFontSize, forKey: "notatnik_def_font_size")
            objectWillChange.send()
        }
    }
    
    @Published public var defaultFontFamily: String = UserDefaults.standard.string(forKey: "notatnik_def_font_family") ?? "default" {
        didSet {
            UserDefaults.standard.set(defaultFontFamily, forKey: "notatnik_def_font_family")
            objectWillChange.send()
        }
    }
    
    @Published public var showSplashScreenOnLaunch: Bool = UserDefaults.standard.object(forKey: "notatnik_splash_screen") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(showSplashScreenOnLaunch, forKey: "notatnik_splash_screen")
            objectWillChange.send()
        }
    }
    
    public func applyAppTheme() {
        let app = NSApplication.shared
        switch appTheme {
        case "light":
            app.appearance = NSAppearance(named: .aqua)
        case "dark":
            app.appearance = NSAppearance(named: .darkAqua)
        default:
            app.appearance = nil
        }
    }
    
    public var storageDirectoryPath: String {
        storageURL.deletingLastPathComponent().path
    }
    
    public var totalStrokesCount: Int {
        notes.reduce(0) { total, note in
            total + note.pages.reduce(0) { $0 + $1.strokes.count }
        }
    }
    
    public var totalPagesCount: Int {
        notes.reduce(0) { $0 + $1.pages.count }
    }
    
    public func resetSettingsToDefaults() {
        language = .polish
        appTheme = "system"
        defaultPaperStyle = .grid
        defaultPaperColor = .white
        defaultDrawingTool = .pen
        pressureSensitivity = 1.3
        strokeSmoothingEnabled = true
        autoCorrectDelay = 0.45
        defaultFontSize = 16.0
        defaultFontFamily = "default"
        showSplashScreenOnLaunch = true
        applyAppTheme()
        objectWillChange.send()
    }
    
    // Undo stack for drawing
    private var undoHistory: [UUID: [[DrawingStroke]]] = [:]
    
    private let storageURL: URL
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Quillfolio", isDirectory: true)
        let oldDir = appSupport.appendingPathComponent("NotatnikStudio", isDirectory: true)
        
        // Migrate existing user notes seamlessly from old folder if needed
        if !FileManager.default.fileExists(atPath: dir.path) && FileManager.default.fileExists(atPath: oldDir.path) {
            try? FileManager.default.copyItem(at: oldDir, to: dir)
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        
        let newURL = dir.appendingPathComponent("quillfolio_data.json")
        let oldFileInDir = dir.appendingPathComponent("notatki_data.json")
        if !FileManager.default.fileExists(atPath: newURL.path) && FileManager.default.fileExists(atPath: oldFileInDir.path) {
            try? FileManager.default.moveItem(at: oldFileInDir, to: newURL)
        }
        
        self.storageURL = FileManager.default.fileExists(atPath: newURL.path) ? newURL : (FileManager.default.fileExists(atPath: oldFileInDir.path) ? oldFileInDir : newURL)
        
        loadFromDisk()
        
        if categories.isEmpty || notes.isEmpty {
            createSampleData()
            saveToDisk()
        }
        
        // Select first note if available
        if selectedNoteId == nil, let firstNote = notes.first {
            selectedNoteId = firstNote.id
            selectedCategoryId = firstNote.categoryId
            selectedSubcategoryId = firstNote.subcategoryId
        }
    }
    
    // MARK: - Current Selection Helpers
    
    public var selectedNote: Note? {
        get {
            notes.first(where: { $0.id == selectedNoteId })
        }
        set {
            guard let newValue = newValue, let index = notes.firstIndex(where: { $0.id == newValue.id }) else { return }
            notes[index] = newValue
            saveToDisk()
        }
    }
    
    public var filteredNotes: [Note] {
        var result = notes
        
        if filterFavoritesOnly {
            result = result.filter { $0.isFavorite }
        }
        
        if let subcatId = selectedSubcategoryId {
            result = result.filter { $0.subcategoryId == subcatId }
        } else if let catId = selectedCategoryId {
            result = result.filter { $0.categoryId == catId }
        }
        
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.classicNoteText.lowercased().contains(query) ||
                $0.tags.contains(where: { $0.lowercased().contains(query) })
            }
        }
        
        return result.sorted(by: { $0.updatedAt > $1.updatedAt })
    }
    
    // MARK: - Category Management
    
    public func addCategory(name: String, icon: String = "folder.fill", colorHex: String = "#0A84FF") {
        let newCat = Category(name: name, icon: icon, colorHex: colorHex)
        categories.append(newCat)
        selectedCategoryId = newCat.id
        selectedSubcategoryId = nil
        saveToDisk()
    }
    
    public func addSubcategory(to categoryId: UUID, name: String, icon: String = "folder", colorHex: String = "#30B0C7") {
        guard let index = categories.firstIndex(where: { $0.id == categoryId }) else { return }
        let subcat = Subcategory(name: name, icon: icon, colorHex: colorHex)
        categories[index].subcategories.append(subcat)
        selectedCategoryId = categoryId
        selectedSubcategoryId = subcat.id
        saveToDisk()
    }
    
    public func deleteCategory(id: UUID) {
        categories.removeAll(where: { $0.id == id })
        // Clear category reference on orphan notes
        for i in 0..<notes.count {
            if notes[i].categoryId == id {
                notes[i].categoryId = nil
                notes[i].subcategoryId = nil
            }
        }
        if selectedCategoryId == id {
            selectedCategoryId = nil
            selectedSubcategoryId = nil
        }
        saveToDisk()
    }
    
    public func deleteSubcategory(categoryId: UUID, subcategoryId: UUID) {
        guard let index = categories.firstIndex(where: { $0.id == categoryId }) else { return }
        categories[index].subcategories.removeAll(where: { $0.id == subcategoryId })
        for i in 0..<notes.count {
            if notes[i].subcategoryId == subcategoryId {
                notes[i].subcategoryId = nil
            }
        }
        if selectedSubcategoryId == subcategoryId {
            selectedSubcategoryId = nil
        }
        saveToDisk()
    }
    
    public func renameCategory(id: UUID, newName: String) {
        guard let idx = categories.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        categories[idx].name = trimmed
        saveToDisk()
        objectWillChange.send()
    }
    
    public func renameSubcategory(categoryId: UUID, subcategoryId: UUID, newName: String) {
        guard let cIdx = categories.firstIndex(where: { $0.id == categoryId }),
              let sIdx = categories[cIdx].subcategories.firstIndex(where: { $0.id == subcategoryId }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        categories[cIdx].subcategories[sIdx].name = trimmed
        saveToDisk()
        objectWillChange.send()
    }
    
    // MARK: - Note Management
    
    public func renameNote(id: UUID, newTitle: String) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        notes[idx].title = trimmed
        notes[idx].updatedAt = Date()
        saveToDisk()
        objectWillChange.send()
    }
    
    public func moveNote(noteId: UUID, toCategoryId: UUID?, toSubcategoryId: UUID?) {
        guard let idx = notes.firstIndex(where: { $0.id == noteId }) else { return }
        notes[idx].categoryId = toCategoryId
        notes[idx].subcategoryId = toSubcategoryId
        notes[idx].updatedAt = Date()
        saveToDisk()
        objectWillChange.send()
    }
    
    public func duplicateNote(id: UUID) {
        guard let original = notes.first(where: { $0.id == id }) else { return }
        var copy = original
        copy.id = UUID()
        copy.title = "\(original.title) (kopia)"
        copy.createdAt = Date()
        copy.updatedAt = Date()
        notes.insert(copy, at: 0)
        selectedNoteId = copy.id
        saveToDisk()
        objectWillChange.send()
    }
    
    @discardableResult
    public func createNote(
        title: String? = nil,
        paperStyle: PaperStyle? = nil,
        paperColor: PaperColor? = nil
    ) -> Note {
        let actualTitle = title ?? t("Nowa notatka", "New Note")
        let actualStyle = paperStyle ?? defaultPaperStyle
        let actualColor = paperColor ?? defaultPaperColor
        let newNote = Note(
            title: actualTitle,
            categoryId: selectedCategoryId,
            subcategoryId: selectedSubcategoryId,
            paperStyle: actualStyle,
            paperColor: actualColor
        )
        notes.insert(newNote, at: 0)
        selectedNoteId = newNote.id
        saveToDisk()
        return newNote
    }
    
    public func deleteNote(id: UUID) {
        notes.removeAll(where: { $0.id == id })
        if selectedNoteId == id {
            selectedNoteId = filteredNotes.first?.id
        }
        saveToDisk()
    }
    
    public func toggleFavorite(for noteId: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == noteId }) else { return }
        notes[index].isFavorite.toggle()
        notes[index].updatedAt = Date()
        saveToDisk()
    }
    
    public func updatePaperStyle(style: PaperStyle) {
        guard let id = selectedNoteId, let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].paperStyle = style
        notes[index].updatedAt = Date()
        saveToDisk()
    }
    
    public func updatePaperColor(color: PaperColor) {
        guard let id = selectedNoteId, let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].paperColor = color
        notes[index].updatedAt = Date()
        // If switching to dark paper, adapt default pen color
        if color.isDark {
            if selectedColorHex == "#1A1A1A" || selectedColorHex == "#1E293B" || selectedColorHex == "#000000" {
                selectedColorHex = "#FFFFFF"
            }
        } else {
            if selectedColorHex == "#FFFFFF" {
                selectedColorHex = "#1E293B"
            }
        }
        saveToDisk()
    }
    
    // MARK: - Page Management
    
    public func addPage(to noteId: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == noteId }) else { return }
        let nextIndex = notes[index].pages.count
        notes[index].pages.append(NotePage(pageIndex: nextIndex))
        notes[index].currentPageIndex = nextIndex
        notes[index].updatedAt = Date()
        saveToDisk()
    }
    
    public func deleteCurrentPage(from noteId: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == noteId }) else { return }
        guard notes[index].pages.count > 1 else {
            // Just clear strokes on the single page
            notes[index].pages[0].strokes.removeAll()
            notes[index].pages[0].textBoxes.removeAll()
            notes[index].pages[0].stickyNotes.removeAll()
            notes[index].pages[0].images.removeAll()
            saveToDisk()
            return
        }
        
        let cur = notes[index].currentPageIndex
        notes[index].pages.remove(at: cur)
        for i in 0..<notes[index].pages.count {
            notes[index].pages[i].pageIndex = i
        }
        notes[index].currentPageIndex = max(0, min(cur - 1, notes[index].pages.count - 1))
        notes[index].updatedAt = Date()
        saveToDisk()
    }
    
    public func changePage(to newIndex: Int) {
        guard let id = selectedNoteId, let index = notes.firstIndex(where: { $0.id == id }) else { return }
        guard newIndex >= 0 && newIndex < notes[index].pages.count else { return }
        notes[index].currentPageIndex = newIndex
        objectWillChange.send()
    }
    
    // MARK: - Strokes, History, Undo & Redo
    
    private func updateCanUndoRedo() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
    
    public func addStroke(_ stroke: DrawingStroke) {
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        let before = notes[noteIndex].pages[pageIdx].strokes
        var after = before
        after.append(stroke)
        
        undoStack.append(HistoryStep(noteId: id, pageIndex: pageIdx, strokesBefore: before, strokesAfter: after))
        redoStack.removeAll()
        updateCanUndoRedo()
        
        notes[noteIndex].pages[pageIdx].strokes = after
        notes[noteIndex].updatedAt = Date()
        
        // If it's a recognized shape, select it immediately so user can edit size/direction!
        if stroke.recognizedShape != nil {
            activeEditingStrokeId = stroke.id
            selectedStrokeIds = [stroke.id]
        }
        
        saveToDisk()
        objectWillChange.send()
    }
    
    public func deleteStrokes(ids: Set<UUID>) {
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        let before = notes[noteIndex].pages[pageIdx].strokes
        let after = before.filter { !ids.contains($0.id) }
        guard after.count != before.count else { return }
        
        undoStack.append(HistoryStep(noteId: id, pageIndex: pageIdx, strokesBefore: before, strokesAfter: after))
        redoStack.removeAll()
        updateCanUndoRedo()
        
        notes[noteIndex].pages[pageIdx].strokes = after
        notes[noteIndex].updatedAt = Date()
        selectedStrokeIds.subtract(ids)
        if let active = activeEditingStrokeId, ids.contains(active) {
            activeEditingStrokeId = nil
        }
        
        saveToDisk()
        objectWillChange.send()
    }
    
    public func undo() {
        guard let step = undoStack.popLast() else { return }
        guard let noteIdx = notes.firstIndex(where: { $0.id == step.noteId }) else { return }
        guard step.pageIndex < notes[noteIdx].pages.count else { return }
        
        let currentStrokes = notes[noteIdx].pages[step.pageIndex].strokes
        redoStack.append(HistoryStep(noteId: step.noteId, pageIndex: step.pageIndex, strokesBefore: currentStrokes, strokesAfter: step.strokesAfter))
        
        notes[noteIdx].pages[step.pageIndex].strokes = step.strokesBefore
        notes[noteIdx].updatedAt = Date()
        selectedStrokeIds.removeAll()
        activeEditingStrokeId = nil
        
        updateCanUndoRedo()
        saveToDisk()
        objectWillChange.send()
    }
    
    public func redo() {
        guard let step = redoStack.popLast() else { return }
        guard let noteIdx = notes.firstIndex(where: { $0.id == step.noteId }) else { return }
        guard step.pageIndex < notes[noteIdx].pages.count else { return }
        
        let currentStrokes = notes[noteIdx].pages[step.pageIndex].strokes
        undoStack.append(HistoryStep(noteId: step.noteId, pageIndex: step.pageIndex, strokesBefore: currentStrokes, strokesAfter: step.strokesAfter))
        
        notes[noteIdx].pages[step.pageIndex].strokes = step.strokesAfter
        notes[noteIdx].updatedAt = Date()
        selectedStrokeIds.removeAll()
        activeEditingStrokeId = nil
        
        updateCanUndoRedo()
        saveToDisk()
        objectWillChange.send()
    }
    
    public func undoLastStroke() {
        undo()
    }
    
    public func togglePenEraser() {
        if selectedTool == .eraser {
            selectedTool = .pen
        } else {
            selectedTool = .eraser
        }
    }
    
    public func zoomIn() {
        let newZoom = min(3.0, (round((zoomScale + 0.15) * 100)) / 100.0)
        zoomScale = newZoom
        objectWillChange.send()
    }
    
    public func zoomOut() {
        let newZoom = max(0.4, (round((zoomScale - 0.15) * 100)) / 100.0)
        zoomScale = newZoom
        objectWillChange.send()
    }
    
    public func zoomReset() {
        zoomScale = 1.0
        objectWillChange.send()
    }
    
    public func clearCurrentPageCanvas() {
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        let before = notes[noteIndex].pages[pageIdx].strokes
        guard !before.isEmpty else { return }
        
        undoStack.append(HistoryStep(noteId: id, pageIndex: pageIdx, strokesBefore: before, strokesAfter: []))
        redoStack.removeAll()
        updateCanUndoRedo()
        
        notes[noteIndex].pages[pageIdx].strokes.removeAll()
        notes[noteIndex].updatedAt = Date()
        selectedStrokeIds.removeAll()
        activeEditingStrokeId = nil
        saveToDisk()
        objectWillChange.send()
    }
    
    public func selectAllStrokes() {
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        selectedStrokeIds = Set(notes[noteIndex].pages[pageIdx].strokes.map { $0.id })
        activeEditingStrokeId = nil
        objectWillChange.send()
    }
    
    // MARK: - Shape Insertion & Customization
    
    public func insertShape(kind: ShapeKind, at center: CGPoint = CGPoint(x: 350, y: 320), size: CGSize? = nil) {
        let actualSize: CGSize
        if let s = size {
            actualSize = s
        } else {
            switch kind {
            case .square:
                actualSize = CGSize(width: 160, height: 160)
            case .circle:
                actualSize = CGSize(width: 160, height: 160)
            case .roundedRectangle:
                actualSize = CGSize(width: 200, height: 130)
            case .rectangle:
                actualSize = CGSize(width: 210, height: 130)
            case .cloud:
                actualSize = CGSize(width: 220, height: 140)
            case .hexagon:
                actualSize = CGSize(width: 160, height: 160)
            case .triangle:
                actualSize = CGSize(width: 180, height: 150)
            case .rhombus:
                actualSize = CGSize(width: 160, height: 160)
            case .trapezoid:
                actualSize = CGSize(width: 200, height: 130)
            case .rightTrapezoid, .rightTrapezoidRight:
                actualSize = CGSize(width: 200, height: 130)
            case .stretchedHexagon:
                actualSize = CGSize(width: 220, height: 120)
            default:
                actualSize = CGSize(width: 200, height: 140)
            }
        }
        
        let bounds = CGRect(x: center.x - actualSize.width/2.0, y: center.y - actualSize.height/2.0, width: actualSize.width, height: actualSize.height)
        let start = CGPoint(x: bounds.minX, y: bounds.midY)
        let end = CGPoint(x: bounds.maxX, y: bounds.midY)
        
        var extraPoints: [StrokePoint] = []
        if kind == .rhombus {
            extraPoints = [
                StrokePoint(x: Double(bounds.midX), y: Double(bounds.minY)),
                StrokePoint(x: Double(bounds.maxX), y: Double(bounds.midY)),
                StrokePoint(x: Double(bounds.midX), y: Double(bounds.maxY)),
                StrokePoint(x: Double(bounds.minX), y: Double(bounds.midY))
            ]
        } else if kind == .parallelogram {
            let skew = bounds.width * 0.25
            extraPoints = [
                StrokePoint(x: Double(bounds.minX + skew), y: Double(bounds.minY)),
                StrokePoint(x: Double(bounds.maxX), y: Double(bounds.minY)),
                StrokePoint(x: Double(bounds.maxX - skew), y: Double(bounds.maxY)),
                StrokePoint(x: Double(bounds.minX), y: Double(bounds.maxY))
            ]
        } else if kind == .trapezoid {
            let inset = bounds.width * 0.22
            extraPoints = [
                StrokePoint(x: Double(bounds.minX + inset), y: Double(bounds.minY)),
                StrokePoint(x: Double(bounds.maxX - inset), y: Double(bounds.minY)),
                StrokePoint(x: Double(bounds.maxX), y: Double(bounds.maxY)),
                StrokePoint(x: Double(bounds.minX), y: Double(bounds.maxY))
            ]
        } else if kind == .rightTrapezoid {
            let topW = bounds.width * 0.65
            extraPoints = [
                StrokePoint(x: Double(bounds.minX), y: Double(bounds.minY)),
                StrokePoint(x: Double(bounds.minX + topW), y: Double(bounds.minY)),
                StrokePoint(x: Double(bounds.maxX), y: Double(bounds.maxY)),
                StrokePoint(x: Double(bounds.minX), y: Double(bounds.maxY))
            ]
        } else if kind == .rightTrapezoidRight {
            let topW = bounds.width * 0.65
            extraPoints = [
                StrokePoint(x: Double(bounds.maxX - topW), y: Double(bounds.minY)),
                StrokePoint(x: Double(bounds.maxX), y: Double(bounds.minY)),
                StrokePoint(x: Double(bounds.maxX), y: Double(bounds.maxY)),
                StrokePoint(x: Double(bounds.minX), y: Double(bounds.maxY))
            ]
        } else if kind == .triangle {
            extraPoints = [
                StrokePoint(x: Double(bounds.midX), y: Double(bounds.minY)),
                StrokePoint(x: Double(bounds.maxX), y: Double(bounds.maxY)),
                StrokePoint(x: Double(bounds.minX), y: Double(bounds.maxY))
            ]
        } else if kind == .hexagon {
            let r = min(actualSize.width, actualSize.height) / 2.0
            for i in 0..<6 {
                let a = CGFloat(i) * (.pi / 3.0)
                extraPoints.append(StrokePoint(x: Double(center.x + r * cos(a)), y: Double(center.y + r * sin(a))))
            }
        } else if kind == .stretchedHexagon {
            let inset = bounds.width * 0.22
            extraPoints = [
                StrokePoint(x: Double(bounds.minX), y: Double(bounds.midY)),
                StrokePoint(x: Double(bounds.minX + inset), y: Double(bounds.minY)),
                StrokePoint(x: Double(bounds.maxX - inset), y: Double(bounds.minY)),
                StrokePoint(x: Double(bounds.maxX), y: Double(bounds.midY)),
                StrokePoint(x: Double(bounds.maxX - inset), y: Double(bounds.maxY)),
                StrokePoint(x: Double(bounds.minX + inset), y: Double(bounds.maxY))
            ]
        }
        
        let shapeData = GeometricShapeData(
            kind: kind,
            start: (kind == .line || kind == .arrow || kind == .doubleArrow) ? CGPoint(x: bounds.minX, y: bounds.midY) : start,
            end: (kind == .line || kind == .arrow || kind == .doubleArrow) ? CGPoint(x: bounds.maxX, y: bounds.midY) : end,
            bounds: bounds,
            hasArrowStart: kind == .doubleArrow,
            hasArrowEnd: kind == .arrow || kind == .doubleArrow,
            extraPoints: extraPoints
        )
        
        var strokeColor = selectedColorHex
        if selectedNote?.paperColor.isDark == true && (selectedColorHex == "#1E293B" || selectedColorHex == "#1A1A1A" || selectedColorHex == "#000000") {
            strokeColor = "#FFFFFF"
        }
        
        let stroke = DrawingStroke(
            tool: .shape,
            colorHex: strokeColor,
            baseWidth: selectedWidth,
            isAutoCorrected: true,
            recognizedShape: shapeData
        )
        
        addStroke(stroke)
    }
    
    public func insertTableShape(rows: Int = 3, cols: Int = 3, at center: CGPoint = CGPoint(x: 400, y: 320)) {
        let width = CGFloat(max(1, cols) * 85)
        let height = CGFloat(max(1, rows) * 36)
        let bounds = CGRect(x: center.x - width / 2.0, y: center.y - height / 2.0, width: width, height: height)
        
        var shape = GeometricShapeData(
            kind: .table,
            start: CGPoint(x: bounds.minX, y: bounds.minY),
            end: CGPoint(x: bounds.maxX, y: bounds.maxY),
            bounds: bounds
        )
        shape.startPointX = Double(cols)
        shape.startPointY = Double(rows)
        
        let stroke = DrawingStroke(
            tool: .shape,
            colorHex: selectedColorHex,
            baseWidth: max(1.5, selectedWidth),
            opacity: 1.0,
            points: [],
            isAutoCorrected: true,
            recognizedShape: shape
        )
        addStroke(stroke)
        selectedStrokeIds = [stroke.id]
        activeEditingStrokeId = stroke.id
    }
    
    // MARK: - Clipboard (Command+C, Command+V)
    
    public var copiedStrokes: [DrawingStroke] = []
    public var copiedTextBox: CanvasTextBox? = nil
    public var copiedStickyNote: StickyNote? = nil
    
    public func copySelection() {
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        let page = notes[noteIndex].pages[pageIdx]
        
        if !selectedStrokeIds.isEmpty {
            copiedStrokes = page.strokes.filter { selectedStrokeIds.contains($0.id) }
            copiedTextBox = nil
            copiedStickyNote = nil
        } else if let boxId = activeEditingTextBoxId, let box = page.textBoxes.first(where: { $0.id == boxId }) {
            copiedTextBox = box
            copiedStrokes = []
            copiedStickyNote = nil
        } else if let stickyId = activeEditingStickyId, let st = page.stickyNotes.first(where: { $0.id == stickyId }) {
            copiedStickyNote = st
            copiedStrokes = []
            copiedTextBox = nil
        }
    }
    
    public func pasteClipboard() {
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        if !copiedStrokes.isEmpty {
            let before = notes[noteIndex].pages[pageIdx].strokes
            var newSelectedIds = Set<UUID>()
            for stroke in copiedStrokes {
                var pasted = stroke
                pasted.id = UUID()
                let offset: Double = 30.0
                if var shape = pasted.recognizedShape {
                    shape.startPointX += offset
                    shape.startPointY += offset
                    shape.endPointX += offset
                    shape.endPointY += offset
                    shape.boundsX += offset
                    shape.boundsY += offset
                    shape.extraPoints = shape.extraPoints.map { StrokePoint(x: $0.x + offset, y: $0.y + offset, pressure: $0.pressure) }
                    pasted.recognizedShape = shape
                }
                pasted.points = pasted.points.map { StrokePoint(x: $0.x + offset, y: $0.y + offset, pressure: $0.pressure) }
                notes[noteIndex].pages[pageIdx].strokes.append(pasted)
                newSelectedIds.insert(pasted.id)
            }
            let after = notes[noteIndex].pages[pageIdx].strokes
            undoStack.append(HistoryStep(noteId: id, pageIndex: pageIdx, strokesBefore: before, strokesAfter: after))
            redoStack.removeAll()
            updateCanUndoRedo()
            
            selectedStrokeIds = newSelectedIds
            activeEditingStrokeId = newSelectedIds.count == 1 ? newSelectedIds.first : nil
            notes[noteIndex].updatedAt = Date()
            saveToDisk()
            objectWillChange.send()
        } else if let box = copiedTextBox {
            var pasted = box
            pasted.id = UUID()
            pasted.x += 30
            pasted.y += 30
            notes[noteIndex].pages[pageIdx].textBoxes.append(pasted)
            activeEditingTextBoxId = pasted.id
            notes[noteIndex].updatedAt = Date()
            saveToDisk()
            objectWillChange.send()
        } else if let st = copiedStickyNote {
            var pasted = st
            pasted.id = UUID()
            pasted.x += 30
            pasted.y += 30
            notes[noteIndex].pages[pageIdx].stickyNotes.append(pasted)
            activeEditingStickyId = pasted.id
            notes[noteIndex].updatedAt = Date()
            saveToDisk()
            objectWillChange.send()
        }
    }
    
    public func reverseArrow(for strokeId: UUID) {
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        let before = notes[noteIndex].pages[pageIdx].strokes
        var after = before
        if let idx = after.firstIndex(where: { $0.id == strokeId }) {
            after[idx].recognizedShape?.reverseArrowDirection()
            undoStack.append(HistoryStep(noteId: id, pageIndex: pageIdx, strokesBefore: before, strokesAfter: after))
            redoStack.removeAll()
            updateCanUndoRedo()
            notes[noteIndex].pages[pageIdx].strokes = after
            notes[noteIndex].updatedAt = Date()
            saveToDisk()
            objectWillChange.send()
        }
    }
    
    public func updateShapeBounds(strokeId: UUID, newBounds: CGRect) {
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        if let idx = notes[noteIndex].pages[pageIdx].strokes.firstIndex(where: { $0.id == strokeId }) {
            notes[noteIndex].pages[pageIdx].strokes[idx].recognizedShape?.updateBounds(newBounds)
            notes[noteIndex].updatedAt = Date()
            saveToDisk()
            objectWillChange.send()
        }
    }
    
    // MARK: - Lasso Selection Operations
    
    public func moveSelectedStrokes(by delta: CGSize) {
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        for i in 0..<notes[noteIndex].pages[pageIdx].strokes.count {
            if selectedStrokeIds.contains(notes[noteIndex].pages[pageIdx].strokes[i].id) {
                notes[noteIndex].pages[pageIdx].strokes[i].translate(by: delta)
            }
        }
        notes[noteIndex].updatedAt = Date()
        saveToDisk()
        objectWillChange.send()
    }
    
    public func scaleSelectedStrokes(factorX: CGFloat, factorY: CGFloat, anchor: CGPoint) {
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        for i in 0..<notes[noteIndex].pages[pageIdx].strokes.count {
            if selectedStrokeIds.contains(notes[noteIndex].pages[pageIdx].strokes[i].id) {
                notes[noteIndex].pages[pageIdx].strokes[i].scale(factorX: factorX, factorY: factorY, anchor: anchor)
            }
        }
        notes[noteIndex].updatedAt = Date()
        saveToDisk()
        objectWillChange.send()
    }
    
    public func deleteSelectedStrokes() {
        deleteStrokes(ids: selectedStrokeIds)
        selectedStrokeIds.removeAll()
        activeEditingStrokeId = nil
    }
    
    public func duplicateSelectedStrokes() {
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        var newStrokes: [DrawingStroke] = []
        var newIds: Set<UUID> = []
        for s in notes[noteIndex].pages[pageIdx].strokes {
            if selectedStrokeIds.contains(s.id) {
                var copy = s
                copy.id = UUID()
                copy.translate(by: CGSize(width: 30, height: 30))
                newStrokes.append(copy)
                newIds.insert(copy.id)
            }
        }
        guard !newStrokes.isEmpty else { return }
        
        let before = notes[noteIndex].pages[pageIdx].strokes
        var after = before
        after.append(contentsOf: newStrokes)
        
        undoStack.append(HistoryStep(noteId: id, pageIndex: pageIdx, strokesBefore: before, strokesAfter: after))
        redoStack.removeAll()
        updateCanUndoRedo()
        
        notes[noteIndex].pages[pageIdx].strokes = after
        selectedStrokeIds = newIds
        notes[noteIndex].updatedAt = Date()
        saveToDisk()
        objectWillChange.send()
    }
    
    public func changeSelectedStrokesColor(hex: String) {
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        for i in 0..<notes[noteIndex].pages[pageIdx].strokes.count {
            if selectedStrokeIds.contains(notes[noteIndex].pages[pageIdx].strokes[i].id) {
                notes[noteIndex].pages[pageIdx].strokes[i].colorHex = hex
            }
        }
        notes[noteIndex].updatedAt = Date()
        saveToDisk()
        objectWillChange.send()
    }
    
    public func addTextBox(x: Double, y: Double, text: String = "Kliknij, aby edytować...") {
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        let box = CanvasTextBox(
            text: text,
            x: x,
            y: y,
            textColorHex: selectedNote?.paperColor.isDark == true ? "#FFFFFF" : "#1E293B"
        )
        notes[noteIndex].pages[pageIdx].textBoxes.append(box)
        notes[noteIndex].updatedAt = Date()
        activeEditingTextBoxId = box.id
        activeEditingStickyId = nil
        saveToDisk()
        objectWillChange.send()
    }
    
    public func updateTextBox(_ box: CanvasTextBox) {
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        if let boxIndex = notes[noteIndex].pages[pageIdx].textBoxes.firstIndex(where: { $0.id == box.id }) {
            notes[noteIndex].pages[pageIdx].textBoxes[boxIndex] = box
            notes[noteIndex].updatedAt = Date()
            saveToDisk()
            objectWillChange.send()
        }
    }
    
    public func deleteTextBox(id boxId: UUID) {
        if activeEditingTextBoxId == boxId {
            activeEditingTextBoxId = nil
        }
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        notes[noteIndex].pages[pageIdx].textBoxes.removeAll(where: { $0.id == boxId })
        notes[noteIndex].updatedAt = Date()
        saveToDisk()
        objectWillChange.send()
    }
    
    public func addStickyNote(x: Double, y: Double, colorHex: String = "#FFF475") {
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        let sticky = StickyNote(x: x, y: y, colorHex: colorHex)
        notes[noteIndex].pages[pageIdx].stickyNotes.append(sticky)
        notes[noteIndex].updatedAt = Date()
        activeEditingStickyId = sticky.id
        activeEditingTextBoxId = nil
        saveToDisk()
        objectWillChange.send()
    }
    
    public func updateStickyNote(_ sticky: StickyNote) {
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        if let idx = notes[noteIndex].pages[pageIdx].stickyNotes.firstIndex(where: { $0.id == sticky.id }) {
            notes[noteIndex].pages[pageIdx].stickyNotes[idx] = sticky
            notes[noteIndex].updatedAt = Date()
            saveToDisk()
            objectWillChange.send()
        }
    }
    
    public func deleteStickyNote(id stickyId: UUID) {
        if activeEditingStickyId == stickyId {
            activeEditingStickyId = nil
        }
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        notes[noteIndex].pages[pageIdx].stickyNotes.removeAll(where: { $0.id == stickyId })
        notes[noteIndex].updatedAt = Date()
        saveToDisk()
        objectWillChange.send()
    }
    
    // MARK: - Canvas Image Operations
    
    public func addImage(data: Data, at center: CGPoint = CGPoint(x: 350, y: 300), size: CGSize? = nil) {
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        var finalWidth: Double = 320
        var finalHeight: Double = 220
        if let nsImage = NSImage(data: data) {
            let rep = nsImage.representations.first
            let pixelWidth = CGFloat(rep?.pixelsWide ?? Int(nsImage.size.width))
            let pixelHeight = CGFloat(rep?.pixelsHigh ?? Int(nsImage.size.height))
            if pixelWidth > 0 && pixelHeight > 0 {
                let maxDim: CGFloat = 360
                if pixelWidth > pixelHeight {
                    finalWidth = Double(min(maxDim, pixelWidth))
                    finalHeight = Double(finalWidth * (pixelHeight / pixelWidth))
                } else {
                    finalHeight = Double(min(maxDim, pixelHeight))
                    finalWidth = Double(finalHeight * (pixelWidth / pixelHeight))
                }
            }
        }
        if let explicitSize = size {
            finalWidth = Double(explicitSize.width)
            finalHeight = Double(explicitSize.height)
        }
        
        let canvasImg = CanvasImage(
            imageData: data,
            x: Double(center.x) - finalWidth / 2.0,
            y: Double(center.y) - finalHeight / 2.0,
            width: finalWidth,
            height: finalHeight
        )
        
        notes[noteIndex].pages[pageIdx].images.append(canvasImg)
        notes[noteIndex].updatedAt = Date()
        saveToDisk()
        objectWillChange.send()
    }
    
    public func updateImage(_ img: CanvasImage) {
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        if let idx = notes[noteIndex].pages[pageIdx].images.firstIndex(where: { $0.id == img.id }) {
            notes[noteIndex].pages[pageIdx].images[idx] = img
            notes[noteIndex].updatedAt = Date()
            saveToDisk()
            objectWillChange.send()
        }
    }
    
    public func deleteImage(id: UUID) {
        guard let noteId = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == noteId }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        notes[noteIndex].pages[pageIdx].images.removeAll(where: { $0.id == id })
        notes[noteIndex].updatedAt = Date()
        saveToDisk()
        objectWillChange.send()
    }
    
    // MARK: - Canvas Table Operations
    
    public func addTable(x: Double, y: Double, rows: Int = 3, cols: Int = 3) {
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        let table = CanvasTable(x: x, y: y, rows: rows, cols: cols)
        notes[noteIndex].pages[pageIdx].tables.append(table)
        notes[noteIndex].updatedAt = Date()
        saveToDisk()
        objectWillChange.send()
    }
    
    public func updateTable(_ table: CanvasTable) {
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        if let idx = notes[noteIndex].pages[pageIdx].tables.firstIndex(where: { $0.id == table.id }) {
            notes[noteIndex].pages[pageIdx].tables[idx] = table
            notes[noteIndex].updatedAt = Date()
            saveToDisk()
            objectWillChange.send()
        }
    }
    
    public func deleteTable(id: UUID) {
        guard let idNote = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == idNote }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        notes[noteIndex].pages[pageIdx].tables.removeAll(where: { $0.id == id })
        notes[noteIndex].updatedAt = Date()
        saveToDisk()
        objectWillChange.send()
    }
    
    public func changeActiveTextIndent(delta: Int) {
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        if let boxId = activeEditingTextBoxId,
           let idx = notes[noteIndex].pages[pageIdx].textBoxes.firstIndex(where: { $0.id == boxId }) {
            let cur = notes[noteIndex].pages[pageIdx].textBoxes[idx].indentLevel
            notes[noteIndex].pages[pageIdx].textBoxes[idx].indentLevel = max(0, min(8, cur + delta))
            notes[noteIndex].updatedAt = Date()
            saveToDisk()
            objectWillChange.send()
        }
    }
    
    public func insertSymbolIntoActiveText(_ symbol: String) {
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        if let boxId = activeEditingTextBoxId,
           let idx = notes[noteIndex].pages[pageIdx].textBoxes.firstIndex(where: { $0.id == boxId }) {
            notes[noteIndex].pages[pageIdx].textBoxes[idx].text += symbol
            notes[noteIndex].updatedAt = Date()
            saveToDisk()
            objectWillChange.send()
            return
        }
        
        if let stickyId = activeEditingStickyId,
           let idx = notes[noteIndex].pages[pageIdx].stickyNotes.firstIndex(where: { $0.id == stickyId }) {
            notes[noteIndex].pages[pageIdx].stickyNotes[idx].text += symbol
            notes[noteIndex].updatedAt = Date()
            saveToDisk()
            objectWillChange.send()
        }
    }
    
    // MARK: - Rich Text Formatting on Active Text Box / Sticky Note
    
    public func updateActiveTextFormatting(
        fontDesign: String? = nil,
        fontSize: Double? = nil,
        toggleBold: Bool = false,
        toggleItalic: Bool = false,
        toggleUnderline: Bool = false,
        toggleStrikethrough: Bool = false,
        alignment: String? = nil,
        listType: String? = nil,
        textColorHex: String? = nil
    ) {
        guard let id = selectedNoteId, let noteIndex = notes.firstIndex(where: { $0.id == id }) else { return }
        let pageIdx = notes[noteIndex].currentPageIndex
        guard pageIdx < notes[noteIndex].pages.count else { return }
        
        if let boxId = activeEditingTextBoxId,
           let idx = notes[noteIndex].pages[pageIdx].textBoxes.firstIndex(where: { $0.id == boxId }) {
            if let fd = fontDesign { notes[noteIndex].pages[pageIdx].textBoxes[idx].fontDesign = fd }
            if let fs = fontSize { notes[noteIndex].pages[pageIdx].textBoxes[idx].fontSize = fs }
            if toggleBold { notes[noteIndex].pages[pageIdx].textBoxes[idx].isBold.toggle() }
            if toggleItalic { notes[noteIndex].pages[pageIdx].textBoxes[idx].isItalic.toggle() }
            if toggleUnderline { notes[noteIndex].pages[pageIdx].textBoxes[idx].isUnderline.toggle() }
            if toggleStrikethrough { notes[noteIndex].pages[pageIdx].textBoxes[idx].isStrikethrough.toggle() }
            if let al = alignment { notes[noteIndex].pages[pageIdx].textBoxes[idx].textAlignment = al }
            if let lt = listType {
                let cur = notes[noteIndex].pages[pageIdx].textBoxes[idx].listType
                notes[noteIndex].pages[pageIdx].textBoxes[idx].listType = (cur == lt ? "none" : lt)
            }
            if let tc = textColorHex { notes[noteIndex].pages[pageIdx].textBoxes[idx].textColorHex = tc }
            notes[noteIndex].updatedAt = Date()
            saveToDisk()
            objectWillChange.send()
            return
        }
        
        if let stickyId = activeEditingStickyId,
           let idx = notes[noteIndex].pages[pageIdx].stickyNotes.firstIndex(where: { $0.id == stickyId }) {
            if let fd = fontDesign { notes[noteIndex].pages[pageIdx].stickyNotes[idx].fontDesign = fd }
            if let fs = fontSize { notes[noteIndex].pages[pageIdx].stickyNotes[idx].fontSize = fs }
            if toggleBold { notes[noteIndex].pages[pageIdx].stickyNotes[idx].isBold.toggle() }
            if toggleItalic { notes[noteIndex].pages[pageIdx].stickyNotes[idx].isItalic.toggle() }
            if toggleUnderline { notes[noteIndex].pages[pageIdx].stickyNotes[idx].isUnderline.toggle() }
            if let al = alignment { notes[noteIndex].pages[pageIdx].stickyNotes[idx].textAlignment = al }
            if let lt = listType {
                let cur = notes[noteIndex].pages[pageIdx].stickyNotes[idx].listType
                notes[noteIndex].pages[pageIdx].stickyNotes[idx].listType = (cur == lt ? "none" : lt)
            }
            notes[noteIndex].updatedAt = Date()
            saveToDisk()
            objectWillChange.send()
        }
    }
    
    // MARK: - Persistence
    
    private struct StorageContainer: Codable {
        var categories: [Category]
        var notes: [Note]
    }
    
    public func saveToDisk() {
        let parentDir = storageURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        let container = StorageContainer(categories: categories, notes: notes)
        do {
            let data = try JSONEncoder().encode(container)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Błąd zapisu danych: \(error)")
        }
    }
    
    public func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let container = try JSONDecoder().decode(StorageContainer.self, from: data)
            self.categories = container.categories
            self.notes = container.notes
        } catch {
            print("Błąd wczytywania danych: \(error)")
        }
    }
    
    // MARK: - Sample Pre-population
    
    private func createSampleData() {
        let subcatMat = Subcategory(name: "Matematyka i Geometria", icon: "function", colorHex: "#5856D6")
        let subcatInf = Subcategory(name: "Informatyka & Algorytmy", icon: "chevron.left.forwardslash.chevron.right", colorHex: "#007AFF")
        let subcatFiz = Subcategory(name: "Fizyka", icon: "atom", colorHex: "#AF52DE")
        let catStudia = Category(name: "Studia & Nauka", icon: "graduationcap.fill", colorHex: "#5856D6", subcategories: [subcatMat, subcatInf, subcatFiz])
        
        let subcatProj = Subcategory(name: "Projekty App", icon: "hammer.fill", colorHex: "#FF9500")
        let subcatSpotk = Subcategory(name: "Spotkania & Notatki", icon: "person.2.fill", colorHex: "#34C759")
        let catPraca = Category(name: "Praca & Biznes", icon: "briefcase.fill", colorHex: "#FF9500", subcategories: [subcatProj, subcatSpotk])
        
        let subcatPom = Subcategory(name: "Pomysły & Szkice", icon: "lightbulb.fill", colorHex: "#FFCC00")
        let subcatDzien = Subcategory(name: "Dziennik osobisty", icon: "book.fill", colorHex: "#FF2D55")
        let catOsobiste = Category(name: "Osobiste", icon: "heart.fill", colorHex: "#FF2D55", subcategories: [subcatPom, subcatDzien])
        
        self.categories = [catStudia, catPraca, catOsobiste]
        
        // Sample Note 1: Geometria i Rysowanie kształtów
        var note1 = Note(
            title: "Wykresy i Kształty Geometryczne",
            categoryId: catStudia.id,
            subcategoryId: subcatMat.id,
            isFavorite: true,
            tags: ["geometria", "wykłady", "wzory"],
            paperStyle: .grid,
            paperColor: .white,
            classicNoteText: """
            # Wykład 4: Geometria analityczna
            - Twierdzenie Pitagorasa: a² + b² = c²
            - Pole koła: P = π · r²
            - Obwód koła: O = 2 · π · r
            
            Notatki odręczne zawierają rozpoznane automatycznie figury geometryczne!
            """
        )
        
        // Add sample geometric shapes to Note 1
        let rectShape = GeometricShapeData(
            kind: .rectangle,
            start: CGPoint(x: 120, y: 150),
            end: CGPoint(x: 320, y: 280),
            bounds: CGRect(x: 120, y: 150, width: 200, height: 130)
        )
        let strokeRect = DrawingStroke(
            tool: .shape,
            colorHex: "#007AFF",
            baseWidth: 3.5,
            isAutoCorrected: true,
            recognizedShape: rectShape
        )
        
        let circleShape = GeometricShapeData(
            kind: .circle,
            start: CGPoint(x: 420, y: 215),
            end: CGPoint(x: 580, y: 215),
            bounds: CGRect(x: 420, y: 135, width: 160, height: 160)
        )
        let strokeCircle = DrawingStroke(
            tool: .shape,
            colorHex: "#AF52DE",
            baseWidth: 3.5,
            isAutoCorrected: true,
            recognizedShape: circleShape
        )
        
        let arrowShape = GeometricShapeData(
            kind: .arrow,
            start: CGPoint(x: 325, y: 215),
            end: CGPoint(x: 415, y: 215),
            bounds: CGRect(x: 325, y: 205, width: 90, height: 20)
        )
        let strokeArrow = DrawingStroke(
            tool: .shape,
            colorHex: "#FF9500",
            baseWidth: 3.0,
            isAutoCorrected: true,
            recognizedShape: arrowShape
        )
        
        note1.pages[0].strokes = [strokeRect, strokeArrow, strokeCircle]
        
        note1.pages[0].textBoxes = [
            CanvasTextBox(
                text: "Wektor przesunięcia T(x, y)",
                x: 310,
                y: 110,
                width: 200,
                height: 45,
                fontSize: 14,
                isBold: true,
                textColorHex: "#007AFF"
            )
        ]
        
        note1.pages[0].stickyNotes = [
            StickyNote(
                text: "💡 Kolokwium w piątek z całek i geometrii!",
                x: 640,
                y: 120,
                width: 190,
                height: 150,
                colorHex: "#FFF475",
                rotationDegrees: 1.5
            )
        ]
        
        // Sample Note 2: Architektura aplikacji (Tablica szkolna)
        var note2 = Note(
            title: "Architektura Quillfolio (Tablica)",
            categoryId: catPraca.id,
            subcategoryId: subcatProj.id,
            isFavorite: true,
            tags: ["swift", "macos", "architektura"],
            paperStyle: .dots,
            paperColor: .chalkboard,
            classicNoteText: """
            Kluczowe moduły aplikacji:
            1. CanvasView (AppKit + CoreGraphics)
            2. ShapeRecognizer (Rozpoznawanie figur)
            3. DataStore (JSON + Application Support)
            4. Eksport PDF / PNG
            """
        )
        
        note2.pages[0].stickyNotes = [
            StickyNote(
                text: "🚀 Gotowe do prezentacji!",
                x: 180,
                y: 160,
                width: 180,
                height: 130,
                colorHex: "#D7AEFB",
                rotationDegrees: -2.0
            )
        ]
        
        self.notes = [note1, note2]
    }
}
