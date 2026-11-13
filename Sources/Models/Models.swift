import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Enums

public enum PaperStyle: String, Codable, CaseIterable, Identifiable {
    case blank = "Czysta"
    case lined = "W linie"
    case grid = "W kratkę"
    case dots = "W kropki"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .blank: return "doc"
        case .lined: return "text.alignleft"
        case .grid: return "squareshape.split.3x3"
        case .dots: return "circle.grid.3x3"
        }
    }
}

public enum PaperColor: String, Codable, CaseIterable, Identifiable {
    case white = "Biały"
    case cream = "Kremowy (Sepia)"
    case yellowLegal = "Żółty notatnik"
    case darkSlate = "Ciemny grafit"
    case chalkboard = "Tablica szkolna"
    
    public var id: String { rawValue }
    
    public var backgroundColor: Color {
        switch self {
        case .white: return Color(white: 0.99)
        case .cream: return Color(red: 0.98, green: 0.96, blue: 0.91)
        case .yellowLegal: return Color(red: 0.99, green: 0.97, blue: 0.82)
        case .darkSlate: return Color(red: 0.13, green: 0.14, blue: 0.16)
        case .chalkboard: return Color(red: 0.11, green: 0.18, blue: 0.15)
        }
    }
    
    public var isDark: Bool {
        return self == .darkSlate || self == .chalkboard
    }
    
    public var defaultInkColorHex: String {
        return isDark ? "#FFFFFF" : "#1A1A1A"
    }
    
    public var patternColor: Color {
        switch self {
        case .white: return Color(white: 0.86)
        case .cream: return Color(red: 0.85, green: 0.82, blue: 0.75)
        case .yellowLegal: return Color(red: 0.87, green: 0.84, blue: 0.68)
        case .darkSlate: return Color(white: 0.25)
        case .chalkboard: return Color(red: 0.20, green: 0.30, blue: 0.25)
        }
    }
    
    public var marginColor: Color {
        switch self {
        case .white, .cream: return Color(red: 0.92, green: 0.45, blue: 0.45).opacity(0.65)
        case .yellowLegal: return Color(red: 0.88, green: 0.38, blue: 0.38).opacity(0.7)
        case .darkSlate, .chalkboard: return Color(red: 0.8, green: 0.3, blue: 0.3).opacity(0.5)
        }
    }
}

public enum DrawingTool: String, Codable, CaseIterable, Identifiable {
    case pointer = "Kursor / Przesuwanie"
    case pen = "Pióro"
    case calligraphy = "Kaligrafia"
    case brush = "Pędzel"
    case pencil = "Ołówek"
    case crayon = "Kredka woskowa"
    case highlighter = "Zakreślacz"
    case eraser = "Gumka"
    case lasso = "Lasso / Zaznacz"
    case shape = "Kształty"
    case text = "Pole tekstowe"
    case sticky = "Karteczka"
    case laser = "Wskaźnik laserowy"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .pointer: return "cursorarrow"
        case .pen: return "pencil.tip"
        case .calligraphy: return "quill"
        case .brush: return "paintbrush.pointed.fill"
        case .pencil: return "pencil"
        case .crayon: return "scribble.variable"
        case .highlighter: return "highlighter"
        case .eraser: return "eraser.fill"
        case .lasso: return "lasso.and.sparkles"
        case .shape: return "square.on.circle"
        case .text: return "character.cursor.ibeam"
        case .sticky: return "note.text"
        case .laser: return "dot.scope"
        }
    }
}

