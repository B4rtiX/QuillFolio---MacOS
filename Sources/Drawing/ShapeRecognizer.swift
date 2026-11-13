import Foundation
import CoreGraphics

public final class ShapeRecognizer {
    
    public static let shared = ShapeRecognizer()
    
    private init() {}
    
    // MARK: - Main Recognition Entrypoint
    
    /// Analyzes a list of points from a stroke and determines if it closely resembles a geometric shape.
    public func recognizeShape(from points: [StrokePoint]) -> GeometricShapeData? {
        guard points.count >= 8 else { return nil }
        
        let cgPoints = points.map { $0.cgPoint }
        let totalPathLength = calculatePathLength(cgPoints)
        guard totalPathLength > 25 else { return nil }
        
        let first = cgPoints.first!
        let last = cgPoints.last!
        let startEndDistance = distance(first, last)
        
        // Calculate bounding box and center
        var minX = CGFloat.infinity, maxX = -CGFloat.infinity
        var minY = CGFloat.infinity, maxY = -CGFloat.infinity
        for p in cgPoints {
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
        }
        let bounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        guard max(bounds.width, bounds.height) > 12 else { return nil }
        let center = CGPoint(x: (minX + maxX) / 2.0, y: (minY + maxY) / 2.0)
        
        // Path is closed if start and end are sufficiently close relative to path length
        let isClosed = (startEndDistance / totalPathLength < 0.28) || (startEndDistance < 42.0 && totalPathLength > 70.0)
        
        if !isClosed {
            // OPEN SHAPES: Straight line, Arrow, Double Arrow
            if let openShape = recognizeOpenShape(points: cgPoints, bounds: bounds, totalPathLength: totalPathLength) {
                return openShape
            }
            // Fallback for slightly unclosed 2D hand-drawn polygons
            if bounds.width >= 30 && bounds.height >= 30 {
                if !isHandwritingClosedLoop(points: cgPoints, bounds: bounds) {
                    return recognizeClosedShape(points: cgPoints, bounds: bounds, center: center)
                }
            }
            return nil
        } else {
            // Filter out small handwriting letters (e.g. 'o', '0', 'a', cursive words)
            if isHandwritingClosedLoop(points: cgPoints, bounds: bounds) {
                return nil
            }
            // CLOSED SHAPES: Triangle, Rhombus, Parallelogram, Trapezoid, Square, Rectangle, Circle, Ellipse, Hexagon
            return recognizeClosedShape(points: cgPoints, bounds: bounds, center: center)
        }
    }
    
    // MARK: - Handwriting Detection Heuristics
    
    /// Detects if a closed stroke is handwriting (small letters, numbers, cursive text) rather than a geometric shape
    private func isHandwritingClosedLoop(points: [CGPoint], bounds: CGRect) -> Bool {
        // Small letters like 'o', 'a', 'e', '0', 'd', 'b' typically have size < 28 pt
        if bounds.width < 28 && bounds.height < 28 { return true }
        if bounds.height < 22 && bounds.width < 45 { return true }
        
        // Cursive handwriting text: count horizontal direction reversals (inflections)
        guard points.count >= 14 else { return false }
        var dxChanges = 0
        var lastDx: CGFloat = 0
        for i in 1..<points.count {
            let dx = points[i].x - points[i-1].x
            if abs(dx) > 3.0 {
                if lastDx != 0 && (dx > 0) != (lastDx > 0) {
                    dxChanges += 1
                }
                lastDx = dx
            }
        }
        // A single convex geometric shape (circle, ellipse, quad, triangle) reverses dx at most twice.
        // Cursive handwriting words (e.g. "notatki", "kurs", "ala") reverse dx 4 or more times.
        if dxChanges >= 4 {
            return true
        }
        
        return false
    }
    
    // MARK: - Open Shape Recognition (Line vs Single Arrow vs Double Arrow)
    
    private func recognizeOpenShape(points: [CGPoint], bounds: CGRect, totalPathLength: CGFloat) -> GeometricShapeData? {
        guard let first = points.first, let last = points.last else { return nil }
        let directDistance = distance(first, last)
        guard directDistance > 12 else { return nil }
        
        // Check for arrowhead barbs at ends
        let (hasStartBarb, startTip) = detectArrowBarb(points: points, atStart: true)
        let (hasEndBarb, endTip) = detectArrowBarb(points: points, atStart: false)
        
        if hasStartBarb && hasEndBarb {
            let directDist = distance(startTip, endTip)
            let lengthRatio = totalPathLength / max(1.0, directDist)
            var maxDev: CGFloat = 0
            for p in points {
                let d = perpendicularDistance(point: p, lineStart: startTip, lineEnd: endTip)
                if d > maxDev { maxDev = d }
            }
            // Double arrow must follow a straight shaft and not loop in 2D
            if directDist > 16 && maxDev <= max(28.0, directDist * 0.35) && lengthRatio < 2.9 {
                return GeometricShapeData(
                    kind: .doubleArrow,
                    start: startTip,
                    end: endTip,
                    bounds: bounds,
                    hasArrowStart: true,
                    hasArrowEnd: true
                )
            }
        }
        
        if hasEndBarb {
            let directDist = distance(first, endTip)
            let lengthRatio = totalPathLength / max(1.0, directDist)
            var maxDev: CGFloat = 0
            for p in points {
                let d = perpendicularDistance(point: p, lineStart: first, lineEnd: endTip)
                if d > maxDev { maxDev = d }
            }
            if directDist > 14 && maxDev <= max(26.0, directDist * 0.38) && lengthRatio < 2.4 {
                return GeometricShapeData(
                    kind: .arrow,
                    start: first,
                    end: endTip,
                    bounds: bounds,
                    hasArrowStart: false,
                    hasArrowEnd: true
                )
            }
        }
        
        // If neither barb was found, check if it's a straight line
        let lengthRatio = totalPathLength / directDistance
        var maxDev: CGFloat = 0
        for p in points {
            let dev = perpendicularDistance(point: p, lineStart: first, lineEnd: last)
            if dev > maxDev { maxDev = dev }
        }
        
        let maxAllowedDev = max(14.0, directDistance * 0.12)
        if maxDev <= maxAllowedDev && lengthRatio < 1.25 {
            return snapStraightLine(start: first, end: last, bounds: bounds)
        }
        
        return nil
    }
    
