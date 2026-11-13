import SwiftUI
import AppKit

public struct CanvasRepresentable: NSViewRepresentable {
    @ObservedObject var dataStore: DataStore
    var note: Note
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeNSView(context: Context) -> CanvasView {
        let canvas = CanvasView(frame: .zero)
        canvas.delegate = context.coordinator
        updateCanvasProperties(canvas)
        return canvas
    }
    
    public func updateNSView(_ canvas: CanvasView, context: Context) {
        updateCanvasProperties(canvas)
    }
    
    private func updateCanvasProperties(_ canvas: CanvasView) {
        canvas.paperStyle = note.paperStyle
        canvas.paperColor = note.paperColor
        canvas.currentTool = dataStore.selectedTool
        canvas.currentShapeKind = dataStore.selectedShapeKind
        canvas.currentColorHex = dataStore.selectedColorHex
        canvas.currentBaseWidth = dataStore.selectedWidth
        canvas.autoCorrectShapes = dataStore.autoCorrectShapes
        canvas.drawAndHoldEnabled = dataStore.drawAndHoldEnabled
        canvas.isRulerVisible = dataStore.isRulerVisible
        canvas.pressureSensitivity = dataStore.pressureSensitivity
        canvas.simulatePressureIfZero = dataStore.simulatePressureIfZero
        canvas.selectedStrokeIds = dataStore.selectedStrokeIds
        canvas.activeEditingStrokeId = dataStore.activeEditingStrokeId
        
        let curPage = note.currentPage
        canvas.strokes = curPage.strokes
        canvas.textBoxes = curPage.textBoxes
        canvas.stickyNotes = curPage.stickyNotes
    }
    
    public class Coordinator: NSObject, CanvasViewDelegate {
        var parent: CanvasRepresentable
        
        init(_ parent: CanvasRepresentable) {
            self.parent = parent
        }
        
        public func canvasDidAddStroke(_ stroke: DrawingStroke) {
            parent.dataStore.addStroke(stroke)
        }
        
        public func canvasDidEraseStrokes(ids: Set<UUID>) {
            parent.dataStore.deleteStrokes(ids: ids)
        }
        
        public func canvasDidSelectStrokes(ids: Set<UUID>) {
            DispatchQueue.main.async {
                self.parent.dataStore.selectedStrokeIds = ids
                self.parent.dataStore.activeEditingStrokeId = ids.count == 1 ? ids.first : nil
            }
        }
        
        public func canvasDidMoveSelectedStrokes(by delta: CGSize) {
            parent.dataStore.moveSelectedStrokes(by: delta)
        }
        
        public func canvasDidScaleSelectedStrokes(factorX: CGFloat, factorY: CGFloat, anchor: CGPoint) {
            parent.dataStore.scaleSelectedStrokes(factorX: factorX, factorY: factorY, anchor: anchor)
        }
        
        public func canvasDidReverseArrow(strokeId: UUID) {
            parent.dataStore.reverseArrow(for: strokeId)
        }
        
        public func canvasDidUpdateShapeEndpoints(strokeId: UUID, start: CGPoint, end: CGPoint) {
            if let noteId = parent.dataStore.selectedNoteId,
               let noteIdx = parent.dataStore.notes.firstIndex(where: { $0.id == noteId }) {
                let pageIdx = parent.dataStore.notes[noteIdx].currentPageIndex
                if let sIdx = parent.dataStore.notes[noteIdx].pages[pageIdx].strokes.firstIndex(where: { $0.id == strokeId }) {
                    parent.dataStore.notes[noteIdx].pages[pageIdx].strokes[sIdx].recognizedShape?.updateEndpoints(start: start, end: end)
                    parent.dataStore.saveToDisk()
                }
            }
        }
        
        public func canvasDidUpdateShapeBounds(strokeId: UUID, newBounds: CGRect) {
            parent.dataStore.updateShapeBounds(strokeId: strokeId, newBounds: newBounds)
        }
        
        public func canvasDidRequestUndo() {
            parent.dataStore.undo()
        }
        
        public func canvasDidRequestRedo() {
            parent.dataStore.redo()
        }
        
        public func canvasDidToggleEraser() {
            DispatchQueue.main.async {
                self.parent.dataStore.togglePenEraser()
            }
        }
        