public enum ShapeKind: String, Codable, CaseIterable, Identifiable {
    case auto = "Automatyczny"
    case line = "Linia"
    case arrow = "Strzałka"
    case doubleArrow = "Strzałka dwustronna"
    case rectangle = "Prostokąt"
    case roundedRectangle = "Zaokrąglony prostokąt"
    case square = "Kwadrat"
    case circle = "Koło"
    case ellipse = "Elipsa"
    case triangle = "Trójkąt"
    case rhombus = "Romb"
    case parallelogram = "Równoległobok"
    case trapezoid = "Trapez"
    case rightTrapezoid = "Trapez prostokątny (lewy)"
    case rightTrapezoidRight = "Trapez prostokątny (prawy)"
    case hexagon = "Sześciokąt"
    case stretchedHexagon = "Sześciokąt rozciągnięty"
    case star = "Gwiazda"
    case cloud = "Chmurka"
    case table = "Tabela"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .auto: return "sparkles"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.up.right"
        case .doubleArrow: return "arrow.left.and.right"
        case .rectangle: return "rectangle"
        case .roundedRectangle: return "app"
        case .square: return "square"
        case .circle: return "circle"
        case .ellipse: return "oval"
        case .triangle: return "triangle"
        case .rhombus: return "diamond"
        case .parallelogram: return "skew"
        case .trapezoid: return "trapezoid.and.line.horizontal"
        case .rightTrapezoid: return "trapezoid.and.line.vertical"
        case .rightTrapezoidRight: return "trapezoid.and.line.vertical.fill"
        case .hexagon: return "hexagon"
        case .stretchedHexagon: return "capsule"
        case .star: return "star"
        case .cloud: return "cloud"
        case .table: return "tablecells"
        }
    }
}

// MARK: - Drawing Data Structures

public struct StrokePoint: Codable, Equatable {
    public var x: Double
    public var y: Double
    public var pressure: Double // 0.0 to 1.0
    public var timestamp: Double
    
    public init(x: Double, y: Double, pressure: Double = 0.5, timestamp: Double = Date().timeIntervalSince1970) {
        self.x = x
        self.y = y
        self.pressure = max(0.05, min(1.0, pressure))
        self.timestamp = timestamp
    }
    
    public var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

public struct GeometricShapeData: Codable, Equatable {
    public var kind: ShapeKind
    public var startPointX: Double
    public var startPointY: Double
    public var endPointX: Double
    public var endPointY: Double
    public var boundsX: Double
    public var boundsY: Double
    public var boundsWidth: Double
    public var boundsHeight: Double
    public var hasArrowStart: Bool
    public var hasArrowEnd: Bool
    public var extraPoints: [StrokePoint]
    
    public init(
        kind: ShapeKind,
        start: CGPoint,
        end: CGPoint,
        bounds: CGRect = .zero,
        hasArrowStart: Bool = false,
        hasArrowEnd: Bool = true,
        extraPoints: [StrokePoint] = []
    ) {
        self.kind = kind
        self.startPointX = Double(start.x)
        self.startPointY = Double(start.y)
        self.endPointX = Double(end.x)
        self.endPointY = Double(end.y)
        self.boundsX = Double(bounds.origin.x)
        self.boundsY = Double(bounds.origin.y)
        self.boundsWidth = Double(bounds.size.width)
        self.boundsHeight = Double(bounds.size.height)
        self.hasArrowStart = hasArrowStart
        self.hasArrowEnd = hasArrowEnd
        self.extraPoints = extraPoints
    }
    
    public var startPoint: CGPoint { CGPoint(x: startPointX, y: startPointY) }
    public var endPoint: CGPoint { CGPoint(x: endPointX, y: endPointY) }
    public var bounds: CGRect { CGRect(x: boundsX, y: boundsY, width: boundsWidth, height: boundsHeight) }
    
    public mutating func reverseArrowDirection() {
        if kind == .arrow || kind == .doubleArrow {
            let tempX = startPointX
            let tempY = startPointY
            startPointX = endPointX
            startPointY = endPointY
            endPointX = tempX
            endPointY = tempY
        }
    }
    
    public mutating func updateEndpoints(start: CGPoint, end: CGPoint) {
        self.startPointX = Double(start.x)
        self.startPointY = Double(start.y)
        self.endPointX = Double(end.x)
        self.endPointY = Double(end.y)
        let minX = min(start.x, end.x)
        let minY = min(start.y, end.y)
        let maxX = max(start.x, end.x)
        let maxY = max(start.y, end.y)
        self.boundsX = Double(minX)
        self.boundsY = Double(minY)
        self.boundsWidth = Double(max(10, maxX - minX))
        self.boundsHeight = Double(max(10, maxY - minY))
    }
    