    /// Detects if there is a sharp arrowhead reverse turn at the start or end of the stroke (including short strokes)
    private func detectArrowBarb(points: [CGPoint], atStart: Bool) -> (Bool, CGPoint) {
        guard points.count >= 5 else { return (false, .zero) }
        let first = points.first!
        let last = points.last!
        let directDist = distance(first, last)
        
        if atStart {
            let searchLimit = max(3, points.count / 3)
            var maxDist: CGFloat = 0
            var maxIdx = 0
            for i in 0..<searchLimit {
                let d = distance(points[i], last)
                if d > maxDist { maxDist = d; maxIdx = i }
            }
            let diff = maxDist - directDist
            if maxIdx > 0 && diff >= max(2.5, directDist * 0.04) {
                let tip = points[maxIdx]
                let enterVec = CGPoint(x: tip.x - first.x, y: tip.y - first.y)
                let leaveVec = CGPoint(x: last.x - tip.x, y: last.y - tip.y)
                if checkAngleBetweenVectors(v1: enterVec, v2: leaveVec, minAngle: 0.85) {
                    return (true, tip)
                }
            }
            return (false, first)
        } else {
            let startIndex = max(0, points.count - max(5, points.count * 2 / 5))
            var maxDist: CGFloat = 0
            var maxIdx = startIndex
            for i in startIndex..<points.count {
                let d = distance(first, points[i])
                if d > maxDist { maxDist = d; maxIdx = i }
            }
            let diff = maxDist - directDist
            if maxIdx < points.count - 1 && diff >= max(2.5, directDist * 0.04) {
                let tip = points[maxIdx]
                let enterVec = CGPoint(x: tip.x - first.x, y: tip.y - first.y)
                let leaveVec = CGPoint(x: last.x - tip.x, y: last.y - tip.y)
                if checkAngleBetweenVectors(v1: enterVec, v2: leaveVec, minAngle: 0.85) {
                    return (true, tip)
                }
            }
            return (false, last)
        }
    }
    
    private func checkAngleBetweenVectors(v1: CGPoint, v2: CGPoint, minAngle: CGFloat) -> Bool {
        let len1 = sqrt(v1.x*v1.x + v1.y*v1.y)
        let len2 = sqrt(v2.x*v2.x + v2.y*v2.y)
        guard len1 >= 4.0 && len2 >= 5.0 else { return false }
        let dot = (v1.x*v2.x + v1.y*v2.y) / (len1 * len2)
        let clamped = max(-1.0, min(1.0, dot))
        let angle = acos(clamped)
        return angle >= minAngle
    }
    
    private func snapStraightLine(start: CGPoint, end: CGPoint, bounds: CGRect) -> GeometricShapeData {
        var snappedStart = start
        var snappedEnd = end
        
        let dx = end.x - start.x
        let dy = end.y - start.y
        let angle = atan2(dy, dx)
        let degrees = abs(angle * 180.0 / .pi)
        
        // Horizontal snap
        if degrees < 7.0 || degrees > 173.0 {
            let midY = (start.y + end.y) / 2.0
            snappedStart.y = midY
            snappedEnd.y = midY
        }
        // Vertical snap
        else if abs(degrees - 90.0) < 7.0 {
            let midX = (start.x + end.x) / 2.0
            snappedStart.x = midX
            snappedEnd.x = midX
        }
        // 45 / 135 degree snap
        else if abs(degrees - 45.0) < 6.0 || abs(degrees - 135.0) < 6.0 {
            let signX: CGFloat = dx >= 0 ? 1 : -1
            let signY: CGFloat = dy >= 0 ? 1 : -1
            let avgLen = (abs(dx) + abs(dy)) / 2.0
            snappedEnd.x = snappedStart.x + signX * avgLen
            snappedEnd.y = snappedStart.y + signY * avgLen
        }
        
        return GeometricShapeData(
            kind: .line,
            start: snappedStart,
            end: snappedEnd,
            bounds: bounds
        )
    }
    
    // MARK: - Closed Shape Recognition
    