        public func canvasDidRequestZoomIn() {
            DispatchQueue.main.async {
                self.parent.dataStore.zoomIn()
            }
        }
        
        public func canvasDidRequestZoomOut() {
            DispatchQueue.main.async {
                self.parent.dataStore.zoomOut()
            }
        }
        
        public func canvasDidRequestZoomReset() {
            DispatchQueue.main.async {
                self.parent.dataStore.zoomReset()
            }
        }
        
        public func canvasDidSelectTextBox(at point: CGPoint) {
            parent.dataStore.addTextBox(x: Double(point.x), y: Double(point.y))
        }
        
        public func canvasDidSelectStickyNote(at point: CGPoint) {
            parent.dataStore.addStickyNote(x: Double(point.x), y: Double(point.y))
        }
        
        public func canvasDidChangeTextBox(_ textBox: CanvasTextBox) {
            parent.dataStore.updateTextBox(textBox)
        }
        
        public func canvasDidChangeStickyNote(_ stickyNote: StickyNote) {
            parent.dataStore.updateStickyNote(stickyNote)
        }
        
        public func canvasDidUpdateStylus(pressure: Double, device: String, isDown: Bool) {
            DispatchQueue.main.async {
                self.parent.dataStore.currentStylusPressure = pressure
                self.parent.dataStore.stylusDeviceName = device
                self.parent.dataStore.isStylusActive = isDown
            }
        }
        
        public func canvasCurrentZoomScale() -> CGFloat {
            parent.dataStore.zoomScale
        }
        
        public func canvasDidUpdateZoom(_ newZoom: CGFloat) {
            DispatchQueue.main.async {
                self.parent.dataStore.zoomScale = newZoom
            }
        }
        
        public func canvasDidPasteImage(data: Data, at location: CGPoint) {
            DispatchQueue.main.async {
                self.parent.dataStore.addImage(data: data, at: location)
            }
        }
        
        public func canvasDidInsertTextBox(at point: CGPoint) {
            DispatchQueue.main.async {
                self.parent.dataStore.addTextBox(x: Double(point.x), y: Double(point.y))
            }
        }
        
        public func canvasDidInsertStickyNote(at point: CGPoint) {
            DispatchQueue.main.async {
                self.parent.dataStore.addStickyNote(x: Double(point.x), y: Double(point.y))
            }
        }
        
        public func canvasDidInsertTable(at point: CGPoint) {
            DispatchQueue.main.async {
                self.parent.dataStore.addTable(x: Double(point.x), y: Double(point.y))
            }
        }
        
        public func canvasDidInsertShape(kind: ShapeKind, at point: CGPoint) {
            DispatchQueue.main.async {
                self.parent.dataStore.insertShape(kind: kind, at: point)
            }
        }
        
        public func canvasDidSelectAll() {
            DispatchQueue.main.async {
                self.parent.dataStore.selectAllStrokes()
            }
        }
        
        public func canvasDidClearPage() {
            DispatchQueue.main.async {
                self.parent.dataStore.clearCurrentPageCanvas()
            }
        }
        
        public func canvasDidChangePaperStyle(_ style: PaperStyle) {
            DispatchQueue.main.async {
                self.parent.dataStore.updatePaperStyle(style: style)
            }
        }
        
        public func canvasDidChangePaperColor(_ color: PaperColor) {
            DispatchQueue.main.async {
                self.parent.dataStore.updatePaperColor(color: color)
            }
        }
        
        public func canvasDidDeselectAll() {
            DispatchQueue.main.async {
                self.parent.dataStore.activeEditingTextBoxId = nil
                self.parent.dataStore.activeEditingStickyId = nil
            }
        }
        
        public func canvasDidChangeTool(_ tool: DrawingTool) {
            DispatchQueue.main.async {
                self.parent.dataStore.selectedTool = tool
            }
        }
        
        public func canvasDidCopySelection() {
            DispatchQueue.main.async {
                self.parent.dataStore.copySelection()
            }
        }
        
        public func canvasDidPasteSelection() {
            DispatchQueue.main.async {
                self.parent.dataStore.pasteClipboard()
            }
        }
        
        public func canvasDidDeleteSelectedStrokes() {
            DispatchQueue.main.async {
                self.parent.dataStore.deleteSelectedStrokes()
            }
        }
    }
}