    public mutating func updateBounds(_ newBounds: CGRect) {
        let oldBounds = bounds
        self.boundsX = Double(newBounds.origin.x)
        self.boundsY = Double(newBounds.origin.y)
        self.boundsWidth = Double(max(10, newBounds.size.width))
        self.boundsHeight = Double(max(10, newBounds.size.height))
        
        // Scale endpoints and extraPoints proportionally
        if oldBounds.width > 0 && oldBounds.height > 0 {
            let scaleX = newBounds.width / oldBounds.width
            let scaleY = newBounds.height / oldBounds.height
            
            startPointX = Double(newBounds.minX + (CGFloat(startPointX) - oldBounds.minX) * scaleX)
            startPointY = Double(newBounds.minY + (CGFloat(startPointY) - oldBounds.minY) * scaleY)
            endPointX = Double(newBounds.minX + (CGFloat(endPointX) - oldBounds.minX) * scaleX)
            endPointY = Double(newBounds.minY + (CGFloat(endPointY) - oldBounds.minY) * scaleY)
            
            for i in 0..<extraPoints.count {
                extraPoints[i].x = Double(newBounds.minX + (CGFloat(extraPoints[i].x) - oldBounds.minX) * scaleX)
                extraPoints[i].y = Double(newBounds.minY + (CGFloat(extraPoints[i].y) - oldBounds.minY) * scaleY)
            }
        }
    }
    
    public mutating func translate(by delta: CGSize) {
        startPointX += Double(delta.width)
        startPointY += Double(delta.height)
        endPointX += Double(delta.width)
        endPointY += Double(delta.height)
        boundsX += Double(delta.width)
        boundsY += Double(delta.height)
        for i in 0..<extraPoints.count {
            extraPoints[i].x += Double(delta.width)
            extraPoints[i].y += Double(delta.height)
        }
    }
}

public struct DrawingStroke: Identifiable, Codable, Equatable {
    public var id: UUID
    public var tool: DrawingTool
    public var colorHex: String
    public var baseWidth: Double
    public var opacity: Double
    public var points: [StrokePoint]
    public var isAutoCorrected: Bool
    public var recognizedShape: GeometricShapeData?
    
    public init(
        id: UUID = UUID(),
        tool: DrawingTool = .pen,
        colorHex: String = "#1A1A1A",
        baseWidth: Double = 3.0,
        opacity: Double = 1.0,
        points: [StrokePoint] = [],
        isAutoCorrected: Bool = false,
        recognizedShape: GeometricShapeData? = nil
    ) {
        self.id = id
        self.tool = tool
        self.colorHex = colorHex
        self.baseWidth = baseWidth
        self.opacity = opacity
        self.points = points
        self.isAutoCorrected = isAutoCorrected
        self.recognizedShape = recognizedShape
    }
    
    public var boundingBox: CGRect {
        if let shape = recognizedShape {
            return shape.bounds
        }
        guard !points.isEmpty else { return .zero }
        var minX = CGFloat.infinity, maxX = -CGFloat.infinity
        var minY = CGFloat.infinity, maxY = -CGFloat.infinity
        for p in points {
            minX = min(minX, CGFloat(p.x))
            maxX = max(maxX, CGFloat(p.x))
            minY = min(minY, CGFloat(p.y))
            maxY = max(maxY, CGFloat(p.y))
        }
        let inset = CGFloat(baseWidth * 2.0)
        return CGRect(x: minX - inset, y: minY - inset, width: (maxX - minX) + inset * 2, height: (maxY - minY) + inset * 2)
    }
    
    public mutating func translate(by delta: CGSize) {
        if recognizedShape != nil {
            recognizedShape?.translate(by: delta)
        } else {
            for i in 0..<points.count {
                points[i].x += Double(delta.width)
                points[i].y += Double(delta.height)
            }
        }
    }
    
