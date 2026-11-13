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

import AppKit
import CoreGraphics

public protocol CanvasViewDelegate: AnyObject {
    func canvasDidAddStroke(_ stroke: DrawingStroke)
    func canvasDidEraseStrokes(ids: Set<UUID>)
    func canvasDidSelectStrokes(ids: Set<UUID>)
    func canvasDidMoveSelectedStrokes(by delta: CGSize)
    func canvasDidScaleSelectedStrokes(factorX: CGFloat, factorY: CGFloat, anchor: CGPoint)
    func canvasDidReverseArrow(strokeId: UUID)
    func canvasDidUpdateShapeEndpoints(strokeId: UUID, start: CGPoint, end: CGPoint)
    func canvasDidUpdateShapeBounds(strokeId: UUID, newBounds: CGRect)
    func canvasDidRequestUndo()
    func canvasDidRequestRedo()
    func canvasDidToggleEraser()
    func canvasDidRequestZoomIn()
    func canvasDidRequestZoomOut()
    func canvasDidRequestZoomReset()
    func canvasDidSelectTextBox(at point: CGPoint)
    func canvasDidSelectStickyNote(at point: CGPoint)
    func canvasDidChangeTextBox(_ textBox: CanvasTextBox)
    func canvasDidChangeStickyNote(_ stickyNote: StickyNote)
    func canvasDidUpdateStylus(pressure: Double, device: String, isDown: Bool)
    func canvasCurrentZoomScale() -> CGFloat
    func canvasDidUpdateZoom(_ newZoom: CGFloat)
    func canvasDidPasteImage(data: Data, at location: CGPoint)
    func canvasDidChangeTool(_ tool: DrawingTool)
    func canvasDidCopySelection()
    func canvasDidPasteSelection()
    func canvasDidDeleteSelectedStrokes()
    func canvasDidInsertTextBox(at point: CGPoint)
    func canvasDidInsertStickyNote(at point: CGPoint)
    func canvasDidInsertTable(at point: CGPoint)
    func canvasDidInsertShape(kind: ShapeKind, at point: CGPoint)
    func canvasDidSelectAll()
    func canvasDidClearPage()
    func canvasDidChangePaperStyle(_ style: PaperStyle)
    func canvasDidChangePaperColor(_ color: PaperColor)
    func canvasDidDeselectAll()
}

public final class CanvasView: NSView {
    
    // MARK: - Properties
    
    public override var isFlipped: Bool { true }
    public weak var delegate: CanvasViewDelegate?
    
    // Laser Pointer Ephemeral Trail (Presentation pointer that auto-fades)
    private var laserPoints: [(point: CGPoint, time: Date)] = []
    private var laserTimer: Timer? = nil
    
    public var paperStyle: PaperStyle = .grid { didSet { needsDisplay = true } }
    public var paperColor: PaperColor = .white { didSet { needsDisplay = true } }
    public var currentTool: DrawingTool = .pen { didSet { updateCursor(); needsDisplay = true } }
    public var currentShapeKind: ShapeKind = .auto
    public var currentColorHex: String = "#1A1A1A"
    public var currentBaseWidth: Double = 3.0
    public var autoCorrectShapes: Bool = true
    public var drawAndHoldEnabled: Bool = true
    public var isRulerVisible: Bool = false { didSet { needsDisplay = true } }
    public var rulerOrigin: CGPoint = CGPoint(x: 100, y: 300)
    public var rulerAngle: CGFloat = 0.0
    
    // Tablet & Stylus Settings
    public var pressureSensitivity: Double = 1.3
    public var simulatePressureIfZero: Bool = true
    private var lastVelocityLocation: CGPoint = .zero
    private var lastVelocityTimestamp: TimeInterval = 0
    
    // Canvas Data
    public var strokes: [DrawingStroke] = [] { didSet { needsDisplay = true } }
    public var textBoxes: [CanvasTextBox] = [] { didSet { needsDisplay = true } }
    public var stickyNotes: [StickyNote] = [] { didSet { needsDisplay = true } }
    
    // Selection & Shape Editing State
    public var selectedStrokeIds: Set<UUID> = [] { didSet { needsDisplay = true } }
    public var activeEditingStrokeId: UUID? = nil { didSet { needsDisplay = true } }
    
    // In-flight Drawing
    private var inProgressPoints: [StrokePoint] = []
    private var inProgressShapePreview: GeometricShapeData? = nil
    private var isDrawing = false
    
    // Lasso in-flight points
    private var lassoPoints: [CGPoint] = []
    
    // Hold gesture timer
    private var holdTimer: Timer?
    private var lastDragPoint: CGPoint = .zero
    private var hasHoldSnapped = false
    
    // Interaction Modes
    public enum ResizeHandle: Equatable {
        case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
    }
    
    private enum DragMode: Equatable {
        case none
        case drawing
        case erasing
        case lassoing
        case movingSelection(lastLocation: CGPoint)
        case resizingShapeHandle(strokeId: UUID, handle: ResizeHandle, originalBounds: CGRect, startLocation: CGPoint)
        case movingShapeEndpoint(strokeId: UUID, isStart: Bool)
    }
    private var dragMode: DragMode = .none
    
    // Tablet Stylus & ExpressKeys State
    private var rightClickDownPoint: CGPoint = .zero
    private var isRightClickErasing: Bool = false
    private var otherDragStartPoint: CGPoint = .zero
    private var isOtherDragging: Bool = false
    
