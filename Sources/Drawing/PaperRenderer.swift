import AppKit
import CoreGraphics

public final class PaperRenderer {
    
    public static func drawPaper(
        in rect: CGRect,
        style: PaperStyle,
        color: PaperColor,
        zoom: CGFloat = 1.0,
        context: CGContext
    ) {
        // 1. Fill base paper background color
        let bgColor = color.backgroundColor
        let nsBgColor = NSColor(bgColor)
        context.setFillColor(nsBgColor.cgColor)
        context.fill(rect)
        
        guard style != .blank else { return }
        
        let patternColor = NSColor(color.patternColor).cgColor
        let marginColor = NSColor(color.marginColor).cgColor
        
        context.saveGState()
        context.setStrokeColor(patternColor)
        context.setFillColor(patternColor)
        
        let spacing: CGFloat = 26.0 // standard ruling/grid spacing
        
        switch style {
        case .blank:
            break
            
        case .lined:
            context.setLineWidth(1.0)
            // Draw horizontal ruled lines
            var y = spacing * 2
            while y < rect.height {
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: rect.width, y: y))
                y += spacing
            }
            context.strokePath()
            
            // Draw classical red margin line on the left (at 70pt)
            let marginX: CGFloat = 72.0
            context.setStrokeColor(marginColor)
            context.setLineWidth(1.5)
            context.move(to: CGPoint(x: marginX, y: 0))
            context.addLine(to: CGPoint(x: marginX, y: rect.height))
            context.strokePath()
            
        case .grid:
            context.setLineWidth(0.75)
            // Vertical lines
            var x = spacing
            while x < rect.width {
                context.move(to: CGPoint(x: x, y: 0))
                context.addLine(to: CGPoint(x: x, y: rect.height))
                x += spacing
            }
            // Horizontal lines
            var y = spacing
            while y < rect.height {
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: rect.width, y: y))
                y += spacing
            }
            context.strokePath()
            
        case .dots:
            let dotRadius: CGFloat = 1.2
            var x = spacing
            while x < rect.width {
                var y = spacing
                while y < rect.height {
                    let dotRect = CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                    context.fillEllipse(in: dotRect)
                    y += spacing
                }
                x += spacing
            }
        }
        
        context.restoreGState()
    }
}