    public mutating func scale(factorX: CGFloat, factorY: CGFloat, anchor: CGPoint) {
        if var shape = recognizedShape {
            let b = shape.bounds
            let newOrigin = CGPoint(
                x: anchor.x + (b.origin.x - anchor.x) * factorX,
                y: anchor.y + (b.origin.y - anchor.y) * factorY
            )
            let newSize = CGSize(width: max(10, b.size.width * factorX), height: max(10, b.size.height * factorY))
            shape.updateBounds(CGRect(origin: newOrigin, size: newSize))
            self.recognizedShape = shape
        } else {
            for i in 0..<points.count {
                points[i].x = Double(anchor.x + (CGFloat(points[i].x) - anchor.x) * factorX)
                points[i].y = Double(anchor.y + (CGFloat(points[i].y) - anchor.y) * factorY)
            }
        }
    }
}

// MARK: - Images on Canvas

public struct CanvasImage: Identifiable, Codable, Equatable {
    public var id: UUID
    public var imageData: Data
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var rotation: Double
    
    public init(
        id: UUID = UUID(),
        imageData: Data,
        x: Double = 100,
        y: Double = 100,
        width: Double = 300,
        height: Double = 220,
        rotation: Double = 0
    ) {
        self.id = id
        self.imageData = imageData
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.rotation = rotation
    }
    
    public var frame: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

public struct CanvasTextBox: Identifiable, Codable, Equatable {
    public var id: UUID
    public var text: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var fontSize: Double
    public var fontDesign: String // "default", "serif", "monospaced", "rounded", "handwriting"
    public var isBold: Bool
    public var isItalic: Bool
    public var isUnderline: Bool
    public var isStrikethrough: Bool
    public var textAlignment: String // "left", "center", "right"
    public var listType: String // "none", "bullet_dot", "bullet_dash", "bullet_square", "numbered"
    public var indentLevel: Int
    public var textColorHex: String
    public var backgroundColorHex: String?
    
    public init(
        id: UUID = UUID(),
        text: String = "Wpisz tekst tutaj...",
        x: Double = 100,
        y: Double = 100,
        width: Double = 140,
        height: Double = 36,
        fontSize: Double = 16,
        fontDesign: String = "default",
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderline: Bool = false,
        isStrikethrough: Bool = false,
        textAlignment: String = "left",
        listType: String = "none",
        indentLevel: Int = 0,
        textColorHex: String = "#1A1A1A",
        backgroundColorHex: String? = nil
    ) {
        self.id = id
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.fontSize = fontSize
        self.fontDesign = fontDesign
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderline = isUnderline
        self.isStrikethrough = isStrikethrough
        self.textAlignment = textAlignment
        self.listType = listType
        self.indentLevel = indentLevel
        self.textColorHex = textColorHex
        self.backgroundColorHex = backgroundColorHex
    }
    
    public var frame: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, text, x, y, width, height, fontSize, fontDesign
        case isBold, isItalic, isUnderline, isStrikethrough, textAlignment, listType
        case indentLevel, textColorHex, backgroundColorHex
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        self.x = try container.decodeIfPresent(Double.self, forKey: .x) ?? 100
        self.y = try container.decodeIfPresent(Double.self, forKey: .y) ?? 100
        self.width = try container.decodeIfPresent(Double.self, forKey: .width) ?? 140
        self.height = try container.decodeIfPresent(Double.self, forKey: .height) ?? 36
        self.fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? 16
        self.fontDesign = try container.decodeIfPresent(String.self, forKey: .fontDesign) ?? "default"
        self.isBold = try container.decodeIfPresent(Bool.self, forKey: .isBold) ?? false
        self.isItalic = try container.decodeIfPresent(Bool.self, forKey: .isItalic) ?? false
        self.isUnderline = try container.decodeIfPresent(Bool.self, forKey: .isUnderline) ?? false
        self.isStrikethrough = try container.decodeIfPresent(Bool.self, forKey: .isStrikethrough) ?? false
        self.textAlignment = try container.decodeIfPresent(String.self, forKey: .textAlignment) ?? "left"
        self.listType = try container.decodeIfPresent(String.self, forKey: .listType) ?? "none"
        self.indentLevel = try container.decodeIfPresent(Int.self, forKey: .indentLevel) ?? 0
        self.textColorHex = try container.decodeIfPresent(String.self, forKey: .textColorHex) ?? "#1A1A1A"
        self.backgroundColorHex = try container.decodeIfPresent(String.self, forKey: .backgroundColorHex)
    }
}

public struct StickyNote: Identifiable, Codable, Equatable {
    public var id: UUID
    public var text: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var colorHex: String
    public var rotationDegrees: Double
    public var fontSize: Double
    public var fontDesign: String
    public var isBold: Bool
    public var isItalic: Bool
    public var isUnderline: Bool
    public var textAlignment: String
    public var listType: String
    