    // MARK: - Initializer
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTracking()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTracking()
    }
    
    private func setupTracking() {
        wantsLayer = true
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .cursorUpdate, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        registerForDraggedTypes([.fileURL, .tiff, .png])
    }
    
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    public override var acceptsFirstResponder: Bool { true }
    public override var mouseDownCanMoveWindow: Bool { false }
    
    // MARK: - Cursor
    
    private func updateCursor() {
        switch currentTool {
        case .pointer: NSCursor.arrow.set()
        case .eraser: NSCursor.crosshair.set()
        case .text: NSCursor.iBeam.set()
        case .lasso: NSCursor.crosshair.set()
        case .sticky, .shape: NSCursor.arrow.set()
        case .pen, .calligraphy, .brush, .pencil, .crayon, .highlighter, .laser: NSCursor.crosshair.set()
        }
    }
    
    public override func cursorUpdate(with event: NSEvent) {
        updateCursor()
    }
    
    // MARK: - Drawing & Rendering
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // 1. Draw Paper background
        PaperRenderer.drawPaper(in: bounds, style: paperStyle, color: paperColor, context: context)
        
        // 2. Draw existing strokes
        for stroke in strokes {
            drawStroke(stroke, in: context)
        }
        
        // 3. Draw in-progress stroke or live preview
        if isDrawing {
            if let preview = inProgressShapePreview {
                let tempStroke = DrawingStroke(
                    tool: currentTool,
                    colorHex: currentColorHex,
                    baseWidth: currentBaseWidth,
                    opacity: 1.0,
                    isAutoCorrected: true,
                    recognizedShape: preview
                )
                context.saveGState()
                context.setShadow(offset: .zero, blur: 8.0, color: NSColor.systemBlue.withAlphaComponent(0.6).cgColor)
                drawStroke(tempStroke, in: context)
                context.restoreGState()
            } else if !inProgressPoints.isEmpty {
                let tempStroke = DrawingStroke(
                    tool: currentTool,
                    colorHex: currentColorHex,
                    baseWidth: currentBaseWidth,
                    opacity: 1.0,
                    points: inProgressPoints
                )
                drawStroke(tempStroke, in: context)
            }
        }
        
        // 4. Draw Lasso in-progress loop
        if !lassoPoints.isEmpty {
            drawLassoPath(in: context)
        }
        
        // 5. Draw Selection & Interactive Shape Transformation Handles
        drawSelectionAndShapeHandles(in: context)
        
        // 6. Draw Ruler if enabled
        if isRulerVisible {
            drawRuler(in: context)
        }
        
        // 7. Draw transient laser pointer trail and head
        drawLaserTrail(in: context)
    }
    
    // MARK: - Point & Pressure Smoothing Filters
    
    private func smoothPoints(_ pts: [StrokePoint]) -> [StrokePoint] {
        guard pts.count >= 3 else { return pts }
        var result = pts
        // 1-pass weighted filter on coordinates and pressure (removes digitizer jaggedness while preserving true path)
        for i in 1..<(pts.count - 1) {
            let prev = pts[i - 1]
            let curr = pts[i]
            let next = pts[i + 1]
            let smX = 0.20 * prev.x + 0.60 * curr.x + 0.20 * next.x
            let smY = 0.20 * prev.y + 0.60 * curr.y + 0.20 * next.y
            let smPressure = 0.25 * prev.pressure + 0.50 * curr.pressure + 0.25 * next.pressure
            result[i] = StrokePoint(x: smX, y: smY, pressure: smPressure, timestamp: curr.timestamp)
        }
        return result
    }
    
    private func strokeWidth(for tool: DrawingTool, baseWidth: Double, pressure: CGFloat) -> CGFloat {
        switch tool {
        case .pencil:
            return max(0.8, CGFloat(baseWidth) * (0.35 + 0.75 * pressure))
        case .brush:
            return max(1.2, CGFloat(baseWidth) * (0.45 + 1.9 * pressure))
        case .crayon:
            return max(1.2, CGFloat(baseWidth) * (0.75 + 0.6 * pressure))
        default: // .pen, .neon, etc.
            return max(1.0, CGFloat(baseWidth) * (0.30 + 1.4 * pressure))
        }
    }
    
    private func drawStroke(_ stroke: DrawingStroke, in context: CGContext) {
        if stroke.tool == .laser { return }
        context.saveGState()
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.interpolationQuality = .high
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        
        let strokeColor = NSColor(hex: stroke.colorHex) ?? (paperColor.isDark ? .white : .black)
        
        // Tool-specific blend modes and alphas
        switch stroke.tool {
        case .highlighter:
            context.setBlendMode(.multiply)
            context.setAlpha(0.38)
            context.setStrokeColor(strokeColor.cgColor)
            context.setLineCap(.round)
            context.setLineJoin(.round)
        case .pencil:
            context.setAlpha(stroke.opacity * 0.72)
            context.setStrokeColor(strokeColor.withAlphaComponent(0.85).cgColor)
            context.setLineCap(.round)
            context.setLineJoin(.round)
        case .brush:
            context.setAlpha(stroke.opacity * 0.88)
            context.setStrokeColor(strokeColor.cgColor)
            context.setLineCap(.round)
            context.setLineJoin(.round)
        case .crayon:
            context.setAlpha(0.90)
            context.setStrokeColor(strokeColor.cgColor)
            context.setLineCap(.round)
            context.setLineJoin(.round)
        case .laser:
            break
        default:
            context.setAlpha(stroke.opacity)
            context.setStrokeColor(strokeColor.cgColor)
            context.setLineCap(.round)
            context.setLineJoin(.round)
        }
        
        // Recognized or inserted geometric shape
        if let shape = stroke.recognizedShape {
            drawGeometricShape(shape, stroke: stroke, context: context)
            context.endTransparencyLayer()
            context.restoreGState()
            return
        }
        
        // Freehand points
        guard !stroke.points.isEmpty else {
            context.endTransparencyLayer()
            context.restoreGState()
            return
        }
        
        drawSmoothFreehandPath(points: stroke.points, stroke: stroke, strokeColor: strokeColor, context: context)
        
        context.endTransparencyLayer()
        context.restoreGState()
    }
    
    private func drawSmoothFreehandPath(points: [StrokePoint], stroke: DrawingStroke, strokeColor: NSColor, context: CGContext) {
        if points.count == 1 {
            let p = points[0].cgPoint
            let r = max(1.0, CGFloat(stroke.baseWidth * (stroke.tool == .highlighter ? 4.0 : points[0].pressure)) / 2.0)
            context.setFillColor(strokeColor.cgColor)
            context.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            return
        }
        
        let smoothed = smoothPoints(points)
        let count = smoothed.count
        
        if stroke.tool == .highlighter {
            let path = CGMutablePath()
            path.move(to: smoothed[0].cgPoint)
            for i in 1..<count {
                let pPrev = smoothed[i - 1].cgPoint
                let pCurr = smoothed[i].cgPoint
                let mid = CGPoint(x: (pPrev.x + pCurr.x) / 2.0, y: (pPrev.y + pCurr.y) / 2.0)
                path.addQuadCurve(to: mid, control: pPrev)
            }
            if let last = smoothed.last {
                path.addLine(to: last.cgPoint)
            }
            context.setLineWidth(CGFloat(stroke.baseWidth * 5.0))
            context.addPath(path)
            context.strokePath()
            return
        }
        
        if stroke.tool == .calligraphy {
            let chiselAngle: CGFloat = .pi / 4.0
            for i in 1..<count {
                let p0 = smoothed[i - 1]
                let p1 = smoothed[i]
                let dx = p1.x - p0.x
                let dy = p1.y - p0.y
                let travelAngle = atan2(dy, dx)
                let angleDiff = abs(travelAngle - chiselAngle)
                let factor = 0.30 + 2.2 * abs(sin(angleDiff))
                let avgPressure = CGFloat((p0.pressure + p1.pressure) / 2.0)
                let w = CGFloat(stroke.baseWidth) * factor * (0.6 + 0.6 * avgPressure)
                
                context.setLineWidth(max(1.0, w))
                context.beginPath()
                context.move(to: p0.cgPoint)
                let mid = CGPoint(x: (p0.x + p1.x) / 2.0, y: (p0.y + p1.y) / 2.0)
                context.addQuadCurve(to: mid, control: p0.cgPoint)
                context.strokePath()
            }
            return
        }
        
        if count == 2 {
            let p0 = smoothed[0]
            let p1 = smoothed[1]
            let avgPressure = CGFloat((p0.pressure + p1.pressure) / 2.0)
            let w = strokeWidth(for: stroke.tool, baseWidth: stroke.baseWidth, pressure: avgPressure)
            context.setLineWidth(w)
            context.beginPath()
            context.move(to: p0.cgPoint)
            context.addLine(to: p1.cgPoint)
            context.strokePath()
            return
        }
        
        // Count >= 3: Smooth quadratic Bézier curves through midpoints for silky rounded handwriting
        var prevMid = CGPoint(x: (smoothed[0].x + smoothed[1].x) / 2.0, y: (smoothed[0].y + smoothed[1].y) / 2.0)
        
        // Initial lead-in segment from P0 to M0
        let w0 = strokeWidth(for: stroke.tool, baseWidth: stroke.baseWidth, pressure: CGFloat(smoothed[0].pressure))
        context.setLineWidth(w0)
        context.beginPath()
        context.move(to: smoothed[0].cgPoint)
        context.addLine(to: prevMid)
        context.strokePath()
        
        for i in 1..<(count - 1) {
            let pCurr = smoothed[i]
            let pNext = smoothed[i + 1]
            let nextMid = CGPoint(x: (pCurr.x + pNext.x) / 2.0, y: (pCurr.y + pNext.y) / 2.0)
            let segPressure = CGFloat(pCurr.pressure)
            let w = strokeWidth(for: stroke.tool, baseWidth: stroke.baseWidth, pressure: segPressure)
            
            context.setLineWidth(w)
            context.beginPath()
            context.move(to: prevMid)
            context.addQuadCurve(to: nextMid, control: pCurr.cgPoint)
            context.strokePath()
            
            // Organic graphite grain speckles for pencil
            if stroke.tool == .pencil && i % 2 == 0 {
                let jitterX = CGFloat(sin(Double(i) * 3.7)) * w * 0.35
                let jitterY = CGFloat(cos(Double(i) * 5.1)) * w * 0.35
                context.setFillColor(strokeColor.withAlphaComponent(0.28).cgColor)
                context.fillEllipse(in: CGRect(x: nextMid.x + jitterX - 0.75, y: nextMid.y + jitterY - 0.75, width: 1.5, height: 1.5))
            }
            
            prevMid = nextMid
        }
        
        // Final lead-out segment from M_{N-2} to P_{N-1}
        if let last = smoothed.last {
            let wLast = strokeWidth(for: stroke.tool, baseWidth: stroke.baseWidth, pressure: CGFloat(last.pressure))
            context.setLineWidth(wLast)
            context.beginPath()
            context.move(to: prevMid)
            context.addLine(to: last.cgPoint)
            context.strokePath()
        }
    }
    
    private func drawGeometricShape(_ shape: GeometricShapeData, stroke: DrawingStroke, context: CGContext) {
        let width = CGFloat(stroke.baseWidth * (stroke.tool == .highlighter ? 4.0 : 1.2))
        context.setLineWidth(width)
        
        switch shape.kind {
        case .line:
            context.beginPath()
            context.move(to: shape.startPoint)
            context.addLine(to: shape.endPoint)
            context.strokePath()
            
        case .arrow, .doubleArrow:
            let start = shape.startPoint
            let end = shape.endPoint
            context.beginPath()
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
            
            let arrowLength: CGFloat = max(14.0, width * 4.5)
            let arrowAngle: CGFloat = .pi / 6.0
            
            // End arrowhead
            if shape.hasArrowEnd {
                let angle = atan2(end.y - start.y, end.x - start.x)
                let p1 = CGPoint(x: end.x - arrowLength * cos(angle - arrowAngle), y: end.y - arrowLength * sin(angle - arrowAngle))
                let p2 = CGPoint(x: end.x - arrowLength * cos(angle + arrowAngle), y: end.y - arrowLength * sin(angle + arrowAngle))
                context.beginPath()
                context.move(to: p1)
                context.addLine(to: end)
                context.addLine(to: p2)
                context.strokePath()
            }
            
            // Start arrowhead (for double arrow)
            if shape.hasArrowStart || shape.kind == .doubleArrow {
                let angle = atan2(start.y - end.y, start.x - end.x)
                let p1 = CGPoint(x: start.x - arrowLength * cos(angle - arrowAngle), y: start.y - arrowLength * sin(angle - arrowAngle))
                let p2 = CGPoint(x: start.x - arrowLength * cos(angle + arrowAngle), y: start.y - arrowLength * sin(angle + arrowAngle))
                context.beginPath()
                context.move(to: p1)
                context.addLine(to: start)
                context.addLine(to: p2)
                context.strokePath()
            }
            
        case .rectangle, .square:
            context.stroke(shape.bounds)
            
        case .roundedRectangle:
            let b = shape.bounds
            let r = min(18.0, min(b.width, b.height) / 3.0)
            let path = CGPath(roundedRect: b, cornerWidth: r, cornerHeight: r, transform: nil)
            context.addPath(path)
            context.strokePath()
            
        case .circle, .ellipse:
            context.strokeEllipse(in: shape.bounds)
            
        case .triangle:
            let b = shape.bounds
            let p1 = shape.extraPoints.count > 0 ? shape.extraPoints[0].cgPoint : CGPoint(x: b.midX, y: b.minY)
            let p2 = shape.extraPoints.count > 1 ? shape.extraPoints[1].cgPoint : CGPoint(x: b.maxX, y: b.maxY)
            let p3 = shape.extraPoints.count > 2 ? shape.extraPoints[2].cgPoint : CGPoint(x: b.minX, y: b.maxY)
            context.beginPath()
            context.move(to: p1)
            context.addLine(to: p2)
            context.addLine(to: p3)
            context.closePath()
            context.strokePath()
            
        case .rhombus:
            let b = shape.bounds
            let top = CGPoint(x: b.midX, y: b.minY)
            let right = CGPoint(x: b.maxX, y: b.midY)
            let bottom = CGPoint(x: b.midX, y: b.maxY)
            let left = CGPoint(x: b.minX, y: b.midY)
            context.beginPath()
            context.move(to: top)
            context.addLine(to: right)
            context.addLine(to: bottom)
            context.addLine(to: left)
            context.closePath()
            context.strokePath()
            
        case .parallelogram:
            let b = shape.bounds
            let skew = b.width * 0.22
            context.beginPath()
            context.move(to: CGPoint(x: b.minX + skew, y: b.minY))
            context.addLine(to: CGPoint(x: b.maxX, y: b.minY))
            context.addLine(to: CGPoint(x: b.maxX - skew, y: b.maxY))
            context.addLine(to: CGPoint(x: b.minX, y: b.maxY))
            context.closePath()
            context.strokePath()
            
        case .trapezoid:
            let b = shape.bounds
            let inset = b.width * 0.22
            context.beginPath()
            context.move(to: CGPoint(x: b.minX + inset, y: b.minY))
            context.addLine(to: CGPoint(x: b.maxX - inset, y: b.minY))
            context.addLine(to: CGPoint(x: b.maxX, y: b.maxY))
            context.addLine(to: CGPoint(x: b.minX, y: b.maxY))
            context.closePath()
            context.strokePath()
            
        case .rightTrapezoid:
            let b = shape.bounds
            let topW = b.width * 0.65
            context.beginPath()
            context.move(to: CGPoint(x: b.minX, y: b.minY))
            context.addLine(to: CGPoint(x: b.minX + topW, y: b.minY))
            context.addLine(to: CGPoint(x: b.maxX, y: b.maxY))
            context.addLine(to: CGPoint(x: b.minX, y: b.maxY))
            context.closePath()
            context.strokePath()
            
        case .rightTrapezoidRight:
            let b = shape.bounds
            let topW = b.width * 0.65
            context.beginPath()
            context.move(to: CGPoint(x: b.maxX - topW, y: b.minY))
            context.addLine(to: CGPoint(x: b.maxX, y: b.minY))
            context.addLine(to: CGPoint(x: b.maxX, y: b.maxY))
            context.addLine(to: CGPoint(x: b.minX, y: b.maxY))
            context.closePath()
            context.strokePath()
            
        case .hexagon:
            let b = shape.bounds
            let cx = b.midX
            let cy = b.midY
            let r = min(b.width, b.height) / 2.0
            context.beginPath()
            for i in 0..<6 {
                let a = CGFloat(i) * (.pi / 3.0)
                let pt = CGPoint(x: cx + r * cos(a), y: cy + r * sin(a))
                if i == 0 { context.move(to: pt) } else { context.addLine(to: pt) }
            }
            context.closePath()
            context.strokePath()
            
        case .stretchedHexagon:
            let b = shape.bounds
            let inset = b.width * 0.20
            context.beginPath()
            context.move(to: CGPoint(x: b.minX, y: b.midY))
            context.addLine(to: CGPoint(x: b.minX + inset, y: b.minY))
            context.addLine(to: CGPoint(x: b.maxX - inset, y: b.minY))
            context.addLine(to: CGPoint(x: b.maxX, y: b.midY))
            context.addLine(to: CGPoint(x: b.maxX - inset, y: b.maxY))
            context.addLine(to: CGPoint(x: b.minX + inset, y: b.maxY))
            context.closePath()
            context.strokePath()
            
        case .star:
            let b = shape.bounds
            let cx = b.midX
            let cy = b.midY
            let rOuter = min(b.width, b.height) / 2.0
            let rInner = rOuter * 0.42
            context.beginPath()
            for i in 0..<10 {
                let angle = (CGFloat(i) * .pi / 5.0) - (.pi / 2.0)
                let r = (i % 2 == 0) ? rOuter : rInner
                let pt = CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle))
                if i == 0 { context.move(to: pt) } else { context.addLine(to: pt) }
            }
            context.closePath()
            context.strokePath()
            
        case .cloud:
            let path = ShapeRecognizer.cloudPath(in: shape.bounds)
            context.addPath(path)
            context.strokePath()
            
        case .table:
            let b = shape.bounds
            let cols = max(1, Int(shape.startPointX > 0 ? shape.startPointX : 3))
            let rows = max(1, Int(shape.startPointY > 0 ? shape.startPointY : 3))
            context.stroke(b)
            context.beginPath()
            for r in 1..<rows {
                let y = b.minY + b.height * CGFloat(r) / CGFloat(rows)
                context.move(to: CGPoint(x: b.minX, y: y))
                context.addLine(to: CGPoint(x: b.maxX, y: y))
            }
            for c in 1..<cols {
                let x = b.minX + b.width * CGFloat(c) / CGFloat(cols)
                context.move(to: CGPoint(x: x, y: b.minY))
                context.addLine(to: CGPoint(x: x, y: b.maxY))
            }
            context.strokePath()
            
        case .auto:
            break
        }
    }
    
    // MARK: - Lasso Rendering
    
    private func drawLassoPath(in context: CGContext) {
        guard lassoPoints.count > 1 else { return }
        context.saveGState()
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.12).cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [5, 4])
        
        let path = CGMutablePath()
        path.move(to: lassoPoints[0])
        for p in lassoPoints.dropFirst() {
            path.addLine(to: p)
        }
        path.closeSubpath()
        context.addPath(path)
        context.fillPath()
        context.addPath(path)
        context.strokePath()
        context.restoreGState()
    }
    
    // MARK: - Selection & Shape Customization Handles
    
    private func drawSelectionAndShapeHandles(in context: CGContext) {
        // If single active shape editing
        if let editingId = activeEditingStrokeId,
           let stroke = strokes.first(where: { $0.id == editingId }),
           let shape = stroke.recognizedShape {
            
            context.saveGState()
            
            if shape.kind == .line || shape.kind == .arrow || shape.kind == .doubleArrow {
                // Draw endpoint handles
                drawControlHandle(at: shape.startPoint, label: "Start", context: context)
                drawControlHandle(at: shape.endPoint, label: "Koniec", context: context)
                
                // Draw quick "Odwróć strzałkę" button in the middle
                let midPoint = CGPoint(x: (shape.startPoint.x + shape.endPoint.x)/2.0, y: (shape.startPoint.y + shape.endPoint.y)/2.0 - 24)
                drawPillButton(at: midPoint, text: "⇄ Odwróć kierunek", in: context)
            } else {
                // 2D Shape: draw bounding box with 8 handles
                let b = shape.bounds.insetBy(dx: -4, dy: -4)
                context.setStrokeColor(NSColor.systemBlue.withAlphaComponent(0.85).cgColor)
                context.setLineWidth(1.5)
                context.setLineDash(phase: 0, lengths: [4, 4])
                context.stroke(b)
                
                // 8 Handles
                drawControlHandle(at: CGPoint(x: b.minX, y: b.minY), context: context)
                drawControlHandle(at: CGPoint(x: b.midX, y: b.minY), context: context)
                drawControlHandle(at: CGPoint(x: b.maxX, y: b.minY), context: context)
                drawControlHandle(at: CGPoint(x: b.maxX, y: b.midY), context: context)
                drawControlHandle(at: CGPoint(x: b.maxX, y: b.maxY), context: context)
                drawControlHandle(at: CGPoint(x: b.midX, y: b.maxY), context: context)
                drawControlHandle(at: CGPoint(x: b.minX, y: b.maxY), context: context)
                drawControlHandle(at: CGPoint(x: b.minX, y: b.midY), context: context)
            }
            context.restoreGState()
            return
        }
        
        // Multi-stroke Lasso Selection
        if !selectedStrokeIds.isEmpty {
            let selectedStrokes = strokes.filter { selectedStrokeIds.contains($0.id) }
            guard !selectedStrokes.isEmpty else { return }
            
            var combinedBox = selectedStrokes[0].boundingBox
            for s in selectedStrokes.dropFirst() {
                combinedBox = combinedBox.union(s.boundingBox)
            }
            let b = combinedBox.insetBy(dx: -8, dy: -8)
            
            context.saveGState()
            context.setStrokeColor(NSColor.systemBlue.cgColor)
            context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.05).cgColor)
            context.setLineWidth(1.5)
            context.setLineDash(phase: 0, lengths: [5, 4])
            context.fill(b)
            context.stroke(b)
            
            // 4 Corner handles
            drawControlHandle(at: CGPoint(x: b.minX, y: b.minY), context: context)
            drawControlHandle(at: CGPoint(x: b.maxX, y: b.minY), context: context)
            drawControlHandle(at: CGPoint(x: b.maxX, y: b.maxY), context: context)
            drawControlHandle(at: CGPoint(x: b.minX, y: b.maxY), context: context)
            
            // Header Action Pill
            drawPillButton(at: CGPoint(x: b.midX, y: b.minY - 20), text: "Zaznaczono: \(selectedStrokes.count) (Przesuń / Skaluj)", in: context)
            context.restoreGState()
        }
    }
    
    private func drawControlHandle(at point: CGPoint, label: String? = nil, context: CGContext) {
        let r: CGFloat = 6.0
        let rect = CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)
        context.saveGState()
        context.setLineDash(phase: 0, lengths: [])
        context.setFillColor(NSColor.white.cgColor)
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(2.0)
        context.fillEllipse(in: rect)
        context.strokeEllipse(in: rect)
        context.restoreGState()
    }
    
    private func drawPillButton(at point: CGPoint, text: String, in context: CGContext) {
        let str = NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.boldSystemFont(ofSize: 11),
                .foregroundColor: NSColor.white
            ]
        )
        let textSize = str.size()
        let pillRect = CGRect(x: point.x - textSize.width/2.0 - 10, y: point.y - textSize.height/2.0 - 4, width: textSize.width + 20, height: textSize.height + 8)
        
        context.saveGState()
        context.setLineDash(phase: 0, lengths: [])
        context.setFillColor(NSColor.systemBlue.cgColor)
        let path = CGPath(roundedRect: pillRect, cornerWidth: pillRect.height/2.0, cornerHeight: pillRect.height/2.0, transform: nil)
        context.addPath(path)
        context.fillPath()
        
        NSGraphicsContext.saveGraphicsState()
        let nsContext = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.current = nsContext
        str.draw(at: CGPoint(x: pillRect.minX + 10, y: pillRect.minY + 4))
        NSGraphicsContext.restoreGraphicsState()
        
        context.restoreGState()
    }
    
    private func drawRuler(in context: CGContext) {
        context.saveGState()
        context.translateBy(x: rulerOrigin.x, y: rulerOrigin.y)
        context.rotate(by: rulerAngle)
        let rulerRect = CGRect(x: 0, y: -25, width: 400, height: 50)
        context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.18).cgColor)
        context.setStrokeColor(NSColor.systemBlue.withAlphaComponent(0.55).cgColor)
        context.setLineWidth(1.5)
        let clipPath = CGPath(roundedRect: rulerRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
        context.addPath(clipPath)
        context.fillPath()
        context.addPath(clipPath)
        context.strokePath()
        context.restoreGState()
    }
    
    // MARK: - Event Handling
    
    private func extractPressure(from event: NSEvent, location: CGPoint) -> Double {
        let rawPressure = Double(event.pressure)
        let isTablet = event.subtype == .tabletPoint ||
                       event.subtype == .tabletProximity ||
                       event.pointingDeviceType == .pen ||
                       event.pointingDeviceType == .eraser
        
        var deviceDesc = "Mysz / Gładzik"
        if event.pointingDeviceType == .eraser {
            deviceDesc = "Gumka rysika (Tablet)"
        } else if isTablet || rawPressure > 0.002 {
            deviceDesc = "Tablet graficzny / Apple Pencil"
        }
        
        if rawPressure > 0.002 {
            let adjusted = pow(rawPressure, 1.0 / max(0.3, pressureSensitivity))
            let finalPressure = max(0.05, min(1.0, adjusted))
            delegate?.canvasDidUpdateStylus(pressure: finalPressure, device: deviceDesc, isDown: true)
            return finalPressure
        }
        
        if simulatePressureIfZero {
            let curTime = event.timestamp
            let dt = max(0.010, curTime - lastVelocityTimestamp)
            let dist = ShapeRecognizer.shared.distance(lastVelocityLocation, location)
            lastVelocityLocation = location
            lastVelocityTimestamp = curTime
            let speed = dist / CGFloat(dt)
            let velocityFactor = max(0.18, min(0.92, 1.0 - (speed / 1100.0)))
            let finalPressure = Double(velocityFactor)
            delegate?.canvasDidUpdateStylus(pressure: finalPressure, device: deviceDesc + " (kaligrafia)", isDown: true)
            return finalPressure
        }
        
        delegate?.canvasDidUpdateStylus(pressure: 0.5, device: deviceDesc, isDown: true)
        return 0.5
    }
    
    public override func tabletProximity(with event: NSEvent) {
        let isEntering = event.isEnteringProximity
        let deviceType = event.pointingDeviceType == .eraser ? "Gumka rysika" : "Rysik tabletu"
        if isEntering {
            delegate?.canvasDidUpdateStylus(pressure: 0.0, device: "\(deviceType) (w zasięgu)", isDown: false)
        }
    }
    
    public override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let location = convert(event.locationInWindow, from: nil)
        lastVelocityLocation = location
        lastVelocityTimestamp = event.timestamp
        
        // Deselect active text box / sticky note / table when clicking on canvas
        delegate?.canvasDidDeselectAll()
        
        // 1. Check if clicking interactive handles of active shape
        if let editingId = activeEditingStrokeId,
           let stroke = strokes.first(where: { $0.id == editingId }),
           let shape = stroke.recognizedShape {
            
            // Check arrow flip button
            if shape.kind == .arrow || shape.kind == .doubleArrow {
                let midPoint = CGPoint(x: (shape.startPoint.x + shape.endPoint.x)/2.0, y: (shape.startPoint.y + shape.endPoint.y)/2.0 - 24)
                let pillRect = CGRect(x: midPoint.x - 70, y: midPoint.y - 14, width: 140, height: 28)
                if pillRect.contains(location) {
                    delegate?.canvasDidReverseArrow(strokeId: editingId)
                    return
                }
                
                // Check endpoints
                if ShapeRecognizer.shared.distance(location, shape.startPoint) < 14 {
                    dragMode = .movingShapeEndpoint(strokeId: editingId, isStart: true)
                    return
                }
                if ShapeRecognizer.shared.distance(location, shape.endPoint) < 14 {
                    dragMode = .movingShapeEndpoint(strokeId: editingId, isStart: false)
                    return
                }
            } else {
                // Check 8 bounding box resize handles
                let b = shape.bounds.insetBy(dx: -4, dy: -4)
                if let handle = hitTestHandle(location: location, bounds: b) {
                    dragMode = .resizingShapeHandle(strokeId: editingId, handle: handle, originalBounds: shape.bounds, startLocation: location)
                    return
                }
            }
        }
        
        // 2. Check if clicking inside lasso selection to move it
        if !selectedStrokeIds.isEmpty {
            var combinedBox: CGRect? = nil
            for s in strokes where selectedStrokeIds.contains(s.id) {
                combinedBox = combinedBox == nil ? s.boundingBox : combinedBox!.union(s.boundingBox)
            }
            if let box = combinedBox, box.insetBy(dx: -10, dy: -10).contains(location) {
                dragMode = .movingSelection(lastLocation: location)
                return
            }
        }
        
        let pressure = extractPressure(from: event, location: location)
        let effectiveTool: DrawingTool = (event.pointingDeviceType == .eraser) ? .eraser : currentTool
        
        // 3. Pointer Tool (Dedicated moving/selecting objects, never draws or creates text)
        if effectiveTool == .pointer {
            for s in strokes.reversed() {
                if s.boundingBox.insetBy(dx: -10, dy: -10).contains(location) {
                    selectedStrokeIds = [s.id]
                    activeEditingStrokeId = s.id
                    delegate?.canvasDidSelectStrokes(ids: selectedStrokeIds)
                    dragMode = .movingSelection(lastLocation: location)
                    needsDisplay = true
                    return
                }
            }
            selectedStrokeIds.removeAll()
            activeEditingStrokeId = nil
            delegate?.canvasDidSelectStrokes(ids: [])
            needsDisplay = true
            return
        }
        
        // 4. Lasso Tool
        if effectiveTool == .lasso {
            dragMode = .lassoing
            lassoPoints = [location]
            selectedStrokeIds.removeAll()
            activeEditingStrokeId = nil
            delegate?.canvasDidSelectStrokes(ids: [])
            needsDisplay = true
            return
        }
        
        // 5. Text Tool
        if effectiveTool == .text {
            delegate?.canvasDidSelectTextBox(at: location)
            currentTool = .pointer
            delegate?.canvasDidChangeTool(.pointer)
            needsDisplay = true
            return
        }
        
        // 6. Sticky Tool
        if effectiveTool == .sticky {
            delegate?.canvasDidSelectStickyNote(at: location)
            currentTool = .pointer
            delegate?.canvasDidChangeTool(.pointer)
            needsDisplay = true
            return
        }
        
        // 6. Eraser Tool
        if effectiveTool == .eraser {
            dragMode = .erasing
            eraseStrokesNear(point: location)
            return
        }
        
        // 7. Laser Pointer Tool (Temporary glowing trail that auto-fades)
        if effectiveTool == .laser {
            dragMode = .drawing
            addLaserPoint(location)
            return
        }
        
        // 8. Drawing Tools (Pen, Calligraphy, Brush, Pencil, Crayon, Shape)
        // Clear previous selection
        selectedStrokeIds.removeAll()
        activeEditingStrokeId = nil
        delegate?.canvasDidSelectStrokes(ids: [])
        
        dragMode = .drawing
        isDrawing = true
        hasHoldSnapped = false
        inProgressShapePreview = nil
        inProgressPoints = [StrokePoint(x: Double(location.x), y: Double(location.y), pressure: pressure)]
        lastDragPoint = location
        
        if effectiveTool == .shape && currentShapeKind != .auto {
            inProgressShapePreview = GeometricShapeData(
                kind: currentShapeKind,
                start: location,
                end: location,
                bounds: CGRect(origin: location, size: .zero)
            )
        } else if autoCorrectShapes && drawAndHoldEnabled {
            startHoldTimer()
        }
        
        needsDisplay = true
    }
    
    public override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        
        switch dragMode {
        case .none:
            return
            
        case .erasing:
            eraseStrokesNear(point: location)
            return
            
        case .lassoing:
            lassoPoints.append(location)
            needsDisplay = true
            return
            
        case .movingSelection(let lastLoc):
            let delta = CGSize(width: location.x - lastLoc.x, height: location.y - lastLoc.y)
            dragMode = .movingSelection(lastLocation: location)
            delegate?.canvasDidMoveSelectedStrokes(by: delta)
            needsDisplay = true
            return
            
        case .movingShapeEndpoint(let strokeId, let isStart):
            if let stroke = strokes.first(where: { $0.id == strokeId }), let shape = stroke.recognizedShape {
                let newStart = isStart ? location : shape.startPoint
                let newEnd = isStart ? shape.endPoint : location
                delegate?.canvasDidUpdateShapeEndpoints(strokeId: strokeId, start: newStart, end: newEnd)
                needsDisplay = true
            }
            return
            
        case .resizingShapeHandle(let strokeId, let handle, let origBounds, let startLoc):
            let dx = location.x - startLoc.x
            let dy = location.y - startLoc.y
            var nb = origBounds
            
            switch handle {
            case .bottomRight:
                nb.size.width = max(15, origBounds.width + dx)
                nb.size.height = max(15, origBounds.height + dy)
            case .right:
                nb.size.width = max(15, origBounds.width + dx)
            case .bottom:
                nb.size.height = max(15, origBounds.height + dy)
            case .topLeft:
                nb.origin.x = min(origBounds.maxX - 15, origBounds.origin.x + dx)
                nb.origin.y = min(origBounds.maxY - 15, origBounds.origin.y + dy)
                nb.size.width = origBounds.maxX - nb.origin.x
                nb.size.height = origBounds.maxY - nb.origin.y
            case .topRight:
                nb.origin.y = min(origBounds.maxY - 15, origBounds.origin.y + dy)
                nb.size.width = max(15, origBounds.width + dx)
                nb.size.height = origBounds.maxY - nb.origin.y
            case .bottomLeft:
                nb.origin.x = min(origBounds.maxX - 15, origBounds.origin.x + dx)
                nb.size.width = origBounds.maxX - nb.origin.x
                nb.size.height = max(15, origBounds.height + dy)
            case .top:
                nb.origin.y = min(origBounds.maxY - 15, origBounds.origin.y + dy)
                nb.size.height = origBounds.maxY - nb.origin.y
            case .left:
                nb.origin.x = min(origBounds.maxX - 15, origBounds.origin.x + dx)
                nb.size.width = origBounds.maxX - nb.origin.x
            }
            delegate?.canvasDidUpdateShapeBounds(strokeId: strokeId, newBounds: nb)
            needsDisplay = true
            return
            
        case .drawing:
            let effectiveTool: DrawingTool = (event.pointingDeviceType == .eraser) ? .eraser : currentTool
            if effectiveTool == .laser {
                addLaserPoint(location)
                return
            }
            
            let pressure = extractPressure(from: event, location: location)
            let effectiveLocation = isRulerVisible ? snapToRuler(location) : location
            
            let moveDist = ShapeRecognizer.shared.distance(lastDragPoint, effectiveLocation)
            if moveDist > 5.0 {
                lastDragPoint = effectiveLocation
                if autoCorrectShapes && !hasHoldSnapped && drawAndHoldEnabled {
                    startHoldTimer()
                }
            }
            
            if currentTool == .shape && currentShapeKind != .auto {
                if let start = inProgressPoints.first?.cgPoint {
                    let rect = CGRect(
                        x: min(start.x, effectiveLocation.x),
                        y: min(start.y, effectiveLocation.y),
                        width: abs(effectiveLocation.x - start.x),
                        height: abs(effectiveLocation.y - start.y)
                    )
                    inProgressShapePreview = GeometricShapeData(
                        kind: currentShapeKind,
                        start: start,
                        end: effectiveLocation,
                        bounds: rect
                    )
                }
            } else {
                if let last = inProgressPoints.last {
                    let dist = ShapeRecognizer.shared.distance(last.cgPoint, effectiveLocation)
                    if dist < 1.2 {
                        return
                    }
                }
                inProgressPoints.append(StrokePoint(x: Double(effectiveLocation.x), y: Double(effectiveLocation.y), pressure: pressure))
            }
            needsDisplay = true
        }
    }
    
    public override func mouseUp(with event: NSEvent) {
        cancelHoldTimer()
        delegate?.canvasDidUpdateStylus(pressure: 0.0, device: "Rysik w gotowości", isDown: false)
        
        switch dragMode {
        case .erasing:
            dragMode = .none
            needsDisplay = true
            return
            
        case .lassoing:
            dragMode = .none
            // Enclose strokes inside lasso loop
            if lassoPoints.count >= 3 {
                let path = CGMutablePath()
                path.move(to: lassoPoints[0])
                for p in lassoPoints.dropFirst() { path.addLine(to: p) }
                path.closeSubpath()
                
                var enclosedIds = Set<UUID>()
                for stroke in strokes {
                    let box = stroke.boundingBox
                    if path.contains(CGPoint(x: box.midX, y: box.midY)) || stroke.points.contains(where: { path.contains($0.cgPoint) }) {
                        enclosedIds.insert(stroke.id)
                    }
                }
                
                selectedStrokeIds = enclosedIds
                if enclosedIds.count == 1 {
                    activeEditingStrokeId = enclosedIds.first
                } else {
                    activeEditingStrokeId = nil
                }
                delegate?.canvasDidSelectStrokes(ids: enclosedIds)
            }
            lassoPoints.removeAll()
            needsDisplay = true
            return
            
        case .movingSelection, .movingShapeEndpoint, .resizingShapeHandle:
            dragMode = .none
            needsDisplay = true
            return
            
        case .drawing:
            dragMode = .none
            isDrawing = false
            
            if currentTool == .laser {
                inProgressPoints.removeAll()
                needsDisplay = true
                return
            }
            
            cancelHoldTimer()
            var finalShape: GeometricShapeData? = inProgressShapePreview
            var isAutoCorrected = hasHoldSnapped
            
            if !autoCorrectShapes && currentTool != .shape {
                finalShape = nil
                isAutoCorrected = false
            } else if currentTool != .shape && !hasHoldSnapped {
                // Natural drawing: lifted stroke without holding still -> keep as natural handwriting!
                finalShape = nil
                isAutoCorrected = false
            }
            
            let finalPoints = (finalShape == nil) ? smoothPoints(inProgressPoints) : []
            let newStroke = DrawingStroke(
                tool: currentTool,
                colorHex: currentColorHex,
                baseWidth: currentBaseWidth,
                opacity: 1.0,
                points: finalPoints,
                isAutoCorrected: isAutoCorrected,
                recognizedShape: finalShape
            )
            
            delegate?.canvasDidAddStroke(newStroke)
            
            inProgressPoints.removeAll()
            inProgressShapePreview = nil
            hasHoldSnapped = false
            needsDisplay = true
            
        case .none:
            break
        }
    }
    
    // MARK: - Tablet Stylus Secondary Button (Barrel Button 1 / Right Click)
    
    public override func rightMouseDown(with event: NSEvent) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(self)
        let location = convert(event.locationInWindow, from: nil)
        rightClickDownPoint = location
        isRightClickErasing = false
        
        // Holding barrel button 1 allows instant erasing under stylus nib!
        eraseStrokesNear(point: location)
        isRightClickErasing = true
        needsDisplay = true
    }
    
    public override func rightMouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if ShapeRecognizer.shared.distance(rightClickDownPoint, location) > 3.0 {
            isRightClickErasing = true
        }
        if isRightClickErasing {
            eraseStrokesNear(point: location)
            needsDisplay = true
        }
    }
    
    public override func rightMouseUp(with event: NSEvent) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        let location = convert(event.locationInWindow, from: nil)
        let movedDist = ShapeRecognizer.shared.distance(rightClickDownPoint, location)
        
        // If clicked without dragging (under 4 pt), open right-click context menu (PPM)
        if movedDist <= 4.0 {
            if let contextMenu = menu(for: event) {
                NSMenu.popUpContextMenu(contextMenu, with: event, for: self)
            }
        }
        
        isRightClickErasing = false
        needsDisplay = true
    }
    
    // MARK: - Tablet ExpressKeys & Stylus Barrel Button 2 (Other Mouse Buttons)
    
    public override func otherMouseDown(with event: NSEvent) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(self)
        let location = convert(event.locationInWindow, from: nil)
        otherDragStartPoint = location
        isOtherDragging = false
        
        // ExpressKeys / Stylus Buttons mappings:
        // Button 2 (Middle click / Stylus upper barrel button): Panning
        // Button 3 (Tablet ExpressKey 1): Przybliżanie (Zoom In)
        // Button 4 (Tablet ExpressKey 2): Oddalanie (Zoom Out)
        // Button 5 (Tablet ExpressKey 3): Szybkie przełączanie narzędzia (Pióro <-> Gumka)
        // Button 6 / 7: Cofnij / Ponów
        switch event.buttonNumber {
        case 3:
            delegate?.canvasDidRequestZoomIn()
        case 4:
            delegate?.canvasDidRequestZoomOut()
        case 5:
            delegate?.canvasDidToggleEraser()
        case 6:
            delegate?.canvasDidRequestUndo()
        case 7:
            delegate?.canvasDidRequestRedo()
        default:
            break
        }
    }
    
    public override func otherMouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let deltaX = location.x - otherDragStartPoint.x
        let deltaY = location.y - otherDragStartPoint.y
        otherDragStartPoint = location
        
        if event.buttonNumber == 2 {
            // Pan canvas smoothly when dragging with middle mouse or upper barrel button
            if let scrollView = enclosingScrollView {
                let curOrigin = scrollView.contentView.bounds.origin
                let newOrigin = CGPoint(x: curOrigin.x - deltaX, y: curOrigin.y - deltaY)
                scrollView.contentView.scroll(to: newOrigin)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }
    }
    
    public override func otherMouseUp(with event: NSEvent) {
        isOtherDragging = false
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
    
    // MARK: - Eraser Logic (Fixed with permanent state synchronization)
    
    private func eraseStrokesNear(point: CGPoint) {
        let eraseRadius: CGFloat = 22.0
        var erasedIds = Set<UUID>()
        
        for stroke in strokes {
            if let shape = stroke.recognizedShape {
                let dist = ShapeRecognizer.shared.distance(point, CGPoint(x: shape.bounds.midX, y: shape.bounds.midY))
                if dist < max(eraseRadius * 2, max(shape.bounds.width, shape.bounds.height) / 2.0) {
                    erasedIds.insert(stroke.id)
                }
            } else {
                for p in stroke.points {
                    let dist = ShapeRecognizer.shared.distance(point, p.cgPoint)
                    if dist <= eraseRadius {
                        erasedIds.insert(stroke.id)
                        break
                    }
                }
            }
        }
        
        if !erasedIds.isEmpty {
            strokes.removeAll(where: { erasedIds.contains($0.id) })
            delegate?.canvasDidEraseStrokes(ids: erasedIds)
            needsDisplay = true
        }
    }
    
    // MARK: - Draw & Hold Shape Detection Timer
    
    private func startHoldTimer() {
        guard autoCorrectShapes && drawAndHoldEnabled else { return }
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: false) { [weak self] _ in
            self?.handleHoldGesture()
        }
    }
    
    private func cancelHoldTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
    }
    
    private func handleHoldGesture() {
        guard autoCorrectShapes && isDrawing && !hasHoldSnapped && inProgressPoints.count >= 8 else { return }
        
        // Prevent snapping when writing small handwriting (letters, accents, notes)
        let xs = inProgressPoints.map(\.x)
        let ys = inProgressPoints.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return }
        let w = maxX - minX
        let h = maxY - minY
        guard max(w, h) >= 30 else { return }
        
        if let recognized = ShapeRecognizer.shared.recognizeShape(from: inProgressPoints) {
            inProgressShapePreview = recognized
            hasHoldSnapped = true
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
            needsDisplay = true
        }
    }
    
    // MARK: - Trackpad Gestures & Smooth Zoom
    
    public override func magnify(with event: NSEvent) {
        let magnification = event.magnification
        let cur = delegate?.canvasCurrentZoomScale() ?? 1.0
        let newZoom = max(0.4, min(3.0, cur + magnification))
        delegate?.canvasDidUpdateZoom(newZoom)
    }
    
    public override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            let delta = event.scrollingDeltaY
            let cur = delegate?.canvasCurrentZoomScale() ?? 1.0
            let newZoom = max(0.4, min(3.0, cur + (delta > 0 ? 0.08 : -0.08)))
            delegate?.canvasDidUpdateZoom(newZoom)
        } else {
            super.scrollWheel(with: event)
        }
    }
    
    public override func smartMagnify(with event: NSEvent) {
        let cur = delegate?.canvasCurrentZoomScale() ?? 1.0
        let target: CGFloat = abs(cur - 1.0) < 0.1 ? 1.5 : 1.0
        delegate?.canvasDidUpdateZoom(target)
    }
    
    // MARK: - Clipboard Paste (⌘V), Undo/Redo (⌘Z), Zoom Shortcuts & Drag and Drop for Images
    
    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let chars = event.charactersIgnoringModifiers ?? ""
        
        // Command+Z or Ctrl+Z (Cofnij) - kluczowe dla przycisków piórka tabletu graficznego
        if (flags == .command || flags == .control) && chars.lowercased() == "z" {
            delegate?.canvasDidRequestUndo()
            return true
        }
        // Command+Shift+Z or Ctrl+Y / Command+Y (Ponów)
        if (flags == [.command, .shift] && chars.lowercased() == "z") ||
           ((flags == .command || flags == .control) && chars.lowercased() == "y") {
            delegate?.canvasDidRequestRedo()
            return true
        }
        // Przybliżanie: Command + (+ lub =), lub Ctrl + (+ lub =)
        if (flags.contains(.command) || flags.contains(.control)) && (chars == "+" || chars == "=") {
            delegate?.canvasDidRequestZoomIn()
            return true
        }
        // Oddalanie: Command + (- lub _), lub Ctrl + (- lub _)
        if (flags.contains(.command) || flags.contains(.control)) && (chars == "-" || chars == "_") {
            delegate?.canvasDidRequestZoomOut()
            return true
        }
        // Rzeczywisty rozmiar: Command + 0
        if (flags.contains(.command) || flags.contains(.control)) && chars == "0" {
            delegate?.canvasDidRequestZoomReset()
            return true
        }
        // Command+C (Kopiuj)
        if flags == .command && chars.lowercased() == "c" {
            delegate?.canvasDidCopySelection()
            return true
        }
        // Command+V (Wklej)
        if flags == .command && chars.lowercased() == "v" {
            if pasteImageFromPasteboard() {
                return true
            }
            delegate?.canvasDidPasteSelection()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
    
    private func pasteImageFromPasteboard(at point: CGPoint? = nil) -> Bool {
        let pb = NSPasteboard.general
        let targetPoint = point ?? CGPoint(x: bounds.midX, y: bounds.midY)
        
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let firstURL = urls.first {
            if let data = try? Data(contentsOf: firstURL), NSImage(data: data) != nil {
                delegate?.canvasDidPasteImage(data: data, at: targetPoint)
                return true
            }
        }
        
        if let image = NSImage(pasteboard: pb),
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            delegate?.canvasDidPasteImage(data: png, at: targetPoint)
            return true
        }
        return false
    }
    
    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        let dropPoint = convert(sender.draggingLocation, from: nil)
        
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let firstURL = urls.first {
            if let data = try? Data(contentsOf: firstURL), NSImage(data: data) != nil {
                delegate?.canvasDidPasteImage(data: data, at: dropPoint)
                return true
            }
        }
        
        if let image = NSImage(pasteboard: pb),
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            delegate?.canvasDidPasteImage(data: png, at: dropPoint)
            return true
        }
        return false
    }
    
    // MARK: - Resize Handle Hit Testing
    
    private func hitTestHandle(location: CGPoint, bounds: CGRect) -> ResizeHandle? {
        let r: CGFloat = 12.0
        if ShapeRecognizer.shared.distance(location, CGPoint(x: bounds.maxX, y: bounds.maxY)) < r { return .bottomRight }
        if ShapeRecognizer.shared.distance(location, CGPoint(x: bounds.minX, y: bounds.minY)) < r { return .topLeft }
        if ShapeRecognizer.shared.distance(location, CGPoint(x: bounds.maxX, y: bounds.minY)) < r { return .topRight }
        if ShapeRecognizer.shared.distance(location, CGPoint(x: bounds.minX, y: bounds.maxY)) < r { return .bottomLeft }
        if ShapeRecognizer.shared.distance(location, CGPoint(x: bounds.midX, y: bounds.minY)) < r { return .top }
        if ShapeRecognizer.shared.distance(location, CGPoint(x: bounds.maxX, y: bounds.midY)) < r { return .right }
        if ShapeRecognizer.shared.distance(location, CGPoint(x: bounds.midX, y: bounds.maxY)) < r { return .bottom }
        if ShapeRecognizer.shared.distance(location, CGPoint(x: bounds.minX, y: bounds.midY)) < r { return .left }
        return nil
    }
    
    private func snapToRuler(_ point: CGPoint) -> CGPoint {
        let topEdgeY = rulerOrigin.y - 25
        let bottomEdgeY = rulerOrigin.y + 25
        if abs(point.y - topEdgeY) < 18 { return CGPoint(x: point.x, y: topEdgeY) }
        else if abs(point.y - bottomEdgeY) < 18 { return CGPoint(x: point.x, y: bottomEdgeY) }
        return point
    }
    
    // MARK: - Laser Pointer Trail & Auto-Fade
    
    private func addLaserPoint(_ pt: CGPoint) {
        laserPoints.append((point: pt, time: Date()))
        if laserTimer == nil {
            laserTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
                self?.tickLaserFade()
            }
        }
        needsDisplay = true
    }
    
    private func tickLaserFade() {
        let now = Date()
        laserPoints.removeAll(where: { now.timeIntervalSince($0.time) > 1.1 })
        if laserPoints.isEmpty {
            laserTimer?.invalidate()
            laserTimer = nil
        }
        needsDisplay = true
    }
    
    private func drawLaserTrail(in context: CGContext) {
        guard !laserPoints.isEmpty else { return }
        let now = Date()
        context.saveGState()
        context.setShadow(offset: .zero, blur: 10.0, color: NSColor.systemRed.cgColor)
        
        if laserPoints.count >= 2 {
            for i in 1..<laserPoints.count {
                let p1 = laserPoints[i - 1].point
                let p2 = laserPoints[i].point
                let age = now.timeIntervalSince(laserPoints[i].time)
                let alpha = max(0.0, min(1.0, 1.0 - CGFloat(age / 1.1)))
                
                context.setStrokeColor(NSColor.systemRed.withAlphaComponent(alpha).cgColor)
                context.setLineWidth(max(2.0, 5.0 * alpha))
                context.setLineCap(.round)
                context.beginPath()
                context.move(to: p1)
                context.addLine(to: p2)
                context.strokePath()
            }
        }
        
        if let latest = laserPoints.last {
            let age = now.timeIntervalSince(latest.time)
            let alpha = max(0.0, min(1.0, 1.0 - CGFloat(age / 1.1)))
            let r: CGFloat = 6.0
            let dotRect = CGRect(x: latest.point.x - r, y: latest.point.y - r, width: r * 2, height: r * 2)
            context.setFillColor(NSColor.systemRed.withAlphaComponent(alpha).cgColor)
            context.fillEllipse(in: dotRect)
            
            context.setFillColor(NSColor.white.withAlphaComponent(alpha).cgColor)
            context.fillEllipse(in: dotRect.insetBy(dx: 2.0, dy: 2.0))
        }
        context.restoreGState()
    }
    
    // MARK: - Keyboard Shortcuts (Command+Z, Command+C, Command+V, Zoom, Delete)
    
    public override func keyDown(with event: NSEvent) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let chars = event.charactersIgnoringModifiers ?? ""
        
        // Command+Z (Undo)
        if (flags == .command || flags == .control) && chars.lowercased() == "z" {
            delegate?.canvasDidRequestUndo()
            return
        }
        
        // Command+Shift+Z or Ctrl+Y (Redo)
        if (flags == [.command, .shift] && chars.lowercased() == "z") ||
           ((flags == .command || flags == .control) && chars.lowercased() == "y") {
            delegate?.canvasDidRequestRedo()
            return
        }
        
        // Przybliżanie: Command + (+ lub =), lub sam klawisz + / = gdy płótno ma fokus
        if (flags.contains(.command) || flags.contains(.control)) && (chars == "+" || chars == "=") {
            delegate?.canvasDidRequestZoomIn()
            return
        }
        
        // Oddalanie: Command + (- lub _), lub sam klawisz - gdy płótno ma fokus
        if (flags.contains(.command) || flags.contains(.control)) && (chars == "-" || chars == "_") {
            delegate?.canvasDidRequestZoomOut()
            return
        }
        
        // Rzeczywisty rozmiar (100%): Command + 0
        if (flags.contains(.command) || flags.contains(.control)) && chars == "0" {
            delegate?.canvasDidRequestZoomReset()
            return
        }
        
        if flags == .command {
            if chars.lowercased() == "c" {
                delegate?.canvasDidCopySelection()
                return
            } else if chars.lowercased() == "v" {
                if pasteImageFromPasteboard() {
                    return
                }
                delegate?.canvasDidPasteSelection()
                return
            }
        } else if event.keyCode == 51 || event.keyCode == 117 { // Backspace lub Delete
            if !selectedStrokeIds.isEmpty {
                delegate?.canvasDidDeleteSelectedStrokes()
                selectedStrokeIds.removeAll()
                activeEditingStrokeId = nil
                needsDisplay = true
                return
            }
        }
        super.keyDown(with: event)
    }
    
    // MARK: - Standard Responder Undo/Redo Actions
    
    @objc public func undo(_ sender: Any?) {
        delegate?.canvasDidRequestUndo()
    }
    
    @objc public func redo(_ sender: Any?) {
        delegate?.canvasDidRequestRedo()
    }
    
    // MARK: - Right Click Context Menu (PPM)
    
    public override func menu(for event: NSEvent) -> NSMenu? {
        let location = convert(event.locationInWindow, from: nil)
        let menu = NSMenu(title: "Opcje kartki")
        
        // 1. Schowek i Edycja
        let copyItem = NSMenuItem(title: "Kopiuj", action: #selector(contextMenuCopy(_:)), keyEquivalent: "c")
        copyItem.target = self
        menu.addItem(copyItem)
        
        let pasteItem = NSMenuItem(title: "Wklej w tym miejscu", action: #selector(contextMenuPaste(_:)), keyEquivalent: "v")
        pasteItem.representedObject = NSValue(point: location)
        pasteItem.target = self
        menu.addItem(pasteItem)
        
        let selectAllItem = NSMenuItem(title: "Zaznacz wszystko", action: #selector(contextMenuSelectAll(_:)), keyEquivalent: "a")
        selectAllItem.target = self
        menu.addItem(selectAllItem)
        
        let deleteItem = NSMenuItem(title: "Usuń zaznaczone", action: #selector(contextMenuDelete(_:)), keyEquivalent: "")
        deleteItem.target = self
        menu.addItem(deleteItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 2. Wstawianie Obiektów w tym miejscu
        let insertSubmenu = NSMenu(title: "Wstaw")
        
        let addText = NSMenuItem(title: "Pole tekstowe", action: #selector(contextMenuInsertText(_:)), keyEquivalent: "t")
        addText.representedObject = NSValue(point: location)
        addText.target = self
        insertSubmenu.addItem(addText)
        
        let addSticky = NSMenuItem(title: "Karteczka Post-it", action: #selector(contextMenuInsertSticky(_:)), keyEquivalent: "s")
        addSticky.representedObject = NSValue(point: location)
        addSticky.target = self
        insertSubmenu.addItem(addSticky)
        
        let addTable = NSMenuItem(title: "Tabela", action: #selector(contextMenuInsertTable(_:)), keyEquivalent: "")
        addTable.representedObject = NSValue(point: location)
        addTable.target = self
        insertSubmenu.addItem(addTable)
        
        insertSubmenu.addItem(NSMenuItem.separator())
        
        // Kształty
        let shapesMenu = NSMenu(title: "Kształt")
        let shapeList: [(ShapeKind, String)] = [
            (.rectangle, "Prostokąt"),
            (.circle, "Koło / Elipsa"),
            (.triangle, "Trójkąt"),
            (.line, "Prosta linia"),
            (.arrow, "Strzałka"),
            (.doubleArrow, "Strzałka obustronna"),
            (.rhombus, "Romb"),
            (.parallelogram, "Równoległobok"),
            (.trapezoid, "Trapez"),
            (.rightTrapezoid, "Trapez prostokątny (lewy)"),
            (.rightTrapezoidRight, "Trapez prostokątny (prawy)"),
            (.hexagon, "Sześciokąt")
        ]
        for (kind, name) in shapeList {
            let item = NSMenuItem(title: name, action: #selector(contextMenuInsertShape(_:)), keyEquivalent: "")
            item.representedObject = ContextShapePayload(kind: kind, location: location)
            item.target = self
            shapesMenu.addItem(item)
        }
        let shapesMenuItem = NSMenuItem(title: "Kształt geometryczny", action: nil, keyEquivalent: "")
        shapesMenuItem.submenu = shapesMenu
        insertSubmenu.addItem(shapesMenuItem)
        
        let insertMenuItem = NSMenuItem(title: "Wstaw...", action: nil, keyEquivalent: "")
        insertMenuItem.submenu = insertSubmenu
        menu.addItem(insertMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 3. Narzędzia rysowania
        let toolsSubmenu = NSMenu(title: "Narzędzia")
        let toolList: [(DrawingTool, String)] = [
            (.pen, "Pióro kulkowe"),
            (.pencil, "Ołówek"),
            (.highlighter, "Zakreślacz"),
            (.calligraphy, "Pędzel kaligraficzny"),
            (.eraser, "Gumka do mazania"),
            (.pointer, "Kursor"),
            (.lasso, "Lasso")
        ]
        for (tool, name) in toolList {
            let item = NSMenuItem(title: name, action: #selector(contextMenuSelectTool(_:)), keyEquivalent: "")
            item.representedObject = tool.rawValue
            item.target = self
            if currentTool == tool { item.state = .on }
            toolsSubmenu.addItem(item)
        }
        let toolsMenuItem = NSMenuItem(title: "Wybierz narzędzie", action: nil, keyEquivalent: "")
        toolsMenuItem.submenu = toolsSubmenu
        menu.addItem(toolsMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 4. Styl papieru
        let paperSubmenu = NSMenu(title: "Styl papieru")
        for style in PaperStyle.allCases {
            let item = NSMenuItem(title: style.rawValue, action: #selector(contextMenuSetPaperStyle(_:)), keyEquivalent: "")
            item.representedObject = style.rawValue
            item.target = self
            if paperStyle == style { item.state = .on }
            paperSubmenu.addItem(item)
        }
        let paperMenuItem = NSMenuItem(title: "Styl papieru", action: nil, keyEquivalent: "")
        paperMenuItem.submenu = paperSubmenu
        menu.addItem(paperMenuItem)
        
        // Kolor papieru
        let colorSubmenu = NSMenu(title: "Kolor kartki")
        for col in PaperColor.allCases {
            let item = NSMenuItem(title: col.rawValue, action: #selector(contextMenuSetPaperColor(_:)), keyEquivalent: "")
            item.representedObject = col.rawValue
            item.target = self
            if paperColor == col { item.state = .on }
            colorSubmenu.addItem(item)
        }
        let colorMenuItem = NSMenuItem(title: "Kolor kartki", action: nil, keyEquivalent: "")
        colorMenuItem.submenu = colorSubmenu
        menu.addItem(colorMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 5. Wyczyść stronę
        let clearItem = NSMenuItem(title: "Wyczyść kartkę", action: #selector(contextMenuClearPage(_:)), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)
        
        return menu
    }
    
    @objc private func contextMenuCopy(_ sender: Any?) {
        delegate?.canvasDidCopySelection()
    }
    
    @objc private func contextMenuPaste(_ sender: NSMenuItem) {
        delegate?.canvasDidPasteSelection()
    }
    
    @objc private func contextMenuSelectAll(_ sender: Any?) {
        delegate?.canvasDidSelectAll()
    }
    
    @objc private func contextMenuDelete(_ sender: Any?) {
        delegate?.canvasDidDeleteSelectedStrokes()
    }
    
    @objc private func contextMenuInsertText(_ sender: NSMenuItem) {
        let loc = (sender.representedObject as? NSValue)?.pointValue ?? CGPoint(x: 300, y: 300)
        delegate?.canvasDidInsertTextBox(at: loc)
    }
    
    @objc private func contextMenuInsertSticky(_ sender: NSMenuItem) {
        let loc = (sender.representedObject as? NSValue)?.pointValue ?? CGPoint(x: 300, y: 300)
        delegate?.canvasDidInsertStickyNote(at: loc)
    }
    
    @objc private func contextMenuInsertTable(_ sender: NSMenuItem) {
        let loc = (sender.representedObject as? NSValue)?.pointValue ?? CGPoint(x: 300, y: 300)
        delegate?.canvasDidInsertTable(at: loc)
    }
    
    @objc private func contextMenuInsertShape(_ sender: NSMenuItem) {
        if let payload = sender.representedObject as? ContextShapePayload {
            delegate?.canvasDidInsertShape(kind: payload.kind, at: payload.location)
        }
    }
    
    @objc private func contextMenuSelectTool(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let tool = DrawingTool(rawValue: raw) {
            currentTool = tool
            delegate?.canvasDidChangeTool(tool)
        }
    }
    
    @objc private func contextMenuSetPaperStyle(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let style = PaperStyle(rawValue: raw) {
            delegate?.canvasDidChangePaperStyle(style)
        }
    }
    
    @objc private func contextMenuSetPaperColor(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let col = PaperColor(rawValue: raw) {
            delegate?.canvasDidChangePaperColor(col)
        }
    }
    
    @objc private func contextMenuClearPage(_ sender: Any?) {
        delegate?.canvasDidClearPage()
    }
}

// MARK: - Context Menu Helper Type
private class ContextShapePayload: NSObject {
    let kind: ShapeKind
    let location: CGPoint
    init(kind: ShapeKind, location: CGPoint) {
        self.kind = kind
        self.location = location
    }
}
