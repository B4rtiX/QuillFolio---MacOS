import SwiftUI
import AppKit

public struct NoteCanvasAreaView: View {
    @ObservedObject var dataStore: DataStore
    @Binding var note: Note
    
    @State private var showClassicTextPanel: Bool = false
    @State private var baseCanvasHeight: CGFloat = 2000
    @State private var baseCanvasWidth: CGFloat = 1200
    @State private var selectedTableId: UUID? = nil
    
    private var dynamicCanvasWidth: CGFloat {
        let curPage = note.currentPage
        var maxX: CGFloat = baseCanvasWidth
        for s in curPage.strokes {
            maxX = max(maxX, s.boundingBox.maxX + 400)
        }
        for b in curPage.textBoxes {
            maxX = max(maxX, CGFloat(b.x + b.width) + 400)
        }
        for st in curPage.stickyNotes {
            maxX = max(maxX, CGFloat(st.x + st.width) + 400)
        }
        for img in curPage.images {
            maxX = max(maxX, CGFloat(img.x + img.width) + 400)
        }
        for tb in curPage.tables {
            maxX = max(maxX, CGFloat(tb.x + tb.totalWidth) + 400)
        }
        return maxX
    }
    
    private var dynamicCanvasHeight: CGFloat {
        let curPage = note.currentPage
        var maxY: CGFloat = baseCanvasHeight
        for s in curPage.strokes {
            maxY = max(maxY, s.boundingBox.maxY + 400)
        }
        for b in curPage.textBoxes {
            maxY = max(maxY, CGFloat(b.y + b.height) + 400)
        }
        for st in curPage.stickyNotes {
            maxY = max(maxY, CGFloat(st.y + st.height) + 400)
        }
        for img in curPage.images {
            maxY = max(maxY, CGFloat(img.y + img.height) + 400)
        }
        for tb in curPage.tables {
            maxY = max(maxY, CGFloat(tb.y + tb.totalHeight) + 400)
        }
        return maxY
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Rich Text Formatting Bar (Placed directly between top toolbar and note title bar)
            if dataStore.activeEditingTextBoxId != nil || dataStore.activeEditingStickyId != nil {
                TextFormattingToolbar(dataStore: dataStore)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Note Title & Info Bar
            HStack(spacing: 12) {
                TextField(dataStore.t("Tytuł notatki", "Note title"), text: $note.title)
                    .font(.system(size: 18, weight: .semibold))
                    .textFieldStyle(PlainTextFieldStyle())
                    .onChange(of: note.title) {
                        note.updatedAt = Date()
                        dataStore.saveToDisk()
                    }
                
                Spacer()
                
                // Favorite Star
                Button(action: {
                    dataStore.toggleFavorite(for: note.id)
                }) {
                    Image(systemName: note.isFavorite ? "star.fill" : "star")
                        .foregroundColor(note.isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .help(note.isFavorite ? dataStore.t("Usuń z ulubionych", "Remove from favorites") : dataStore.t("Dodaj do ulubionych", "Add to favorites"))
                
                // Toggle Classic Typed Text Side-Panel
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showClassicTextPanel.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: showClassicTextPanel ? "sidebar.right" : "doc.text")
                        Text(showClassicTextPanel ? dataStore.t("Ukryj tekst", "Hide Text") : dataStore.t("Notatnik tekstowy", "Typewriter Notes"))
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(showClassicTextPanel ? Color.accentColor.opacity(0.15) : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(dataStore.t("Przełącz widok klasycznego pisania maszynowego", "Toggle typewriter notes panel"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.7))
            .overlay(Divider(), alignment: .bottom)
            
            // Main Canvas Area (optionally split with classic text editor)
            HSplitView {
                // Drawing Canvas Area with Continuous Infinite Scroll & Zoom (Centered dynamically)
                GeometryReader { geo in
                    ScrollView([.horizontal, .vertical], showsIndicators: true) {
                        HStack(alignment: .top, spacing: 0) {
                            Spacer(minLength: 24)
                            
                            ZStack(alignment: .topLeading) {
                                let curHeight = dynamicCanvasHeight
                                let curWidth = dynamicCanvasWidth
                                
                                // 1. Drawing Canvas (Infinite horizontal & vertical canvas)
                                CanvasRepresentable(dataStore: dataStore, note: note)
                                    .frame(width: curWidth, height: curHeight)
                                
                                let curPageIdx = max(0, min(note.currentPageIndex, note.pages.count - 1))
                                
                                // 2. Interactive Embedded Images
                                ForEach(note.pages[curPageIdx].images, id: \.id) { img in
                                    CanvasImageOverlay(
                                        image: img,
                                        isSelected: false,
                                        onSelect: {
                                            dataStore.activeEditingTextBoxId = nil
                                            dataStore.activeEditingStickyId = nil
                                            selectedTableId = nil
                                        },
                                        onDelete: {
                                            let imgId = img.id
                                            DispatchQueue.main.async {
                                                dataStore.deleteImage(id: imgId)
                                            }
                                        },
                                        onUpdate: { updated in
                                            dataStore.updateImage(updated)
                                        }
                                    )
                                }
                                
                                // 3. Interactive Floating Text Boxes
                                ForEach(note.pages[curPageIdx].textBoxes, id: \.id) { textBox in
                                    CanvasTextBoxOverlay(
                                        textBox: textBox,
                                        isSelected: dataStore.activeEditingTextBoxId == textBox.id,
                                        isDarkPaper: note.paperColor.isDark,
                                        onSelect: {
                                            dataStore.activeEditingTextBoxId = textBox.id
                                            dataStore.activeEditingStickyId = nil
                                            selectedTableId = nil
                                        },
                                        onDelete: {
                                            let boxId = textBox.id
                                            if dataStore.activeEditingTextBoxId == boxId {
                                                dataStore.activeEditingTextBoxId = nil
                                            }
                                            DispatchQueue.main.async {
                                                dataStore.deleteTextBox(id: boxId)
                                            }
                                        },
                                        onUpdate: { updated in
                                            dataStore.updateTextBox(updated)
                                        }
                                    )
                                }
                                
                                // 4. Interactive Sticky Notes
                                ForEach(note.pages[curPageIdx].stickyNotes, id: \.id) { sticky in
                                    StickyNoteOverlay(
                                        sticky: sticky,
                                        isSelected: dataStore.activeEditingStickyId == sticky.id,
                                        onSelect: {
                                            dataStore.activeEditingStickyId = sticky.id
                                            dataStore.activeEditingTextBoxId = nil
                                            selectedTableId = nil
                                        },
                                        onDelete: {
                                            let stickyId = sticky.id
                                            if dataStore.activeEditingStickyId == stickyId {
                                                dataStore.activeEditingStickyId = nil
                                            }
                                            DispatchQueue.main.async {
                                                dataStore.deleteStickyNote(id: stickyId)
                                            }
                                        },
                                        onUpdate: { updated in
                                            dataStore.updateStickyNote(updated)
                                        }
                                    )
                                }
                                
                                // 5. Interactive Solid Tables directly on canvas
                                ForEach(note.pages[curPageIdx].tables, id: \.id) { table in
                                    CanvasTableOverlay(
                                        table: table,
                                        isSelected: selectedTableId == table.id,
                                        isDarkPaper: note.paperColor.isDark,
                                        onSelect: {
                                            selectedTableId = table.id
                                            dataStore.activeEditingTextBoxId = nil
                                            dataStore.activeEditingStickyId = nil
                                        },
                                        onDelete: {
                                            let tableId = table.id
                                            if selectedTableId == tableId { selectedTableId = nil }
                                            DispatchQueue.main.async {
                                                dataStore.deleteTable(id: tableId)
                                            }
                                        },
                                        onUpdate: { updated in
                                            dataStore.updateTable(updated)
                                        }
                                    )
                                }
                            }
                            .coordinateSpace(name: "canvas")
                            .scaleEffect(dataStore.zoomScale, anchor: .topLeading)
                            .frame(
                                width: dynamicCanvasWidth * dataStore.zoomScale,
                                height: dynamicCanvasHeight * dataStore.zoomScale,
                                alignment: .topLeading
                            )
                            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
                            .padding(.top, 24)
                            .padding(.bottom, 60)
                            
                            Spacer(minLength: 24)
                        }
                        .frame(
                            minWidth: max(geo.size.width, dynamicCanvasWidth * dataStore.zoomScale + 48),
                            minHeight: max(geo.size.height, dynamicCanvasHeight * dataStore.zoomScale + 84),
                            alignment: .top
                        )
                        .contentShape(Rectangle())
                        .simultaneousGesture(TapGesture().onEnded {
                            dataStore.activeEditingTextBoxId = nil
                            dataStore.activeEditingStickyId = nil
                            selectedTableId = nil
                        })
                    }
                    .background(Color(NSColor.underPageBackgroundColor))
                    .overlay(alignment: .bottom) {
                        // Floating Bottom Tooltip Capsule (No interference with note title!)
                        if let hint = dataStore.hoveredToolDescription {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 11))
                                Text(hint)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.95))
                                    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 3)
                                    .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 1))
                            )
                            .padding(.bottom, 20)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .allowsHitTesting(false)
                            .zIndex(1000)
                        }
                    }
                    .background(Color(NSColor.underPageBackgroundColor))
                }
                
                // Optional Classic Markdown / Typed Notes Panel
                if showClassicTextPanel {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "text.justify.left")
                                .foregroundColor(.secondary)
                            Text(dataStore.t("Pismo maszynowe / Treść tekstowa", "Typewriter / Plain Text Content"))
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        
                        TextEditor(text: $note.classicNoteText)
                            .font(.system(size: 13, design: .default))
                            .lineSpacing(4)
                            .padding(8)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                            .onChange(of: note.classicNoteText) {
                                note.updatedAt = Date()
                                dataStore.saveToDisk()
                            }
                    }
                    .frame(minWidth: 260, idealWidth: 320, maxWidth: 450)
                    .background(Color(NSColor.windowBackgroundColor))
                }
            }
            
            // Bottom Multi-page, Canvas Extension & Zoom Bar
            HStack(spacing: 16) {
                // Page Navigator
                HStack(spacing: 8) {
                    Button(action: {
                        if note.currentPageIndex > 0 {
                            dataStore.changePage(to: note.currentPageIndex - 1)
                        }
                    }) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .disabled(note.currentPageIndex <= 0)
                    
                    Text("\(dataStore.t("Strona", "Page")) \(note.currentPageIndex + 1) \(dataStore.t("z", "of")) \(max(1, note.pages.count))")
                        .font(.system(size: 12, weight: .medium))
                    
                    Button(action: {
                        if note.currentPageIndex < note.pages.count - 1 {
                            dataStore.changePage(to: note.currentPageIndex + 1)
                        }
                    }) {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.plain)
                    .disabled(note.currentPageIndex >= note.pages.count - 1)
                    
                    Button(action: {
                        dataStore.addPage(to: note.id)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                            Text(dataStore.t("Nowa strona", "New Page"))
                                .font(.system(size: 11))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help(dataStore.t("Dodaj kolejną stronę do tej notatki", "Add another page to this note"))
                }
                
                Divider().frame(height: 16)
                
                // Infinite Canvas Extension Buttons (Horizontal & Vertical)
                Button(action: {
                    baseCanvasWidth += 800
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.to.line.compact")
                            .font(.system(size: 11))
                        Text(dataStore.t("Poszerz w prawo (+800 px)", "Expand Right (+800 px)"))
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help(dataStore.t("Poszerz stronę horyzontalnie w nieskończoność (jak w OneNote)", "Expand canvas horizontally without limits (like OneNote)"))
                
                Button(action: {
                    baseCanvasHeight += 1000
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.to.line.compact")
                            .font(.system(size: 11))
                        Text(dataStore.t("Wydłuż w dół (+1000 px)", "Expand Down (+1000 px)"))
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help(dataStore.t("Przedłuż kartkę w dół w nieskończoność", "Extend canvas vertically without limits"))
                
                Spacer()
                
                // Zoom Controls
                HStack(spacing: 8) {
                    Button(action: {
                        dataStore.zoomScale = max(0.4, dataStore.zoomScale - 0.15)
                    }) {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .buttonStyle(.plain)
                    
                    Text("\(Int(dataStore.zoomScale * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 45)
                    
                    Button(action: {
                        dataStore.zoomScale = min(3.0, dataStore.zoomScale + 0.15)
                    }) {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .buttonStyle(.plain)
                    
                    Button("100%") {
                        dataStore.zoomScale = 1.0
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.85))
            .overlay(Divider(), alignment: .top)
            .overlay(
                Group {
                    Button(action: { dataStore.copySelection() }) { EmptyView() }
                        .keyboardShortcut("c", modifiers: .command)
                        .opacity(0)
                        .frame(width: 0, height: 0)
                    Button(action: { dataStore.pasteClipboard() }) { EmptyView() }
                        .keyboardShortcut("v", modifiers: .command)
                        .opacity(0)
                        .frame(width: 0, height: 0)
                }
            )
        }
    }
}