    public init(
        id: UUID = UUID(),
        text: String = "Ważna myśl...",
        x: Double = 150,
        y: Double = 150,
        width: Double = 160,
        height: Double = 140,
        colorHex: String = "#FFF475", // Pastel yellow
        rotationDegrees: Double = -1.5,
        fontSize: Double = 15,
        fontDesign: String = "default",
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderline: Bool = false,
        textAlignment: String = "left",
        listType: String = "none"
    ) {
        self.id = id
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.colorHex = colorHex
        self.rotationDegrees = rotationDegrees
        self.fontSize = fontSize
        self.fontDesign = fontDesign
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderline = isUnderline
        self.textAlignment = textAlignment
        self.listType = listType
    }
    
    public var frame: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, text, x, y, width, height, colorHex, rotationDegrees
        case fontSize, fontDesign, isBold, isItalic, isUnderline, textAlignment, listType
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        self.x = try container.decodeIfPresent(Double.self, forKey: .x) ?? 150
        self.y = try container.decodeIfPresent(Double.self, forKey: .y) ?? 150
        self.width = try container.decodeIfPresent(Double.self, forKey: .width) ?? 200
        self.height = try container.decodeIfPresent(Double.self, forKey: .height) ?? 180
        self.colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? "#FFF475"
        self.rotationDegrees = try container.decodeIfPresent(Double.self, forKey: .rotationDegrees) ?? -1.5
        self.fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? 15
        self.fontDesign = try container.decodeIfPresent(String.self, forKey: .fontDesign) ?? "default"
        self.isBold = try container.decodeIfPresent(Bool.self, forKey: .isBold) ?? false
        self.isItalic = try container.decodeIfPresent(Bool.self, forKey: .isItalic) ?? false
        self.isUnderline = try container.decodeIfPresent(Bool.self, forKey: .isUnderline) ?? false
        self.textAlignment = try container.decodeIfPresent(String.self, forKey: .textAlignment) ?? "left"
        self.listType = try container.decodeIfPresent(String.self, forKey: .listType) ?? "none"
    }
}

// MARK: - Canvas Table Model

public struct CanvasTable: Identifiable, Codable, Equatable {
    public var id: UUID
    public var x: Double
    public var y: Double
    public var rows: Int
    public var cols: Int
    public var data: [[String]] // [row][col]
    public var colWidths: [Double]
    public var rowHeights: [Double]
    public var headerColorHex: String?
    public var borderColorHex: String
    
    public init(
        id: UUID = UUID(),
        x: Double,
        y: Double,
        rows: Int = 3,
        cols: Int = 3,
        data: [[String]]? = nil,
        colWidths: [Double]? = nil,
        rowHeights: [Double]? = nil,
        headerColorHex: String? = "#3B82F622",
        borderColorHex: String = "#334155"
    ) {
        self.id = id
        self.x = x
        self.y = y
        let r = max(1, rows)
        let c = max(1, cols)
        self.rows = r
        self.cols = c
        if let d = data, d.count == r {
            self.data = d
        } else {
            self.data = Array(repeating: Array(repeating: "", count: c), count: r)
        }
        self.colWidths = colWidths ?? Array(repeating: 110.0, count: c)
        self.rowHeights = rowHeights ?? Array(repeating: 34.0, count: r)
        self.headerColorHex = headerColorHex
        self.borderColorHex = borderColorHex
    }
    
    public var totalWidth: Double {
        colWidths.reduce(0, +)
    }
    
    public var totalHeight: Double {
        rowHeights.reduce(0, +)
    }
}

public struct NotePage: Identifiable, Codable, Equatable {
    public var id: UUID
    public var pageIndex: Int
    public var strokes: [DrawingStroke]
    public var textBoxes: [CanvasTextBox]
    public var stickyNotes: [StickyNote]
    public var images: [CanvasImage]
    public var tables: [CanvasTable]
    