    private func recognizeClosedShape(points: [CGPoint], bounds: CGRect, center: CGPoint) -> GeometricShapeData? {
        guard bounds.width > 15, bounds.height > 15 else { return nil }
        let polyArea = abs(calculatePolygonArea(points))
        let boxArea = bounds.width * bounds.height
        let fillRatio = boxArea > 0 ? (polyArea / boxArea) : 0
        let aspectRatio = bounds.width / bounds.height
        
        // Simplify polygon using Douglas-Peucker to identify structural corners
        let epsilon = max(8.0, min(bounds.width, bounds.height) * 0.08)
        let simplified = simplifyDouglasPeucker(points, epsilon: epsilon)
        let sharpCorners = findSharpCorners(points: simplified, isClosed: true, minAngleDegrees: 50.0)
        let cornerCount = sharpCorners.count
        
        // 1. CIRCLE & ELLIPSE (Smooth continuous curvature, hand-drawn circle / ellipse)
        if fillRatio >= 0.48 && fillRatio <= 0.90 {
            if let circleOrEllipse = checkCircleOrEllipse(points: points, center: center, bounds: bounds, aspectRatio: aspectRatio, cornerCount: cornerCount, fillRatio: fillRatio) {
                return circleOrEllipse
            }
        }
        
        // 2. STRETCHED HEXAGON (Wide / Horizontal or Vertical capsule with pointed ends and flat bases)
        if (aspectRatio > 1.20 || aspectRatio < 0.82) && fillRatio >= 0.55 && fillRatio <= 0.88 {
            if let stretched = checkStretchedHexagon(points: points, bounds: bounds, center: center) {
                return stretched
            }
        }
        
        // 3. Corner cut-off analysis: distance from the 4 bounding box corners
        let cornerCutoff = boundingBoxCornerAverageDistance(points: points, bounds: bounds)
        let minDim = min(bounds.width, bounds.height)
        let cornerCutoffRatio = cornerCutoff / max(1.0, minDim)
        
        // 4. SQUARE & RECTANGLE (Corners filled: stroke touches all 4 bounding box corners, cornerCutoffRatio < 0.14)
        if cornerCutoffRatio < 0.14 && fillRatio >= 0.74 {
            if let rectOrSquare = checkRectangleOrSquare(points: points, bounds: bounds, aspectRatio: aspectRatio) {
                return rectOrSquare
            }
        }
        
        // 5. REGULAR HEXAGON (Must have at least 5 corners and hexagonal straight facets, never mistaken for circle!)
        if (aspectRatio >= 0.74 && aspectRatio <= 1.35) && (cornerCount >= 5 && isHexagonalContour(points: points, center: center, bounds: bounds)) {
            if let hex = checkHexagon(points: points, bounds: bounds, center: center) {
                return hex
            }
        }
        
        // 6. RHOMBUS / DIAMOND (4 vertices near edges midpoints, empty bounding box corners, fill ratio ~ 0.36 - 0.68)
        if fillRatio >= 0.36 && fillRatio <= 0.68 {
            if let rhombus = checkRhombus(points: points, bounds: bounds, center: center) {
                return rhombus
            }
        }
        
        // 7. RIGHT TRAPEZOID (4 corners, unequal parallel horizontal bases, one perpendicular vertical side)
        if fillRatio >= 0.42 && fillRatio <= 0.85 {
            if let rightTrap = checkRightTrapezoid(points: points, bounds: bounds) {
                return rightTrap
            }
        }
        
        // 8. TRAPEZOID (4 corners, unequal parallel horizontal bases)
        if fillRatio >= 0.42 && fillRatio <= 0.85 {
            if let trap = checkTrapezoid(points: points, bounds: bounds) {
                return trap
            }
        }
        
        // 9. PARALLELOGRAM (4 corners, two pairs of parallel opposite sides, skewed)
        if fillRatio >= 0.42 && fillRatio <= 0.88 {
            if let para = checkParallelogram(points: points, bounds: bounds, cornerCount: cornerCount) {
                return para
            }
        }
        
        // 10. TRIANGLE (3 distinct corners, fill ratio ~ 0.28 - 0.65)
        if fillRatio >= 0.28 && fillRatio <= 0.65 {
            if let triangle = checkTriangle(points: points, bounds: bounds) {
                return triangle
            }
        }
        
        // 11. SQUARE & RECTANGLE fallback (High fill ratio >= 0.74)
        if fillRatio >= 0.74 {
            if let rectOrSquare = checkRectangleOrSquare(points: points, bounds: bounds, aspectRatio: aspectRatio) {
                return rectOrSquare
            }
        }
        
        // Fallbacks based on geometry
        if cornerCount <= 2 {
            if let circleOrEllipse = checkCircleOrEllipse(points: points, center: center, bounds: bounds, aspectRatio: aspectRatio) {
                return circleOrEllipse
            }
        }
        
        if cornerCount == 3 {
            return checkTriangle(points: points, bounds: bounds)
        }
        
        if let rectOrSquare = checkRectangleOrSquare(points: points, bounds: bounds, aspectRatio: aspectRatio) {
            return rectOrSquare
        }
        
        return nil
    }
    
    // MARK: - Specific Closed Shape Checkers
    
