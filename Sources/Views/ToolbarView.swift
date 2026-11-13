import SwiftUI
import AppKit

public struct ToolbarView: View {
    @ObservedObject var dataStore: DataStore
    var note: Note?
    var onExportPDF: () -> Void
    var onExportPNG: () -> Void
    
    @State private var isShowingTabletSettings = false
    @State private var isShowingShapePicker = false
    @State private var isShowingTablePicker = false
    @State private var isShowingCustomThickness = false
    
    // 7 curated high-frequency vibrant colors (+ macOS native color wheel for infinite colors)
    private let presetColors: [String] = [
        "#1E293B", // Ciemny łupek / Grafit
        "#007AFF", // Niebieski macOS
        "#10B981", // Szmaragdowy
        "#F59E0B", // Bursztynowy / Złoty
        "#FF3B30", // Czerwony
        "#AF52DE", // Fioletowy
        "#FFFFFF"  // Biały
    ]
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // MARK: - Home / Pulpit Dashboard Button
                Button(action: {
                    dataStore.showSettings = false
                    dataStore.showHomeDashboard.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 11))
                            .foregroundColor(dataStore.showHomeDashboard ? .accentColor : .primary)
                        Text(dataStore.t("Pulpit", "Dashboard"))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(dataStore.showHomeDashboard ? Color.accentColor.opacity(0.18) : Color(NSColor.controlBackgroundColor).opacity(0.55))
                    .cornerRadius(7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
                .help(dataStore.t("Pulpit: przeglądaj wszystkie notatki, szablony i statystyki", "Dashboard: browse all notes, templates, and statistics"))
                
                Divider().frame(height: 18)
                
                // MARK: - SEKCJA 1: Kursor i Zaznaczanie
                HStack(spacing: 1) {
                    toolButton(tool: .pointer, label: dataStore.t("Kursor", "Cursor"), tooltip: dataStore.t("Kursor: zaznaczaj, edytuj i swobodnie przesuwaj elementy bez rysowania", "Cursor: select, edit, and move canvas elements"))
                    toolButton(tool: .lasso, label: dataStore.t("Lasso", "Lasso"), tooltip: dataStore.t("Lasso: zakreśl obszar, aby zaznaczyć grupę kresek", "Lasso: circle an area to select handwritten strokes"))
                }
                .padding(2)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
                )
                
                Divider().frame(height: 18)
                
