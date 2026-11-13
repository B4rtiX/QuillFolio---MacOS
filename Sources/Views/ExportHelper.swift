import AppKit
import CoreGraphics
import UniformTypeIdentifiers

public final class ExportHelper {
    
    public static func exportNoteToPDF(note: Note) {
        let savePanel = NSSavePanel()
        savePanel.title = "Eksportuj notatkę jako PDF"
        savePanel.nameFieldStringValue = "\(note.title).pdf"
        savePanel.allowedContentTypes = [.pdf]
        
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            renderPDF(note: note, to: url)
        }
    }
    
    public static func exportPageToPNG(note: Note, pageIndex: Int) {
        let savePanel = NSSavePanel()
        savePanel.title = "Eksportuj stronę jako PNG"
        savePanel.nameFieldStringValue = "\(note.title)_strona_\(pageIndex + 1).png"
        savePanel.allowedContentTypes = [.png]
        
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            renderPNG(note: note, pageIndex: pageIndex, to: url)
        }
    }
    
    private static func renderPDF(note: Note, to url: URL) {
        let pageRect = CGRect(x: 0, y: 0, width: 1200, height: 1600)
        
        guard let consumer = CGDataConsumer(url: url as CFURL) else { return }
        var mediaBox = pageRect
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }
        
        for page in note.pages {
            context.beginPage(mediaBox: &mediaBox)
            
            // Draw paper background
            PaperRenderer.drawPaper(in: pageRect, style: note.paperStyle, color: note.paperColor, context: context)
            
            // Draw images
            for img in page.images {
                drawImage(img, in: context)
            }
            
            // Draw strokes
            for stroke in page.strokes {
                drawStroke(stroke, paperColor: note.paperColor, in: context)
            }
            
            // Draw text boxes
            for textBox in page.textBoxes {
                drawTextBox(textBox, isDark: note.paperColor.isDark, in: context)
            }
            
            // Draw sticky notes
            for sticky in page.stickyNotes {
                drawStickyNote(sticky, in: context)
            }
            
            context.endPage()
        }
        
        context.closePDF()
    }
    
    private static func renderPNG(note: Note, pageIndex: Int, to url: URL) {
        let pageRect = CGRect(x: 0, y: 0, width: 1200, height: 1600)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(pageRect.width),
            height: Int(pageRect.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }
        
        let validIdx = max(0, min(pageIndex, note.pages.count - 1))
        let page = note.pages[validIdx]
        
        // Draw paper background
        PaperRenderer.drawPaper(in: pageRect, style: note.paperStyle, color: note.paperColor, context: context)
        
        // Draw images
        for img in page.images {
            drawImage(img, in: context)
        }
        
        // Draw strokes
        for stroke in page.strokes {
            drawStroke(stroke, paperColor: note.paperColor, in: context)
        }
        
        // Draw text boxes
        for textBox in page.textBoxes {
            drawTextBox(textBox, isDark: note.paperColor.isDark, in: context)
        }
        
        // Draw sticky notes
        for sticky in page.stickyNotes {
            drawStickyNote(sticky, in: context)
        }
        
        guard let cgImage = context.makeImage() else { return }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            try? pngData.write(to: url)
        }
    }
    
    // MARK: - Rendering Helpers
    
    private static func drawStroke(_ stroke: DrawingStroke, paperColor: PaperColor, in context: CGContext) {
        context.saveGState()
        let strokeColor = NSColor(hex: stroke.colorHex) ?? (paperColor.isDark ? .white : .black)
        
        if stroke.tool == .highlighter {
            context.setBlendMode(.multiply)
            context.setAlpha(0.38)
            context.setStrokeColor(strokeColor.cgColor)
        } else {
            context.setAlpha(stroke.opacity)
            context.setStrokeColor(strokeColor.cgColor)
            context.setLineCap(.round)
            context.setLineJoin(.round)
        }
        
        if let shape = stroke.recognizedShape {
            context.setLineWidth(CGFloat(stroke.baseWidth * (stroke.tool == .highlighter ? 4.0 : 1.2)))
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
                let arrowLength: CGFloat = max(14.0, CGFloat(stroke.baseWidth) * 4.5)
                let arrowAngle: CGFloat = .pi / 6.0
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
                context.beginPath()
                context.move(to: CGPoint(x: b.midX, y: b.minY))
                context.addLine(to: CGPoint(x: b.maxX, y: b.midY))
                context.addLine(to: CGPoint(x: b.midX, y: b.maxY))
                context.addLine(to: CGPoint(x: b.minX, y: b.midY))
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
            case .roundedRectangle:
                let b = shape.bounds
                let r = min(18.0, min(b.width, b.height) / 3.0)
                let path = CGPath(roundedRect: b, cornerWidth: r, cornerHeight: r, transform: nil)
                context.addPath(path)
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
            context.restoreGState()
            return
        }
        
        let points = stroke.points
        guard points.count > 0 else {
            context.restoreGState()
            return
        }
        
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.interpolationQuality = .high
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        if points.count == 1 {
            let p = points[0].cgPoint
            let r = max(1.0, CGFloat(stroke.baseWidth * (stroke.tool == .highlighter ? 4.0 : points[0].pressure)) / 2.0)
            context.setFillColor(strokeColor.cgColor)
            context.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            context.restoreGState()
            return
        }
        
        let count = points.count
        if count == 2 {
            let p0 = points[0]
            let p1 = points[1]
            let avgPressure = CGFloat((p0.pressure + p1.pressure) / 2.0)
            let widthFactor = (stroke.tool == .pen) ? (0.30 + 1.4 * avgPressure) : (0.45 + 0.90 * avgPressure)
            context.setLineWidth(max(1.0, CGFloat(stroke.baseWidth) * widthFactor))
            context.beginPath()
            context.move(to: p0.cgPoint)
            context.addLine(to: p1.cgPoint)
            context.strokePath()
            context.restoreGState()
            return
        }
        
        // Count >= 3: Smooth quadratic Bézier curves through midpoints
        var prevMid = CGPoint(x: (points[0].x + points[1].x) / 2.0, y: (points[0].y + points[1].y) / 2.0)
        let w0 = max(1.0, CGFloat(stroke.baseWidth) * ((stroke.tool == .pen) ? (0.30 + 1.4 * CGFloat(points[0].pressure)) : (0.45 + 0.90 * CGFloat(points[0].pressure))))
        context.setLineWidth(w0)
        context.beginPath()
        context.move(to: points[0].cgPoint)
        context.addLine(to: prevMid)
        context.strokePath()
        
        for i in 1..<(count - 1) {
            let pCurr = points[i]
            let pNext = points[i + 1]
            let nextMid = CGPoint(x: (pCurr.x + pNext.x) / 2.0, y: (pCurr.y + pNext.y) / 2.0)
            let w = max(1.0, CGFloat(stroke.baseWidth) * ((stroke.tool == .pen) ? (0.30 + 1.4 * CGFloat(pCurr.pressure)) : (0.45 + 0.90 * CGFloat(pCurr.pressure))))
            context.setLineWidth(w)
            context.beginPath()
            context.move(to: prevMid)
            context.addQuadCurve(to: nextMid, control: pCurr.cgPoint)
            context.strokePath()
            prevMid = nextMid
        }
        
        if let last = points.last {
            let wLast = max(1.0, CGFloat(stroke.baseWidth) * ((stroke.tool == .pen) ? (0.30 + 1.4 * CGFloat(last.pressure)) : (0.45 + 0.90 * CGFloat(last.pressure))))
            context.setLineWidth(wLast)
            context.beginPath()
            context.move(to: prevMid)
            context.addLine(to: last.cgPoint)
            context.strokePath()
        }
        
        context.restoreGState()
    }
    
    private static func drawTextBox(_ box: CanvasTextBox, isDark: Bool, in context: CGContext) {
        let str = NSAttributedString(
            string: box.text,
            attributes: [
                .font: NSFont.systemFont(ofSize: CGFloat(box.fontSize)),
                .foregroundColor: NSColor(hex: box.textColorHex) ?? (isDark ? .white : .black)
            ]
        )
        let rect = box.frame
        NSGraphicsContext.saveGraphicsState()
        let nsContext = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.current = nsContext
        str.draw(in: rect)
        NSGraphicsContext.restoreGraphicsState()
    }
    
    private static func drawStickyNote(_ sticky: StickyNote, in context: CGContext) {
        context.saveGState()
        let bg = NSColor(hex: sticky.colorHex) ?? .yellow
        context.setFillColor(bg.cgColor)
        context.fill(sticky.frame)
        
        let str = NSAttributedString(
            string: sticky.text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: NSColor.black
            ]
        )
        let textRect = sticky.frame.insetBy(dx: 10, dy: 10)
        NSGraphicsContext.saveGraphicsState()
        let nsContext = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.current = nsContext
        str.draw(in: textRect)
        NSGraphicsContext.restoreGraphicsState()
        
        context.restoreGState()
    }
    
    private static func drawImage(_ image: CanvasImage, in context: CGContext) {
        guard let nsImage = NSImage(data: image.imageData) else { return }
        var rect = image.frame
        guard let cgImage = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return }
        context.saveGState()
        context.translateBy(x: rect.origin.x, y: rect.origin.y + rect.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        context.restoreGState()
    }
}