    private func checkCircleOrEllipse(points: [CGPoint], center: CGPoint, bounds: CGRect, aspectRatio: CGFloat, cornerCount: Int = 0, fillRatio: CGFloat = 0.78) -> GeometricShapeData? {
        guard bounds.width >= 30, bounds.height >= 30 else { return nil }
        
        var sumX: CGFloat = 0, sumY: CGFloat = 0
        for p in points { sumX += p.x; sumY += p.y }
        let centroid = CGPoint(x: sumX / CGFloat(points.count), y: sumY / CGFloat(points.count))
        let effectiveCenter = CGPoint(
            x: (bounds.midX * 0.40) + (centroid.x * 0.60),
            y: (bounds.midY * 0.40) + (centroid.y * 0.60)
        )
        
        var radii: [CGFloat] = []
        for p in points {
            radii.append(distance(p, effectiveCenter))
        }
        guard !radii.isEmpty else { return nil }
        
        let avgRadius = radii.reduce(0, +) / CGFloat(radii.count)
        let variance = radii.reduce(0) { $0 + pow($1 - avgRadius, 2) } / CGFloat(radii.count)
        let stdDev = sqrt(variance)
        let cv = stdDev / max(avgRadius, 1.0)
        
        // Circle: Low radial variation (< 0.21) AND aspect ratio near 1.0 (0.70 to 1.40)
        // Must have fillRatio >= 0.58 (otherwise it is a rhombus/diamond with fillRatio ~ 0.50)
        if cv < 0.21 && (aspectRatio >= 0.70 && aspectRatio <= 1.40) && fillRatio >= 0.58 {
            // Only let checkHexagon handle it if the user drew 5+ sharp corners with flat facets!
            if cv >= 0.045 && cornerCount >= 5 && isHexagonalContour(points: points, center: effectiveCenter, bounds: bounds) {
                return nil
            }
            if cornerCount >= 4 && fillRatio < 0.70 {
                return nil
            }
            
            let radius = (bounds.width + bounds.height) / 4.0
            let circleBounds = CGRect(
                x: effectiveCenter.x - radius,
                y: effectiveCenter.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            return GeometricShapeData(
                kind: .circle,
                start: CGPoint(x: effectiveCenter.x - radius, y: effectiveCenter.y),
                end: CGPoint(x: effectiveCenter.x + radius, y: effectiveCenter.y),
                bounds: circleBounds
            )
        }
        
        // Ellipse
        let a = bounds.width / 2.0
        let b = bounds.height / 2.0
        guard a > 4 && b > 4 else { return nil }
        
        // Ellipses are curved continuously and cannot have a long flat straight horizontal or vertical facet!
        let flatTopPoints = points.filter { abs($0.y - bounds.minY) < max(2.5, bounds.height * 0.025) }
        if let minX = flatTopPoints.map(\.x).min(), let maxX = flatTopPoints.map(\.x).max(), (maxX - minX) > bounds.width * 0.36 {
            return nil // Flat facet -> stretched hexagon or trapezoid, NOT an ellipse!
        }
        
        var ellipseErrorSum: CGFloat = 0
        for p in points {
            let dx = p.x - effectiveCenter.x
            let dy = p.y - effectiveCenter.y
            let term = (dx*dx) / (a*a) + (dy*dy) / (b*b)
            ellipseErrorSum += abs(sqrt(term) - 1.0)
        }
        let avgEllipseError = ellipseErrorSum / CGFloat(points.count)
        // Natural hand-drawn ellipse (avgEllipseError < 0.15)
        if avgEllipseError < 0.15 && (aspectRatio < 0.82 || aspectRatio > 1.22) && fillRatio >= 0.50 {
            let cornerCutoff = boundingBoxCornerAverageDistance(points: points, bounds: bounds)
            let minDim = min(bounds.width, bounds.height)
            if (cornerCutoff / max(1.0, minDim)) > 0.11 {
                return GeometricShapeData(
                    kind: .ellipse,
                    start: CGPoint(x: bounds.minX, y: effectiveCenter.y),
                    end: CGPoint(x: bounds.maxX, y: effectiveCenter.y),
                    bounds: bounds
                )
            }
        }
        
        return nil
    }
    
    private func checkRectangleOrSquare(points: [CGPoint], bounds: CGRect, aspectRatio: CGFloat) -> GeometricShapeData? {
        guard bounds.width > 20, bounds.height > 20 else { return nil }
        
        // Rectangles and squares must have points filling the 4 bounding box corners
        let cornerCutoff = boundingBoxCornerAverageDistance(points: points, bounds: bounds)
        let minDim = min(bounds.width, bounds.height)
        if (cornerCutoff / max(1.0, minDim)) >= 0.13 {
            return nil // Corners are empty -> it's an ellipse, circle, or hexagon, NOT a rectangle!
        }
        
        let corners = findExtremeCorners(points: points, count: 4)
        if corners.count == 4 {
            let skewX = abs(corners[0].x - corners[3].x)
            let topW = distance(corners[0], corners[1])
            let botW = distance(corners[3], corners[2])
            let baseRatio = min(topW, botW) / max(topW, botW)
            // If it has slanted sides (parallelogram/rhombus) or unequal bases (trapezoid), it's not a rectangle/square
            if skewX > bounds.width * 0.08 || baseRatio <= 0.80 {
                return nil
            }
        }
        
        // SQUARE: Aspect ratio 0.85 - 1.18
        if aspectRatio >= 0.85 && aspectRatio <= 1.18 {
            let side = (bounds.width + bounds.height) / 2.0
            let cx = bounds.midX
            let cy = bounds.midY
            let squareBounds = CGRect(x: cx - side / 2.0, y: cy - side / 2.0, width: side, height: side)
            return GeometricShapeData(
                kind: .square,
                start: CGPoint(x: squareBounds.minX, y: squareBounds.minY),
                end: CGPoint(x: squareBounds.maxX, y: squareBounds.maxY),
                bounds: squareBounds
            )
        }
        
        // RECTANGLE
        return GeometricShapeData(
            kind: .rectangle,
            start: CGPoint(x: bounds.minX, y: bounds.minY),
            end: CGPoint(x: bounds.maxX, y: bounds.maxY),
            bounds: bounds
        )
    }
    
    private func checkTriangle(points: [CGPoint], bounds: CGRect) -> GeometricShapeData? {
        guard bounds.width > 20, bounds.height > 20 else { return nil }
        
        // Find 3 furthest distinct extreme vertices
        let corners = findExtremeCorners(points: points, count: 3)
        guard corners.count == 3 else { return nil }
        
        return GeometricShapeData(
            kind: .triangle,
            start: corners[0],
            end: corners[1],
            bounds: bounds,
            extraPoints: corners.map { StrokePoint(x: Double($0.x), y: Double($0.y)) }
        )
    }
    
    private func checkRhombus(points: [CGPoint], bounds: CGRect, center: CGPoint) -> GeometricShapeData? {
        guard bounds.width > 22, bounds.height > 22 else { return nil }
        
        let topCandidate = CGPoint(x: bounds.midX, y: bounds.minY)
        let rightCandidate = CGPoint(x: bounds.maxX, y: bounds.midY)
        let bottomCandidate = CGPoint(x: bounds.midX, y: bounds.maxY)
        let leftCandidate = CGPoint(x: bounds.minX, y: bounds.midY)
        
        let tol = max(bounds.width, bounds.height) * 0.24
        var hasTop = false, hasRight = false, hasBottom = false, hasLeft = false
        for p in points {
            if distance(p, topCandidate) < tol { hasTop = true }
            if distance(p, rightCandidate) < tol { hasRight = true }
            if distance(p, bottomCandidate) < tol { hasBottom = true }
            if distance(p, leftCandidate) < tol { hasLeft = true }
        }
        
        // 1. Diamond Form: 4 midpoints touched, bounding box corners empty
        if hasTop && hasRight && hasBottom && hasLeft {
            let tl = CGPoint(x: bounds.minX, y: bounds.minY)
            let tr = CGPoint(x: bounds.maxX, y: bounds.minY)
            let br = CGPoint(x: bounds.maxX, y: bounds.maxY)
            let bl = CGPoint(x: bounds.minX, y: bounds.maxY)
            let cornerTol = min(bounds.width, bounds.height) * 0.18
            
            var hitsCorner = false
            for p in points {
                if distance(p, tl) < cornerTol || distance(p, tr) < cornerTol ||
                   distance(p, br) < cornerTol || distance(p, bl) < cornerTol {
                    hitsCorner = true
                    break
                }
            }
            if !hitsCorner {
                let vertices = [
                    StrokePoint(x: Double(topCandidate.x), y: Double(topCandidate.y)),
                    StrokePoint(x: Double(rightCandidate.x), y: Double(rightCandidate.y)),
                    StrokePoint(x: Double(bottomCandidate.x), y: Double(bottomCandidate.y)),
                    StrokePoint(x: Double(leftCandidate.x), y: Double(leftCandidate.y))
                ]
                return GeometricShapeData(
                    kind: .rhombus,
                    start: topCandidate,
                    end: bottomCandidate,
                    bounds: bounds,
                    extraPoints: vertices
                )
            }
        }
        
        // 2. Equilateral slanted quad form: 4 sides equal length
        let corners = findExtremeCorners(points: points, count: 4)
        if corners.count == 4 {
            let topWidth = distance(corners[0], corners[1])
            let bottomWidth = distance(corners[3], corners[2])
            let leftHeight = distance(corners[0], corners[3])
            let rightHeight = distance(corners[1], corners[2])
            let maxDim = max(topWidth, max(bottomWidth, max(leftHeight, rightHeight)))
            let minDim = min(topWidth, min(bottomWidth, min(leftHeight, rightHeight)))
            let skewX = abs(corners[0].x - corners[3].x)
            
            if minDim > 18 && (maxDim - minDim) / maxDim < 0.18 && skewX > bounds.width * 0.08 {
                return GeometricShapeData(
                    kind: .rhombus,
                    start: corners[0],
                    end: corners[2],
                    bounds: bounds,
                    extraPoints: corners.map { StrokePoint(x: Double($0.x), y: Double($0.y)) }
                )
            }
        }
        
        return nil
    }
    
    private func checkRightTrapezoid(points: [CGPoint], bounds: CGRect) -> GeometricShapeData? {
        guard bounds.width > 28, bounds.height > 20 else { return nil }
        
        let corners = findExtremeCorners(points: points, count: 4)
        guard corners.count == 4 else { return nil }
        
        let cTL = corners[0]
        let cTR = corners[1]
        let cBR = corners[2]
        let cBL = corners[3]
        
        let topW = distance(cTL, cTR)
        let botW = distance(cBL, cBR)
        guard topW > 12, botW > 12 else { return nil }
        
        let baseRatio = min(topW, botW) / max(topW, botW)
        guard baseRatio >= 0.20 && baseRatio <= 0.82 else { return nil }
        
        let vTop = CGPoint(x: cTR.x - cTL.x, y: cTR.y - cTL.y)
        let vBot = CGPoint(x: cBR.x - cBL.x, y: cBR.y - cBL.y)
        let dot = (vTop.x * vBot.x + vTop.y * vBot.y)
        let lenTop = sqrt(vTop.x*vTop.x + vTop.y*vTop.y)
        let lenBot = sqrt(vBot.x*vBot.x + vBot.y*vBot.y)
        guard lenTop > 0 && lenBot > 0 else { return nil }
        guard abs(dot / (lenTop * lenBot)) > 0.80 else { return nil }
        
        let leftDx = abs(cTL.x - cBL.x)
        let rightDx = abs(cTR.x - cBR.x)
        
        let isLeftVertical = leftDx <= bounds.width * 0.12 && rightDx > bounds.width * 0.14
        let isRightVertical = rightDx <= bounds.width * 0.12 && leftDx > bounds.width * 0.14
        
        guard isLeftVertical || isRightVertical else { return nil }
        
        let isTopShorter = topW <= botW
        let snappedVertices: [StrokePoint]
        if isLeftVertical {
            let topX = isTopShorter ? (bounds.minX + bounds.width * baseRatio) : bounds.maxX
            let botX = isTopShorter ? bounds.maxX : (bounds.minX + bounds.width * baseRatio)
            snappedVertices = [
                StrokePoint(x: Double(bounds.minX), y: Double(bounds.minY)),
                StrokePoint(x: Double(topX), y: Double(bounds.minY)),
                StrokePoint(x: Double(botX), y: Double(bounds.maxY)),
                StrokePoint(x: Double(bounds.minX), y: Double(bounds.maxY))
            ]
        } else {
            let topX = isTopShorter ? (bounds.maxX - bounds.width * baseRatio) : bounds.minX
            let botX = isTopShorter ? bounds.minX : (bounds.maxX - bounds.width * baseRatio)
            snappedVertices = [
                StrokePoint(x: Double(topX), y: Double(bounds.minY)),
                StrokePoint(x: Double(bounds.maxX), y: Double(bounds.minY)),
                StrokePoint(x: Double(bounds.maxX), y: Double(bounds.maxY)),
                StrokePoint(x: Double(botX), y: Double(bounds.maxY))
            ]
        }
        
        return GeometricShapeData(
            kind: isLeftVertical ? .rightTrapezoid : .rightTrapezoidRight,
            start: CGPoint(x: snappedVertices[0].x, y: snappedVertices[0].y),
            end: CGPoint(x: snappedVertices[1].x, y: snappedVertices[1].y),
            bounds: bounds,
            extraPoints: snappedVertices
        )
    }
    
    private func checkTrapezoid(points: [CGPoint], bounds: CGRect) -> GeometricShapeData? {
        guard bounds.width > 28, bounds.height > 20 else { return nil }
        
        let corners = findExtremeCorners(points: points, count: 4)
        guard corners.count == 4 else { return nil }
        
        let cTL = corners[0]
        let cTR = corners[1]
        let cBR = corners[2]
        let cBL = corners[3]
        
        let topWidth = distance(cTL, cTR)
        let bottomWidth = distance(cBL, cBR)
        guard topWidth > 12, bottomWidth > 12 else { return nil }
        
        let minBase = min(topWidth, bottomWidth)
        let maxBase = max(topWidth, bottomWidth)
        let baseRatio = minBase / maxBase
        
        // In a trapezoid, top and bottom bases are parallel but distinctly unequal (e.g. 0.22 to 0.78)
        guard baseRatio >= 0.20 && baseRatio <= 0.80 else { return nil }
        
        let vTop = CGPoint(x: cTR.x - cTL.x, y: cTR.y - cTL.y)
        let vBot = CGPoint(x: cBR.x - cBL.x, y: cBR.y - cBL.y)
        let dot = (vTop.x * vBot.x + vTop.y * vBot.y)
        let lenTop = sqrt(vTop.x*vTop.x + vTop.y*vTop.y)
        let lenBot = sqrt(vBot.x*vBot.x + vBot.y*vBot.y)
        guard lenTop > 0 && lenBot > 0 else { return nil }
        
        let cosAngle = abs(dot / (lenTop * lenBot))
        guard cosAngle > 0.80 else { return nil }
        
        let inset = bounds.width * (1.0 - baseRatio) / 2.0
        let isTopShorter = topWidth <= bottomWidth
        let snappedVertices = isTopShorter ? [
            StrokePoint(x: Double(bounds.minX + inset), y: Double(bounds.minY)),
            StrokePoint(x: Double(bounds.maxX - inset), y: Double(bounds.minY)),
            StrokePoint(x: Double(bounds.maxX), y: Double(bounds.maxY)),
            StrokePoint(x: Double(bounds.minX), y: Double(bounds.maxY))
        ] : [
            StrokePoint(x: Double(bounds.minX), y: Double(bounds.minY)),
            StrokePoint(x: Double(bounds.maxX), y: Double(bounds.minY)),
            StrokePoint(x: Double(bounds.maxX - inset), y: Double(bounds.maxY)),
            StrokePoint(x: Double(bounds.minX + inset), y: Double(bounds.maxY))
        ]
        
        return GeometricShapeData(
            kind: .trapezoid,
            start: CGPoint(x: snappedVertices[0].x, y: snappedVertices[0].y),
            end: CGPoint(x: snappedVertices[1].x, y: snappedVertices[1].y),
            bounds: bounds,
            extraPoints: snappedVertices
        )
    }
    
    private func checkParallelogram(points: [CGPoint], bounds: CGRect, cornerCount: Int = 4) -> GeometricShapeData? {
        guard bounds.width > 28, bounds.height > 20 else { return nil }
        // Ellipses have 0-2 corners; a parallelogram must have distinct corners
        guard cornerCount >= 3 else { return nil }
        
        let corners = findExtremeCorners(points: points, count: 4)
        guard corners.count == 4 else { return nil }
        
        let topWidth = distance(corners[0], corners[1])
        let bottomWidth = distance(corners[3], corners[2])
        guard topWidth > 12, bottomWidth > 12 else { return nil }
        
        let baseRatio = min(topWidth, bottomWidth) / max(topWidth, bottomWidth)
        // Parallelogram has approximately equal opposite bases (if unequal, it's a trapezoid!)
        guard baseRatio > 0.65 else { return nil }
        
        // Vector for top edge: c1 - c0, and bottom edge: c2 - c3
        let v0 = CGPoint(x: corners[1].x - corners[0].x, y: corners[1].y - corners[0].y)
        let v2 = CGPoint(x: corners[2].x - corners[3].x, y: corners[2].y - corners[3].y)
        
        let dot = (v0.x * v2.x + v0.y * v2.y)
        let len0 = sqrt(v0.x*v0.x + v0.y*v0.y)
        let len2 = sqrt(v2.x*v2.x + v2.y*v2.y)
        guard len0 > 0 && len2 > 0 else { return nil }
        
        let cosAngle = abs(dot / (len0 * len2))
        if cosAngle > 0.76 {
            let skewX = abs(corners[0].x - corners[3].x)
            if skewX > bounds.width * 0.05 {
                return GeometricShapeData(
                    kind: .parallelogram,
                    start: corners[0],
                    end: corners[2],
                    bounds: bounds,
                    extraPoints: corners.map { StrokePoint(x: Double($0.x), y: Double($0.y)) }
                )
            }
        }
        
        return nil
    }
    
    private func isHexagonalContour(points: [CGPoint], center: CGPoint, bounds: CGRect) -> Bool {
        var maxR: CGFloat = 0
        for p in points {
            let d = distance(p, center)
            if d > maxR { maxR = d }
        }
        guard maxR > 15 else { return false }
        let r = maxR
        
        // Find best phase offset matching a vertex
        var bestAngle: CGFloat = 0
        var maxVertexDist: CGFloat = 0
        for p in points {
            let d = distance(p, center)
            if d > maxVertexDist {
                maxVertexDist = d
                bestAngle = atan2(p.y - center.y, p.x - center.x)
            }
        }
        
        var dipsCount = 0
        for i in 0..<6 {
            let a = bestAngle + (CGFloat(i) + 0.5) * (.pi / 3.0)
            var minDInSector: CGFloat = r
            for p in points {
                let dx = p.x - center.x
                let dy = p.y - center.y
                let pAngle = atan2(dy, dx)
                let diff = abs(atan2(sin(pAngle - a), cos(pAngle - a)))
                if diff < 0.28 {
                    let d = sqrt(dx*dx + dy*dy)
                    if d < minDInSector { minDInSector = d }
                }
            }
            if minDInSector <= r * 0.93 && minDInSector >= r * 0.76 {
                dipsCount += 1
            }
        }
        return dipsCount >= 4
    }
    
    private func checkHexagon(points: [CGPoint], bounds: CGRect, center: CGPoint) -> GeometricShapeData? {
        guard bounds.width > 24, bounds.height > 24 else { return nil }
        
        let radius = (bounds.width + bounds.height) / 4.0
        var hexVertices: [StrokePoint] = []
        for i in 0..<6 {
            let a = CGFloat(i) * (.pi / 3.0)
            let vx = center.x + radius * cos(a)
            let vy = center.y + radius * sin(a)
            hexVertices.append(StrokePoint(x: Double(vx), y: Double(vy)))
        }
        
        return GeometricShapeData(
            kind: .hexagon,
            start: CGPoint(x: hexVertices[0].x, y: hexVertices[0].y),
            end: CGPoint(x: hexVertices[3].x, y: hexVertices[3].y),
            bounds: bounds,
            extraPoints: hexVertices
        )
    }
    
    private func checkStretchedHexagon(points: [CGPoint], bounds: CGRect, center: CGPoint) -> GeometricShapeData? {
        guard bounds.width > 30, bounds.height > 16 else { return nil }
        
        let isHorizontal = bounds.width >= bounds.height
        if isHorizontal {
            let topPoints = points.filter { $0.y <= bounds.minY + bounds.height * 0.15 }
            let botPoints = points.filter { $0.y >= bounds.maxY - bounds.height * 0.15 }
            guard !topPoints.isEmpty && !botPoints.isEmpty else { return nil }
            
            let minTopX = topPoints.map(\.x).min() ?? bounds.minX
            let maxTopX = topPoints.map(\.x).max() ?? bounds.maxX
            let minBotX = botPoints.map(\.x).min() ?? bounds.minX
            let maxBotX = botPoints.map(\.x).max() ?? bounds.maxX
            
            let leftInsetThreshold = bounds.minX + bounds.width * 0.07
            let rightInsetThreshold = bounds.maxX - bounds.width * 0.07
            
            guard minTopX >= leftInsetThreshold && minBotX >= leftInsetThreshold else { return nil }
            guard maxTopX <= rightInsetThreshold && maxBotX <= rightInsetThreshold else { return nil }
            
            let midBand = points.filter { abs($0.y - bounds.midY) <= bounds.height * 0.30 }
            guard let minMidX = midBand.map(\.x).min(), minMidX <= bounds.minX + bounds.width * 0.12 else { return nil }
            guard let maxMidX = midBand.map(\.x).max(), maxMidX >= bounds.maxX - bounds.width * 0.12 else { return nil }
            
            let inset = bounds.width * 0.20
            let leftTip = CGPoint(x: bounds.minX, y: bounds.midY)
            let rightTip = CGPoint(x: bounds.maxX, y: bounds.midY)
            let candidateVertices = [
                leftTip,
                CGPoint(x: bounds.minX + inset, y: bounds.minY),
                CGPoint(x: bounds.maxX - inset, y: bounds.minY),
                rightTip,
                CGPoint(x: bounds.maxX - inset, y: bounds.maxY),
                CGPoint(x: bounds.minX + inset, y: bounds.maxY)
            ]
            
            return GeometricShapeData(
                kind: .stretchedHexagon,
                start: leftTip,
                end: rightTip,
                bounds: bounds,
                extraPoints: candidateVertices.map { StrokePoint(x: Double($0.x), y: Double($0.y)) }
            )
        } else {
            let leftPoints = points.filter { $0.x <= bounds.minX + bounds.width * 0.15 }
            let rightPoints = points.filter { $0.x >= bounds.maxX - bounds.width * 0.15 }
            guard !leftPoints.isEmpty && !rightPoints.isEmpty else { return nil }
            
            let minLeftY = leftPoints.map(\.y).min() ?? bounds.minY
            let maxLeftY = leftPoints.map(\.y).max() ?? bounds.maxY
            let minRightY = rightPoints.map(\.y).min() ?? bounds.minY
            let maxRightY = rightPoints.map(\.y).max() ?? bounds.maxY
            
            let topInsetThreshold = bounds.minY + bounds.height * 0.07
            let botInsetThreshold = bounds.maxY - bounds.height * 0.07
            
            guard minLeftY >= topInsetThreshold && minRightY >= topInsetThreshold else { return nil }
            guard maxLeftY <= botInsetThreshold && maxRightY <= botInsetThreshold else { return nil }
            
            let midBand = points.filter { abs($0.x - bounds.midX) <= bounds.width * 0.30 }
            guard let minMidY = midBand.map(\.y).min(), minMidY <= bounds.minY + bounds.height * 0.12 else { return nil }
            guard let maxMidY = midBand.map(\.y).max(), maxMidY >= bounds.maxY - bounds.height * 0.12 else { return nil }
            
            let inset = bounds.height * 0.20
            let topTip = CGPoint(x: bounds.midX, y: bounds.minY)
            let botTip = CGPoint(x: bounds.midX, y: bounds.maxY)
            let candidateVertices = [
                topTip,
                CGPoint(x: bounds.maxX, y: bounds.minY + inset),
                CGPoint(x: bounds.maxX, y: bounds.maxY - inset),
                botTip,
                CGPoint(x: bounds.minX, y: bounds.maxY - inset),
                CGPoint(x: bounds.minX, y: bounds.minY + inset)
            ]
            
            return GeometricShapeData(
                kind: .stretchedHexagon,
                start: topTip,
                end: botTip,
                bounds: bounds,
                extraPoints: candidateVertices.map { StrokePoint(x: Double($0.x), y: Double($0.y)) }
            )
        }
    }
    
    private func boundingBoxCornerAverageDistance(points: [CGPoint], bounds: CGRect) -> CGFloat {
        let corners = [
            CGPoint(x: bounds.minX, y: bounds.minY),
            CGPoint(x: bounds.maxX, y: bounds.minY),
            CGPoint(x: bounds.minX, y: bounds.maxY),
            CGPoint(x: bounds.maxX, y: bounds.maxY)
        ]
        var totalMinDist: CGFloat = 0
        for c in corners {
            var minD: CGFloat = .infinity
            for p in points {
                let d = distance(p, c)
                if d < minD { minD = d }
            }
            totalMinDist += minD
        }
        return totalMinDist / 4.0
    }
    
    private func checkStar(points: [CGPoint], center: CGPoint, bounds: CGRect) -> GeometricShapeData? {
        guard points.count >= 15, bounds.width > 35, bounds.height > 35 else { return nil }
        
        let radii = points.map { distance($0, center) }
        var peakCount = 0
        for i in 1..<(radii.count - 1) {
            let prev = radii[i - 1]
            let curr = radii[i]
            let next = radii[i + 1]
            if curr > prev && curr > next && curr > bounds.width * 0.25 {
                peakCount += 1
            }
        }
        
        if peakCount >= 4 && peakCount <= 6 {
            return GeometricShapeData(
                kind: .star,
                start: CGPoint(x: center.x, y: bounds.minY),
                end: CGPoint(x: center.x, y: bounds.maxY),
                bounds: bounds
            )
        }
        
        return nil
    }
    
    // MARK: - Mathematical and Geometric Utilities
    
    public func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx*dx + dy*dy)
    }
    
    private func calculatePathLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count >= 2 else { return 0 }
        var total: CGFloat = 0
        for i in 1..<points.count {
            total += distance(points[i - 1], points[i])
        }
        return total
    }
    
    private func perpendicularDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let length = sqrt(dx*dx + dy*dy)
        if length == 0 { return distance(point, lineStart) }
        let numerator = abs(dy * point.x - dx * point.y + lineEnd.x * lineStart.y - lineEnd.y * lineStart.x)
        return numerator / length
    }
    
    private func calculatePolygonArea(_ points: [CGPoint]) -> CGFloat {
        guard points.count >= 3 else { return 0 }
        var area: CGFloat = 0
        for i in 0..<points.count {
            let j = (i + 1) % points.count
            area += points[i].x * points[j].y
            area -= points[j].x * points[i].y
        }
        return area / 2.0
    }
    
    private func findSharpCorners(points: [CGPoint], isClosed: Bool, minAngleDegrees: CGFloat = 38.0) -> [CGPoint] {
        guard points.count >= 4 else { return [] }
        var corners: [CGPoint] = []
        let minAngleRad = minAngleDegrees * .pi / 180.0
        
        let count = points.count
        for i in 0..<count {
            if !isClosed && (i == 0 || i == count - 1) { continue }
            let prev = points[(i - 1 + count) % count]
            let curr = points[i]
            let next = points[(i + 1) % count]
            
            let v1 = CGPoint(x: curr.x - prev.x, y: curr.y - prev.y)
            let v2 = CGPoint(x: next.x - curr.x, y: next.y - curr.y)
            let len1 = sqrt(v1.x*v1.x + v1.y*v1.y)
            let len2 = sqrt(v2.x*v2.x + v2.y*v2.y)
            if len1 > 2 && len2 > 2 {
                let dot = max(-1.0, min(1.0, (v1.x * v2.x + v1.y * v2.y) / (len1 * len2)))
                let turnAngle = acos(dot)
                if turnAngle >= minAngleRad {
                    corners.append(curr)
                }
            }
        }
        return corners
    }
    
    private func simplifyDouglasPeucker(_ points: [CGPoint], epsilon: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }
        var maxDist: CGFloat = 0
        var maxIdx = 0
        let first = points.first!
        let last = points.last!
        
        for i in 1..<(points.count - 1) {
            let dist = perpendicularDistance(point: points[i], lineStart: first, lineEnd: last)
            if dist > maxDist {
                maxDist = dist
                maxIdx = i
            }
        }
        
        if maxDist > epsilon {
            let left = simplifyDouglasPeucker(Array(points[0...maxIdx]), epsilon: epsilon)
            let right = simplifyDouglasPeucker(Array(points[maxIdx..<points.count]), epsilon: epsilon)
            return left.dropLast() + right
        } else {
            return [first, last]
        }
    }
    
    private func findExtremeCorners(points: [CGPoint], count: Int) -> [CGPoint] {
        guard points.count >= count else { return points }
        
        if count == 3 {
            // Find 3 furthest distinct points
            var p1 = points[0]
            var maxD: CGFloat = 0
            for p in points {
                let d = distance(points[0], p)
                if d > maxD { maxD = d; p1 = p }
            }
            var p2 = points[0]
            maxD = 0
            for p in points {
                let d = distance(p1, p)
                if d > maxD { maxD = d; p2 = p }
            }
            var p3 = points[0]
            maxD = 0
            for p in points {
                let d = perpendicularDistance(point: p, lineStart: p1, lineEnd: p2)
                if d > maxD { maxD = d; p3 = p }
            }
            return [p1, p2, p3]
        }
        
        var tl = points[0], tr = points[0], br = points[0], bl = points[0]
        for p in points {
            if (p.x + p.y) < (tl.x + tl.y) { tl = p }
            if (p.x - p.y) > (tr.x - tr.y) { tr = p }
            if (p.x + p.y) > (br.x + br.y) { br = p }
            if (p.y - p.x) > (bl.y - bl.x) { bl = p }
        }
        return [tl, tr, br, bl]
    }
    
    // MARK: - Dedicated Cloud Path Generator
    
    public static func cloudPath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let w = rect.width
        let h = rect.height
        let x = rect.minX
        let y = rect.minY
        
        // Puffy cloud arcs around perimeter
        path.move(to: CGPoint(x: x + w * 0.22, y: y + h * 0.82))
        path.addCurve(
            to: CGPoint(x: x + w * 0.78, y: y + h * 0.82),
            control1: CGPoint(x: x + w * 0.38, y: y + h * 0.94),
            control2: CGPoint(x: x + w * 0.62, y: y + h * 0.94)
        )
        path.addCurve(
            to: CGPoint(x: x + w * 0.95, y: y + h * 0.58),
            control1: CGPoint(x: x + w * 0.92, y: y + h * 0.82),
            control2: CGPoint(x: x + w * 0.98, y: y + h * 0.70)
        )
        path.addCurve(
            to: CGPoint(x: x + w * 0.75, y: y + h * 0.26),
            control1: CGPoint(x: x + w * 0.95, y: y + h * 0.40),
            control2: CGPoint(x: x + w * 0.88, y: y + h * 0.20)
        )
        path.addCurve(
            to: CGPoint(x: x + w * 0.35, y: y + h * 0.20),
            control1: CGPoint(x: x + w * 0.68, y: y + h * 0.04),
            control2: CGPoint(x: x + w * 0.42, y: y + h * 0.04)
        )
        path.addCurve(
            to: CGPoint(x: x + w * 0.08, y: y + h * 0.50),
            control1: CGPoint(x: x + w * 0.20, y: y + h * 0.16),
            control2: CGPoint(x: x + w * 0.05, y: y + h * 0.30)
        )
        path.addCurve(
            to: CGPoint(x: x + w * 0.22, y: y + h * 0.82),
            control1: CGPoint(x: x + w * 0.03, y: y + h * 0.68),
            control2: CGPoint(x: x + w * 0.08, y: y + h * 0.82)
        )
        path.closeSubpath()
        return path
    }
}