                // MARK: - SEKCJA 2: Przybory do Pisania i Rysowania
                HStack(spacing: 1) {
                    toolButton(tool: .pen, label: dataStore.t("Pióro wieczne", "Fountain Pen"), tooltip: dataStore.t("Pióro: płynne pismo z naturalną zmienną grubością", "Pen: fluid handwriting with natural thickness variation"))
                    toolButton(tool: .calligraphy, label: dataStore.t("Kaligrafia", "Calligraphy"), tooltip: dataStore.t("Kaligrafia: stalówka skośna reagująca na kąt ruchu", "Calligraphy: angled nib reacting to stroke angle"))
                    toolButton(tool: .brush, label: dataStore.t("Pędzel", "Brush"), tooltip: dataStore.t("Pędzel: miękkie, artystyczne pociągnięcia z kryciem", "Brush: soft artistic strokes with opacity"))
                    toolButton(tool: .pencil, label: dataStore.t("Ołówek", "Pencil"), tooltip: dataStore.t("Ołówek: delikatny szkic o naturalnej ziarnistości", "Pencil: fine sketching with natural graphite texture"))
                    toolButton(tool: .crayon, label: dataStore.t("Kredka", "Crayon"), tooltip: dataStore.t("Kredka woskowa: nasycona faktura kredki", "Wax Crayon: textured saturated crayon stroke"))
                    toolButton(tool: .highlighter, label: dataStore.t("Zakreślacz", "Highlighter"), tooltip: dataStore.t("Zakreślacz: marker do wyróżniania tekstu", "Highlighter: semi-transparent marker"))
                    toolButton(tool: .eraser, label: dataStore.t("Gumka", "Eraser"), tooltip: dataStore.t("Gumka: wymazywanie odręcznych kresek i figur", "Eraser: erase ink strokes and shapes"))
                    toolButton(tool: .laser, label: dataStore.t("Laser", "Laser"), tooltip: dataStore.t("Wskaźnik laserowy: punkt prezentacyjny znikający po chwili", "Laser Pointer: fading spotlight for presentations"))
                }
                .padding(2)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
                )
                
                // MARK: - SEKCJA 3: Kolor i Grubość Narzędzia
                HStack(spacing: 4) {
                    ForEach(presetColors, id: \.self) { hex in
                        Circle()
                            .fill(Color(NSColor(hex: hex) ?? .black))
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(0.8), lineWidth: dataStore.selectedColorHex == hex ? 2.5 : 0.5)
                            )
                            .onTapGesture {
                                dataStore.selectedColorHex = hex
                                if !dataStore.selectedStrokeIds.isEmpty {
                                    dataStore.changeSelectedStrokesColor(hex: hex)
                                }
                            }
                    }
                    
                    Divider()
                        .frame(height: 14)
                        .padding(.horizontal, 6)
                    
                    ColorPicker("", selection: Binding(
                        get: { Color(NSColor(hex: dataStore.selectedColorHex) ?? .black) },
                        set: { newColor in
                            if let nsColor = NSColor(newColor).usingColorSpace(.sRGB) {
                                let r = Int(round(nsColor.redComponent * 255.0))
                                let g = Int(round(nsColor.greenComponent * 255.0))
                                let b = Int(round(nsColor.blueComponent * 255.0))
                                let hex = String(format: "#%02X%02X%02X", max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))
                                dataStore.selectedColorHex = hex
                                if !dataStore.selectedStrokeIds.isEmpty {
                                    dataStore.changeSelectedStrokesColor(hex: hex)
                                }
                            }
                        }
                    ))
                    .labelsHidden()
                    .frame(width: 24, height: 24)
                    .help(dataStore.t("Wybór dowolnego koloru rysowania z koła barw macOS", "Pick any drawing color from macOS color wheel"))
                    
                    Divider()
                        .frame(height: 14)
                        .padding(.horizontal, 4)
                    
                    // Thickness Button & Popover
                    Button(action: {
                        isShowingCustomThickness.toggle()
                    }) {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color.primary)
                                .frame(width: CGFloat(min(10, max(3, dataStore.selectedWidth * 1.3))), height: CGFloat(min(10, max(3, dataStore.selectedWidth * 1.3))))
                            Text("\(String(format: "%.1f", dataStore.selectedWidth)) pt")
                                .font(.system(size: 11, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(isShowingCustomThickness ? Color.accentColor.opacity(0.18) : Color(NSColor.controlBackgroundColor).opacity(0.6))
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help(dataStore.t("Grubość linii: kliknij, aby wybrać preset lub dowolny rozmiar w pikselach", "Stroke width: click to choose presets or custom size"))
                    .popover(isPresented: $isShowingCustomThickness) {
                        CustomThicknessPopover(dataStore: dataStore, selectedWidth: $dataStore.selectedWidth)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
                )
                
                Divider().frame(height: 18)
                
                // MARK: - SEKCJA 4: Wstawianie Treści
                HStack(spacing: 3) {
                    toolButton(tool: .text, label: dataStore.t("Pole tekstowe", "Text Box"), tooltip: dataStore.t("Pole tekstowe: kliknij na kartce, aby dodać małe kompaktowe pole tekstowe", "Text Box: click anywhere to add a floating text box"))
                    toolButton(tool: .sticky, label: dataStore.t("Karteczka Post-it", "Sticky Note"), tooltip: dataStore.t("Karteczka: pastelowa karteczka z notatkami", "Sticky Note: colorful sticky note"))
                    
                    Button(action: { isShowingShapePicker.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.on.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                            Text(dataStore.t("Kształty", "Shapes"))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(isShowingShapePicker ? Color.accentColor.opacity(0.18) : Color.clear)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help(dataStore.t("Kształty: wstaw gotową figurę geometryczną (prostokąt, romb, trapez, sześciokąt...)", "Shapes: insert geometric shapes (rectangle, rhombus, trapezoid, hexagon...)"))
                    .popover(isPresented: $isShowingShapePicker) {
                        ShapePickerPopover(dataStore: dataStore) {
                            isShowingShapePicker = false
                        }
                    }
                    
                    Button(action: { isShowingTablePicker.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "tablecells")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                            Text(dataStore.t("Tabela", "Table"))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(isShowingTablePicker ? Color.accentColor.opacity(0.18) : Color.clear)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help(dataStore.t("Tabela: wstaw tabelę z edytowalnymi komórkami i automatycznym poszerzaniem", "Table: insert editable dynamic table with auto-expanding cells"))
                    .popover(isPresented: $isShowingTablePicker) {
                        TablePickerPopover(dataStore: dataStore) {
                            isShowingTablePicker = false
                        }
                    }
                    
                    Button(action: {
                        let panel = NSOpenPanel()
                        panel.title = dataStore.t("Wstaw zdjęcie do notatki", "Insert Image into Note")
                        panel.allowedContentTypes = [.image, .png, .jpeg, .tiff]
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
                            dataStore.addImage(data: data)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                            Text(dataStore.t("Zdjęcie", "Image"))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help(dataStore.t("Zdjęcie: wstaw zdjęcie z pliku lub wklej schowkiem (⌘V)", "Image: insert photo from disk or paste from clipboard (⌘V)"))
                }
                .padding(2)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
                )
                
                Divider().frame(height: 18)
                
                // MARK: - Sekcja 5: Inteligentne rysowanie (Auto-kształt & Tablet)
                HStack(spacing: 4) {
                    // Shape Auto-Correction Toggle
                    Button(action: {
                        dataStore.autoCorrectShapes.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: dataStore.autoCorrectShapes ? "wand.and.stars" : "wand.and.stars.inverse")
                                .font(.system(size: 11))
                                .foregroundColor(dataStore.autoCorrectShapes ? .accentColor : .secondary)
                            Text(dataStore.t("Auto-kształt", "Auto-Shape"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(dataStore.autoCorrectShapes ? .primary : .secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(dataStore.autoCorrectShapes ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help(dataStore.autoCorrectShapes ? dataStore.t("Auto-kształt: WŁĄCZONY (przytrzymaj chwilę w miejscu po narysowaniu)", "Auto-Shape: ENABLED (hold steady after drawing)") : dataStore.t("Auto-kształt: WYŁĄCZONY", "Auto-Shape: DISABLED"))
                    
                    // Tablet & Stylus Settings
                    Button(action: {
                        isShowingTabletSettings.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.draw.fill")
                                .font(.system(size: 11))
                            Text(dataStore.t("Tablet", "Tablet"))
                                .font(.system(size: 11, weight: .medium))
                            if dataStore.currentStylusPressure > 0.05 {
                                Text("\(Int(dataStore.currentStylusPressure * 100))%")
                                    .font(.system(size: 9, design: .monospaced))
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .foregroundColor(dataStore.currentStylusPressure > 0.05 ? .accentColor : .primary)
                        .background(dataStore.currentStylusPressure > 0.05 ? Color.accentColor.opacity(0.18) : Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help(dataStore.t("Ustawienia tabletu graficznego i nacisku piórka", "Tablet diagnostics and pen pressure settings"))
                    .popover(isPresented: $isShowingTabletSettings) {
                        TabletSettingsPopover(dataStore: dataStore)
                    }
                }
                .padding(2)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
                )
                
                // MARK: - Selected Elements Actions (Lasso / Active Shape)
                if !dataStore.selectedStrokeIds.isEmpty {
                    HStack(spacing: 4) {
                        if let activeId = dataStore.activeEditingStrokeId ?? dataStore.selectedStrokeIds.first,
                           let stroke = dataStore.selectedNote?.currentPage.strokes.first(where: { $0.id == activeId }),
                           stroke.recognizedShape?.kind == .arrow || stroke.recognizedShape?.kind == .doubleArrow {
                            Button(action: {
                                dataStore.reverseArrow(for: activeId)
                            }) {
                                HStack(spacing: 2) {
                                    Image(systemName: "arrow.left.and.right")
                                    Text(dataStore.t("Odwróć", "Reverse"))
                                        .font(.system(size: 11))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.15))
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .help(dataStore.t("Odwróć zwrot strzałki", "Reverse arrow direction"))
                        }
                        
                        Button(action: {
                            dataStore.duplicateSelectedStrokes()
                        }) {
                            Image(systemName: "plus.square.on.square")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .help(dataStore.t("Duplikuj zaznaczone elementy", "Duplicate selected elements"))
                        
                        Button(action: {
                            dataStore.deleteSelectedStrokes()
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .help(dataStore.t("Usuń zaznaczone elementy", "Delete selected elements"))
                    }
                    .padding(3)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.75))
                    .cornerRadius(7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.accentColor.opacity(0.35), lineWidth: 0.8)
                    )
                }
                
                Spacer()
                
                // MARK: - Undo & Redo
                HStack(spacing: 6) {
                    Button(action: {
                        dataStore.undo()
                    }) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(!dataStore.canUndo)
                    .keyboardShortcut("z", modifiers: .command)
                    .help(dataStore.t("Cofnij (⌘Z / Ctrl+Z)", "Undo (⌘Z / Ctrl+Z)"))
                    
                    Button(action: {
                        dataStore.redo()
                    }) {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(!dataStore.canRedo)
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .help(dataStore.t("Ponów (⌘⇧Z / Ctrl+Y)", "Redo (⌘⇧Z / Ctrl+Y)"))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
                )
                
                // MARK: - Paper Style & Color Menu
                if let note = note {
                    Menu {
                        Section(dataStore.t("Styl papieru", "Paper Style")) {
                            ForEach(PaperStyle.allCases) { style in
                                Button(action: { dataStore.updatePaperStyle(style: style) }) {
                                    Label(style.localizedName(language: dataStore.language), systemImage: style.iconName)
                                }
                            }
                        }
                        Divider()
                        Section(dataStore.t("Kolor papieru", "Paper Color")) {
                            ForEach(PaperColor.allCases) { color in
                                Button(action: { dataStore.updatePaperColor(color: color) }) {
                                    Text(color.localizedName(language: dataStore.language))
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: note.paperStyle.iconName)
                            Text(note.paperStyle.localizedName(language: dataStore.language))
                                .font(.system(size: 11))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
                        .cornerRadius(7)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
                        )
                    }
                    .menuStyle(.borderlessButton)
                }
                
                // MARK: - Export Menu
                Menu {
                    Button(action: onExportPDF) {
                        Label(dataStore.t("Eksportuj jako PDF...", "Export as PDF..."), systemImage: "doc.richtext")
                    }
                    Button(action: onExportPNG) {
                        Label(dataStore.t("Eksportuj jako PNG...", "Export as PNG..."), systemImage: "photo")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .padding(4)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
                        .cornerRadius(7)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
                        )
                }
                .menuStyle(.borderlessButton)
                .help(dataStore.t("Eksportuj notatkę", "Export Note"))
                
                // MARK: - Settings Button (Direct Toolbar Shortcut)
                Button(action: {
                    dataStore.showSettings.toggle()
                    if dataStore.showSettings {
                        dataStore.showHomeDashboard = false
                    }
                }) {
                    Image(systemName: dataStore.showSettings ? "gearshape.fill" : "gearshape")
                        .font(.system(size: 12))
                        .foregroundColor(dataStore.showSettings ? .accentColor : .primary)
                        .padding(5)
                        .background(dataStore.showSettings ? Color.accentColor.opacity(0.18) : Color(NSColor.controlBackgroundColor).opacity(0.45))
                        .cornerRadius(7)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
                        )
                }
                .buttonStyle(.plain)
                .help(dataStore.t("Ustawienia aplikacji", "App Settings"))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
        .background(VisualEffectBackground())
        .overlay(Divider(), alignment: .bottom)
    }
    
    @ViewBuilder
    private func toolButton(tool: DrawingTool, label: String, tooltip: String? = nil) -> some View {
        let desc = tooltip ?? label
        Button(action: {
            dataStore.selectedTool = tool
        }) {
            Group {
                if tool == .highlighter {
                    HighlighterIconView(isSelected: dataStore.selectedTool == .highlighter)
                } else {
                    Image(systemName: tool.iconName)
                        .font(.system(size: 13))
                        .foregroundColor(tool == .laser ? .red : (dataStore.selectedTool == tool ? .accentColor : .primary))
                }
            }
            .padding(5)
            .background(dataStore.selectedTool == tool ? Color.accentColor.opacity(0.18) : Color.clear)
            .cornerRadius(6)
            .help(desc)
        }
        .buttonStyle(.plain)
        .help(desc)
        .onHover { isHovered in
            if isHovered {
                dataStore.hoveredToolDescription = desc
            } else if dataStore.hoveredToolDescription == desc {
                dataStore.hoveredToolDescription = nil
            }
        }
    }
}

// MARK: - Authentic Highlighter Marker Icon (Chisel-Tip)

public struct HighlighterIconView: View {
    var isSelected: Bool
    
    public var body: some View {
        Canvas { context, size in
            // Slanted chisel tip (yellow marker nib)
            var tip = Path()
            tip.move(to: CGPoint(x: size.width * 0.28, y: size.height * 0.38))
            tip.addLine(to: CGPoint(x: size.width * 0.72, y: size.height * 0.12)) // angled chisel
            tip.addLine(to: CGPoint(x: size.width * 0.72, y: size.height * 0.38))
            tip.closeSubpath()
            context.fill(tip, with: .color(Color(red: 0.98, green: 0.88, blue: 0.15)))
            
            // Marker nib collar
            let collarRect = CGRect(x: size.width * 0.28, y: size.height * 0.38, width: size.width * 0.44, height: size.height * 0.12)
            context.fill(Path(collarRect), with: .color(Color.gray.opacity(0.85)))
            
            // Marker chunky body
            let bodyRect = CGRect(x: size.width * 0.20, y: size.height * 0.50, width: size.width * 0.60, height: size.height * 0.46)
            let bodyPath = Path(roundedRect: bodyRect, cornerRadius: 2.0)
            context.fill(bodyPath, with: .color(isSelected ? Color.accentColor : Color.primary.opacity(0.8)))
        }
        .frame(width: 16, height: 16)
    }
}

// MARK: - Custom Stroke Thickness Popover (1–50 px)

public struct CustomThicknessPopover: View {
    @ObservedObject var dataStore: DataStore
    @Binding var selectedWidth: Double
    @State private var textInput: String = ""
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(dataStore.t("Grubość narzędzia", "Tool Thickness"))
                .font(.system(size: 13, weight: .bold))
            
            // Standard presets
            HStack(spacing: 5) {
                presetBtn(label: dataStore.t("Cienki", "Fine"), width: 1.5)
                presetBtn(label: dataStore.t("Średni", "Medium"), width: 3.0)
                presetBtn(label: dataStore.t("Gruby", "Thick"), width: 6.0)
                presetBtn(label: dataStore.t("B. gruby", "Very Thick"), width: 12.0)
            }
            
            Divider().padding(.vertical, 2)
            
            // Custom pixel slider & direct text input
            HStack {
                Text(dataStore.t("Dowolny rozmiar:", "Custom size:"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                TextField("", text: $textInput, onCommit: {
                    if let val = Double(textInput.replacingOccurrences(of: ",", with: ".")) {
                        selectedWidth = max(0.5, min(50.0, val))
                    }
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 52)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                Text("px")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .onAppear {
                textInput = String(format: "%.1f", selectedWidth)
            }
            .onChange(of: selectedWidth) {
                textInput = String(format: "%.1f", selectedWidth)
            }
            
            Slider(value: $selectedWidth, in: 0.5...50.0, step: 0.5)
            
            // Live Stroke Preview
            HStack {
                Text(dataStore.t("Podgląd:", "Preview:"))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                RoundedRectangle(cornerRadius: CGFloat(selectedWidth / 2.0))
                    .fill(Color.primary)
                    .frame(width: 100, height: max(1.0, min(36.0, CGFloat(selectedWidth))))
            }
            .frame(height: 38)
        }
        .padding(12)
        .frame(width: 250)
    }
    
    private func presetBtn(label: String, width: Double) -> some View {
        Button(action: { selectedWidth = width }) {
            VStack(spacing: 3) {
                Circle()
                    .fill(Color.primary)
                    .frame(width: CGFloat(min(12, max(3, width * 1.5))), height: CGFloat(min(12, max(3, width * 1.5))))
                Text(label)
                    .font(.system(size: 9, weight: abs(selectedWidth - width) < 0.2 ? .bold : .regular))
                Text("\(String(format: "%.1f", width)) pt")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(abs(selectedWidth - width) < 0.2 ? Color.accentColor.opacity(0.18) : Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(abs(selectedWidth - width) < 0.2 ? Color.accentColor : Color.clear, lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Table Picker Popover

public struct TablePickerPopover: View {
    @ObservedObject var dataStore: DataStore
    var onSelect: () -> Void
    
    @State private var rows: Int = 3
    @State private var cols: Int = 3
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(dataStore.t("Wstaw tabelę", "Insert Table"))
                .font(.headline)
            
            Text(dataStore.t("Wybierz liczbę wierszy i kolumn:", "Choose number of rows and columns:"))
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                Stepper("\(dataStore.t("Wiersze", "Rows")): \(rows)", value: $rows, in: 1...20)
                Stepper("\(dataStore.t("Kolumny", "Columns")): \(cols)", value: $cols, in: 1...12)
            }
            .font(.system(size: 12))
            
            HStack(spacing: 6) {
                ForEach([(2,2), (3,3), (4,3), (5,4)], id: \.0) { r, c in
                    Button("\(r)×\(c)") {
                        rows = r
                        cols = c
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            Divider()
            
            HStack {
                Spacer()
                Button("\(dataStore.t("Wstaw tabelę", "Insert Table")) (\(rows)×\(cols))") {
                    dataStore.addTable(x: 250, y: 250, rows: rows, cols: cols)
                    onSelect()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .frame(width: 300)
    }
}

// MARK: - Shape Picker Popover Gallery

public struct ShapePickerPopover: View {
    @ObservedObject var dataStore: DataStore
    var onSelect: () -> Void
    
    private let availableShapes: [(ShapeKind, String)] = [
        (.line, "line.diagonal"),
        (.arrow, "arrow.up.right"),
        (.doubleArrow, "arrow.left.and.right"),
        (.square, "square"),
        (.rectangle, "rectangle"),
        (.roundedRectangle, "app"),
        (.circle, "circle"),
        (.ellipse, "oval"),
        (.triangle, "triangle"),
        (.rhombus, "diamond"),
        (.parallelogram, "skew"),
        (.trapezoid, "trapezoid.and.line.horizontal"),
        (.rightTrapezoid, "trapezoid.and.line.vertical"),
        (.rightTrapezoidRight, "trapezoid.and.line.vertical.fill"),
        (.hexagon, "hexagon"),
        (.stretchedHexagon, "capsule"),
        (.star, "star"),
        (.cloud, "cloud")
    ]
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(dataStore.t("Wstaw figurę geometryczną", "Insert Geometric Shape"))
                .font(.headline)
            
            Text(dataStore.t("Wybierz kształt, aby wstawić go na kartkę. Będziesz mógł swobodnie zmieniać jego rozmiar i kierunek!", "Choose a shape to place on the canvas. You can freely resize and rotate it!"))
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 95))], spacing: 8) {
                ForEach(availableShapes, id: \.0) { kind, icon in
                    Button(action: {
                        dataStore.insertShape(kind: kind)
                        onSelect()
                    }) {
                        VStack(spacing: 5) {
                            Image(systemName: icon)
                                .font(.system(size: 20))
                                .foregroundColor(.accentColor)
                            Text(kind.localizedName(language: dataStore.language))
                                .font(.system(size: 10))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(width: 350)
    }
}

// Visual effect helper for native macOS translucent vibrancy
public struct VisualEffectBackground: NSViewRepresentable {
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .headerView
        view.blendingMode = .withinWindow
        view.state = .followsWindowActiveState
        return view
    }
    
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Tablet Settings & Live Diagnostics Popover

public struct TabletSettingsPopover: View {
    @ObservedObject var dataStore: DataStore
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "hand.draw.fill")
                    .foregroundColor(.accentColor)
                Text(dataStore.t("Diagnostyka i ustawienia tabletu", "Tablet Diagnostics & Settings"))
                    .font(.headline)
            }
            
            Divider()
            
            // 1. Live Pressure Meter
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(dataStore.t("Aktualny nacisk rysika:", "Current Stylus Pressure:"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(dataStore.currentStylusPressure * 100))%")
                        .font(.caption.monospaced())
                        .fontWeight(.bold)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(dataStore.currentStylusPressure))
                    }
                }
                .frame(height: 12)
            }
            
            // 2. Device Status
            HStack {
                Circle()
                    .fill(dataStore.isStylusActive ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(dataStore.isStylusActive ? dataStore.stylusDeviceName : dataStore.t("Gotowy (oczekiwanie na rysik)", "Ready (waiting for stylus)"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // 3. Pressure Sensitivity Curve
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dataStore.t("Czułość nacisku (krzywa reakcji):", "Pressure Sensitivity (Response Curve):"))
                        .font(.caption)
                    Spacer()
                    Text("\(String(format: "%.1f", dataStore.pressureSensitivity))x")
                        .font(.caption.monospaced())
                }
                
                Slider(value: $dataStore.pressureSensitivity, in: 0.5...2.5, step: 0.1)
                
                HStack {
                    Text(dataStore.t("Miękka (lekki dotyk)", "Soft (Light Touch)"))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(dataStore.t("Twarda (mocny docisk)", "Firm (Heavy Press)"))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            
            // 4. Fallback Pressure Simulation (Dynamic Calligraphy from Speed)
            Toggle(isOn: $dataStore.simulatePressureIfZero) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dataStore.t("Płynna kaligrafia dla myszy / gładzika", "Smooth Calligraphy for Mouse / Trackpad"))
                        .font(.caption)
                        .fontWeight(.medium)
                    Text(dataStore.t("Symuluje naturalną zmienną grubość na podstawie prędkości ruchu", "Simulates dynamic thickness based on motion speed"))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.checkbox)
            
            Divider()
            
            // 5. Help for macOS System Permissions
            VStack(alignment: .leading, spacing: 4) {
                Text(dataStore.t("💡 Jeśli tablet nie reaguje na nacisk:", "💡 If tablet does not respond to pressure:"))
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(dataStore.t("W macOS: Ustawienia systemowe ➔ Prywatność i ochrona ➔ Dostępność oraz Monitorowanie wprowadzania ➔ dodaj lub zaznacz Quillfolio oraz sterowniki swojego tabletu (np. Wacom / Huion / XP-Pen).", "In macOS: System Settings ➔ Privacy & Security ➔ Accessibility & Input Monitoring ➔ check Quillfolio and your tablet drivers (e.g. Wacom / Huion / XP-Pen)."))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .frame(width: 320)
    }
}