    public init(
        id: UUID = UUID(),
        pageIndex: Int = 0,
        strokes: [DrawingStroke] = [],
        textBoxes: [CanvasTextBox] = [],
        stickyNotes: [StickyNote] = [],
        images: [CanvasImage] = [],
        tables: [CanvasTable] = []
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.strokes = strokes
        self.textBoxes = textBoxes
        self.stickyNotes = stickyNotes
        self.images = images
        self.tables = tables
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, pageIndex, strokes, textBoxes, stickyNotes, images, tables
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.pageIndex = try container.decodeIfPresent(Int.self, forKey: .pageIndex) ?? 0
        self.strokes = try container.decodeIfPresent([DrawingStroke].self, forKey: .strokes) ?? []
        self.textBoxes = try container.decodeIfPresent([CanvasTextBox].self, forKey: .textBoxes) ?? []
        self.stickyNotes = try container.decodeIfPresent([StickyNote].self, forKey: .stickyNotes) ?? []
        self.images = try container.decodeIfPresent([CanvasImage].self, forKey: .images) ?? []
        self.tables = try container.decodeIfPresent([CanvasTable].self, forKey: .tables) ?? []
    }
}

public struct Note: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var categoryId: UUID?
    public var subcategoryId: UUID?
    public var createdAt: Date
    public var updatedAt: Date
    public var isFavorite: Bool
    public var tags: [String]
    public var paperStyle: PaperStyle
    public var paperColor: PaperColor
    public var pages: [NotePage]
    public var currentPageIndex: Int
    public var classicNoteText: String
    
    public init(
        id: UUID = UUID(),
        title: String = "Nowa notatka",
        categoryId: UUID? = nil,
        subcategoryId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isFavorite: Bool = false,
        tags: [String] = [],
        paperStyle: PaperStyle = .grid,
        paperColor: PaperColor = .white,
        pages: [NotePage] = [NotePage(pageIndex: 0)],
        currentPageIndex: Int = 0,
        classicNoteText: String = ""
    ) {
        self.id = id
        self.title = title
        self.categoryId = categoryId
        self.subcategoryId = subcategoryId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isFavorite = isFavorite
        self.tags = tags
        self.paperStyle = paperStyle
        self.paperColor = paperColor
        self.pages = pages.isEmpty ? [NotePage(pageIndex: 0)] : pages
        self.currentPageIndex = currentPageIndex
        self.classicNoteText = classicNoteText
    }
    
    public var currentPage: NotePage {
        get {
            let validIndex = max(0, min(currentPageIndex, pages.count - 1))
            return pages[validIndex]
        }
        set {
            let validIndex = max(0, min(currentPageIndex, pages.count - 1))
            pages[validIndex] = newValue
        }
    }
}

public struct Subcategory: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var icon: String
    public var colorHex: String
    
    public init(
        id: UUID = UUID(),
        name: String,
        icon: String = "folder.badge.gearshape",
        colorHex: String = "#0A84FF"
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
    }
}

public struct Category: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var icon: String
    public var colorHex: String
    public var subcategories: [Subcategory]
    
    public init(
        id: UUID = UUID(),
        name: String,
        icon: String = "folder.fill",
        colorHex: String = "#007AFF",
        subcategories: [Subcategory] = []
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.subcategories = subcategories
    }
}

extension NSColor {
    public convenience init?(hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanHex.hasPrefix("#") { cleanHex.removeFirst() }
        
        guard cleanHex.count == 6 || cleanHex.count == 8 else { return nil }
        
        var rgbValue: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&rgbValue)
        
        if cleanHex.count == 6 {
            let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(rgbValue & 0x0000FF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: 1.0)
        } else {
            let r = CGFloat((rgbValue & 0xFF000000) >> 24) / 255.0
            let g = CGFloat((rgbValue & 0x00FF0000) >> 16) / 255.0
            let b = CGFloat((rgbValue & 0x0000FF00) >> 8) / 255.0
            let a = CGFloat(rgbValue & 0x000000FF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: a)
        }
    }
}
