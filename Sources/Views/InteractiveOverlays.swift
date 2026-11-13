import SwiftUI
import AppKit

// MARK: - Typography Resolver Helper

public func resolveCustomFont(name: String, size: Double, isBold: Bool, isItalic: Bool) -> Font {
    var f: Font
    switch name {
    case "helvetica": f = .custom("Helvetica Neue", size: size)
    case "times": f = .custom("Times New Roman", size: size)
    case "georgia": f = .custom("Georgia", size: size)
    case "courier": f = .custom("Courier New", size: size)
    case "menlo": f = .custom("Menlo", size: size)
    case "palatino": f = .custom("Palatino", size: size)
    case "futura": f = .custom("Futura", size: size)
    case "avenir": f = .custom("Avenir Next", size: size)
    case "noteworthy", "handwriting": f = .custom("Noteworthy-Bold", size: size)
    case "chalkboard": f = .custom("Chalkboard", size: size)
    case "optima": f = .custom("Optima", size: size)
    case "serif": f = .system(size: size, design: .serif)
    case "monospaced": f = .system(size: size, design: .monospaced)
    case "rounded": f = .system(size: size, design: .rounded)
    default: f = .system(size: size, design: .default)
    }
    if isBold { f = f.bold() }
    if isItalic { f = f.italic() }
    return f
}

// MARK: - Canvas Text Box Component (Paint-style Transparent Floating Text)

public struct CanvasTextBoxOverlay: View {
    let textBox: CanvasTextBox
    var isSelected: Bool
    var isDarkPaper: Bool
    var onSelect: () -> Void
    var onDelete: () -> Void
    var onUpdate: (CanvasTextBox) -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var initialPos: CGPoint? = nil
    @State private var isHovering: Bool = false
    @State private var isDragging: Bool = false
    
    public var body: some View {
        let effX = (initialPos?.x ?? CGFloat(textBox.x)) + dragOffset.width
        let effY = (initialPos?.y ?? CGFloat(textBox.y)) + dragOffset.height
        
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                // Stable Header bar (Opacity toggled so geometry never shifts or jumps)
                HStack(spacing: 6) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Text("Tekst")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Usuń pole tekstowe")
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.85))
                .cornerRadius(4)
                .padding(.bottom, 2)
                .opacity((isSelected || isHovering || isDragging) ? 1.0 : 0.0)
                .allowsHitTesting(isSelected || isHovering || isDragging)
                .gesture(
                    DragGesture(coordinateSpace: .named("canvas"))
                        .onChanged { val in
                            isDragging = true
                            isHovering = true
                            if initialPos == nil {
                                initialPos = CGPoint(x: CGFloat(textBox.x), y: CGFloat(textBox.y))
                            }
                            dragOffset = val.translation
                        }
                        .onEnded { val in
                            let start = initialPos ?? CGPoint(x: CGFloat(textBox.x), y: CGFloat(textBox.y))
                            let finalX = Double(start.x + val.translation.width)
                            let finalY = Double(start.y + val.translation.height)
                            initialPos = nil
                            dragOffset = .zero
                            isDragging = false
                            var updated = textBox
                            updated.x = finalX
                            updated.y = finalY
                            onUpdate(updated)
                        }
                )
                
                // Transparent text area
                TextEditor(text: Binding(
                    get: { textBox.text },
                    set: { newText in
                        var updated = textBox
                        updated.text = newText
                        onUpdate(updated)
                    }
                ))
                .font(resolvedFont)
                .multilineTextAlignment(resolvedAlignment)
                .padding(.leading, CGFloat(textBox.indentLevel * 18))
                .foregroundColor(Color(NSColor(hex: textBox.textColorHex) ?? (isDarkPaper ? .white : .black)))
                .scrollContentBackground(.hidden)
                .frame(width: max(40, textBox.width), height: max(24, textBox.height))
            }
            .frame(width: max(40, textBox.width))
            .padding(6)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.accentColor.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            .background(Color(NSColor.textBackgroundColor).opacity(0.12))
                    } else if isHovering {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    } else {
                        Color.clear
                    }
                }
            )
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded { onSelect() })
            
            // Bottom-right resize handle
            ResizeCornerHandle { delta in
                var updated = textBox
                updated.width = max(40, textBox.width + Double(delta.width))
                updated.height = max(24, textBox.height + Double(delta.height))
                onUpdate(updated)
            }
            .offset(x: 4, y: 4)
            .opacity((isSelected || isHovering || isDragging) ? 1.0 : 0.0)
            .allowsHitTesting(isSelected || isHovering || isDragging)
        }
        .frame(width: max(40, textBox.width))
        .onHover { hovering in
            if !isDragging {
                isHovering = hovering
            }
        }
        .offset(x: effX, y: effY)
    }
    
    private var resolvedAlignment: TextAlignment {
        switch textBox.textAlignment {
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }
    
    private var resolvedFont: Font {
        resolveCustomFont(name: textBox.fontDesign, size: textBox.fontSize, isBold: textBox.isBold, isItalic: textBox.isItalic)
    }
}

// MARK: - Sticky Note Component (Resizable Pastel Paper)

public struct StickyNoteOverlay: View {
    let sticky: StickyNote
    var isSelected: Bool
    var onSelect: () -> Void
    var onDelete: () -> Void
    var onUpdate: (StickyNote) -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var initialPos: CGPoint? = nil
    @State private var isHovering: Bool = false
    @State private var isDragging: Bool = false
    
    private let presetColors: [String] = [
        "#FFF475", // Pastel yellow
        "#F28B82", // Pastel red/pink
        "#FBBC04", // Pastel orange
        "#CCFF90", // Pastel green
        "#A7FFEB", // Pastel teal
        "#D7AEFB"  // Pastel purple
    ]
    
    public var body: some View {
        let effX = (initialPos?.x ?? CGFloat(sticky.x)) + dragOffset.width
        let effY = (initialPos?.y ?? CGFloat(sticky.y)) + dragOffset.height
        
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 6) {
                // Header: Pin, preset colors, delete button (acts as draggable handle)
                HStack(spacing: 6) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color.black.opacity(0.55))
                        .rotationEffect(.degrees(25))
                    
                    HStack(spacing: 4) {
                        ForEach(presetColors, id: \.self) { hex in
                            Circle()
                                .fill(Color(NSColor(hex: hex) ?? .yellow))
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Circle().stroke(Color.black.opacity(sticky.colorHex == hex ? 0.6 : 0.15), lineWidth: 1)
                                )
                                .onTapGesture {
                                    var updated = sticky
                                    updated.colorHex = hex
                                    onUpdate(updated)
                                }
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color.black.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                    .help("Usuń karteczkę")
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(coordinateSpace: .named("canvas"))
                        .onChanged { val in
                            isDragging = true
                            isHovering = true
                            if initialPos == nil {
                                initialPos = CGPoint(x: CGFloat(sticky.x), y: CGFloat(sticky.y))
                            }
                            dragOffset = val.translation
                        }
                        .onEnded { val in
                            let start = initialPos ?? CGPoint(x: CGFloat(sticky.x), y: CGFloat(sticky.y))
                            let finalX = Double(start.x + val.translation.width)
                            let finalY = Double(start.y + val.translation.height)
                            initialPos = nil
                            dragOffset = .zero
                            isDragging = false
                            var updated = sticky
                            updated.x = finalX
                            updated.y = finalY
                            onUpdate(updated)
                        }
                )
                
                // Editable Note Area
                TextEditor(text: Binding(
                    get: { sticky.text },
                    set: { newText in
                        var updated = sticky
                        updated.text = newText
                        onUpdate(updated)
                    }
                ))
                .font(resolvedFont)
                .multilineTextAlignment(resolvedAlignment)
                .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.12))
                .scrollContentBackground(.hidden)
                .frame(width: max(80, sticky.width - 20), height: max(60, sticky.height - 40))
                .onTapGesture {
                    onSelect()
                }
            }
            .frame(width: max(80, sticky.width))
            .padding(8)
            .background(
                Color(NSColor(hex: sticky.colorHex) ?? NSColor(red: 1.0, green: 0.96, blue: 0.6, alpha: 1.0))
            )
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.black.opacity(0.12), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 6, x: 2, y: 4)
            .rotationEffect(.degrees(sticky.rotationDegrees))
            
            // Bottom-right resize handle
            ResizeCornerHandle { delta in
                var updated = sticky
                updated.width = max(80, updated.width + Double(delta.width))
                updated.height = max(60, updated.height + Double(delta.height))
                onUpdate(updated)
            }
            .offset(x: 2, y: 2)
            .opacity((isSelected || isHovering || isDragging) ? 1.0 : 0.0)
            .allowsHitTesting(isSelected || isHovering || isDragging)
        }
        .frame(width: max(80, sticky.width), height: max(60, sticky.height))
        .onHover { hovering in
            if !isDragging {
                isHovering = hovering
            }
        }
        .offset(x: effX, y: effY)
    }
    
    private var resolvedAlignment: TextAlignment {
        switch sticky.textAlignment {
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }
    
    private var resolvedFont: Font {
        resolveCustomFont(name: sticky.fontDesign, size: sticky.fontSize, isBold: sticky.isBold, isItalic: sticky.isItalic)
    }
}

// MARK: - Canvas Image Overlay Component

public struct CanvasImageOverlay: View {
    let image: CanvasImage
    var isSelected: Bool
    var onSelect: () -> Void
    var onDelete: () -> Void
    var onUpdate: (CanvasImage) -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var initialPos: CGPoint? = nil
    @State private var isHovering: Bool = false
    @State private var isDragging: Bool = false
    
    public var body: some View {
        let effX = (initialPos?.x ?? CGFloat(image.x)) + dragOffset.width
        let effY = (initialPos?.y ?? CGFloat(image.y)) + dragOffset.height
        
        ZStack(alignment: .bottomTrailing) {
            ZStack(alignment: .topTrailing) {
                if let nsImage = NSImage(data: image.imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: max(40, image.width), height: max(40, image.height))
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .overlay(Image(systemName: "photo").font(.largeTitle).foregroundColor(.secondary))
                        .frame(width: max(40, image.width), height: max(40, image.height))
                }
                
                // Delete button
                if isSelected || isHovering {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.accentColor : (isHovering ? Color.accentColor.opacity(0.4) : Color.clear), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
            .onTapGesture {
                onSelect()
            }
            
            // Resize handle
            if isSelected || isHovering || isDragging {
                ResizeCornerHandle { delta in
                    var updated = image
                    updated.width = max(50, updated.width + Double(delta.width))
                    updated.height = max(50, updated.height + Double(delta.height))
                    onUpdate(updated)
                }
                .offset(x: 4, y: 4)
            }
        }
        .frame(width: max(40, image.width), height: max(40, image.height))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(coordinateSpace: .named("canvas"))
                .onChanged { val in
                    isDragging = true
                    if initialPos == nil {
                        initialPos = CGPoint(x: image.x, y: image.y)
                    }
                    dragOffset = val.translation
                }
                .onEnded { val in
                    let start = initialPos ?? CGPoint(x: image.x, y: image.y)
                    let finalX = start.x + Double(val.translation.width)
                    let finalY = start.y + Double(val.translation.height)
                    initialPos = nil
                    dragOffset = .zero
                    isDragging = false
                    var updated = image
                    updated.x = finalX
                    updated.y = finalY
                    onUpdate(updated)
                }
        )
        .onHover { isHovering = $0 }
        .offset(x: effX, y: effY)
    }
}

// MARK: - Reusable Resize Corner Handle

private struct ResizeCornerHandle: View {
    var onResize: (CGSize) -> Void
    
    @State private var currentTranslation: CGSize = .zero
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 12, height: 12)
            .overlay(
                Circle().stroke(Color.accentColor, lineWidth: 2)
            )
            .shadow(radius: 2)
            .gesture(
                DragGesture(coordinateSpace: .named("canvas"))
                    .onChanged { val in
                        let delta = CGSize(
                            width: val.translation.width - currentTranslation.width,
                            height: val.translation.height - currentTranslation.height
                        )
                        currentTranslation = val.translation
                        onResize(delta)
                    }
                    .onEnded { _ in
                        currentTranslation = .zero
                    }
            )
    }
}

// MARK: - Rich Text Formatting Toolbar (Shown below main toolbar when text item is selected)

public struct TextFormattingToolbar: View {
    @ObservedObject var dataStore: DataStore
    
    private let fontSizes: [Double] = [10, 12, 14, 16, 18, 20, 24, 28, 32, 40]
    
    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "character.cursor.ibeam")
                .foregroundColor(.accentColor)
                .font(.system(size: 12))
            
            Text("Formatowanie tekstu:")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            
            Divider().frame(height: 18)
            
            // 1. Font Family Picker
            Menu {
                Button("Domyślna (San Francisco)") { dataStore.updateActiveTextFormatting(fontDesign: "default") }
                Button("Helvetica Neue") { dataStore.updateActiveTextFormatting(fontDesign: "helvetica") }
                Button("Times New Roman") { dataStore.updateActiveTextFormatting(fontDesign: "times") }
                Button("Georgia") { dataStore.updateActiveTextFormatting(fontDesign: "georgia") }
                Button("Palatino") { dataStore.updateActiveTextFormatting(fontDesign: "palatino") }
                Button("Futura") { dataStore.updateActiveTextFormatting(fontDesign: "futura") }
                Button("Avenir Next") { dataStore.updateActiveTextFormatting(fontDesign: "avenir") }
                Button("Menlo (Kod)") { dataStore.updateActiveTextFormatting(fontDesign: "menlo") }
                Button("Courier New") { dataStore.updateActiveTextFormatting(fontDesign: "courier") }
                Button("Noteworthy (Odręczne)") { dataStore.updateActiveTextFormatting(fontDesign: "noteworthy") }
                Button("Chalkboard (Tablica)") { dataStore.updateActiveTextFormatting(fontDesign: "chalkboard") }
                Button("Optima") { dataStore.updateActiveTextFormatting(fontDesign: "optima") }
                Button("Systemowa Zaokrąglona") { dataStore.updateActiveTextFormatting(fontDesign: "rounded") }
                Button("Systemowa Szeryfowa") { dataStore.updateActiveTextFormatting(fontDesign: "serif") }
            } label: {
                HStack(spacing: 3) {
                    Text(currentFontName)
                        .font(.system(size: 11))
                    Image(systemName: "chevron.down").font(.system(size: 8))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                .cornerRadius(4)
            }
            .menuStyle(.borderlessButton)
            
            // 2. Font Size Picker
            Menu {
                ForEach(fontSizes, id: \.self) { sz in
                    Button("\(Int(sz)) pt") {
                        dataStore.updateActiveTextFormatting(fontSize: sz)
                    }
                }
            } label: {
                HStack(spacing: 2) {
                    Text("\(Int(currentFontSize)) pt")
                        .font(.system(size: 11))
                    Image(systemName: "chevron.down").font(.system(size: 8))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                .cornerRadius(4)
            }
            .menuStyle(.borderlessButton)
            
            Divider().frame(height: 18)
            
            // 3. Style Buttons (Bold, Italic, Underline, Strikethrough)
            HStack(spacing: 2) {
                formatButton(title: "B", isBold: true, isActive: isCurrentBold) {
                    dataStore.updateActiveTextFormatting(toggleBold: true)
                }
                formatButton(title: "I", isItalic: true, isActive: isCurrentItalic) {
                    dataStore.updateActiveTextFormatting(toggleItalic: true)
                }
                formatButton(title: "U", isUnderline: true, isActive: isCurrentUnderline) {
                    dataStore.updateActiveTextFormatting(toggleUnderline: true)
                }
                formatButton(title: "S", isStrikethrough: true, isActive: isCurrentStrikethrough) {
                    dataStore.updateActiveTextFormatting(toggleStrikethrough: true)
                }
            }
            
            Divider().frame(height: 18)
            
            // 4. Alignment Buttons
            HStack(spacing: 2) {
                iconButton(icon: "text.alignleft", isActive: currentAlignment == "left") {
                    dataStore.updateActiveTextFormatting(alignment: "left")
                }
                iconButton(icon: "text.aligncenter", isActive: currentAlignment == "center") {
                    dataStore.updateActiveTextFormatting(alignment: "center")
                }
                iconButton(icon: "text.alignright", isActive: currentAlignment == "right") {
                    dataStore.updateActiveTextFormatting(alignment: "right")
                }
            }
            
            Divider().frame(height: 18)
            
            // 5. Indentation
            HStack(spacing: 2) {
                iconButton(icon: "decrease.indent", isActive: false) {
                    dataStore.changeActiveTextIndent(delta: -1)
                }
                .help(dataStore.t("Zmniejsz wcięcie", "Decrease indent"))
                
                iconButton(icon: "increase.indent", isActive: false) {
                    dataStore.changeActiveTextIndent(delta: 1)
                }
                .help(dataStore.t("Zwiększ wcięcie", "Increase indent"))
            }
            
            Divider().frame(height: 18)
            
            // 6. Bullet & Number Lists
            Menu {
                Button(dataStore.t("• Kropka (Punktor)", "• Bullet point")) {
                    dataStore.updateActiveTextFormatting(listType: "bullet_dot")
                    appendBulletPrefix("• ")
                }
                Button(dataStore.t("- Kreska", "- Dash")) {
                    dataStore.updateActiveTextFormatting(listType: "bullet_dash")
                    appendBulletPrefix("- ")
                }
                Button(dataStore.t("▪ Kwadrat", "▪ Square")) {
                    dataStore.updateActiveTextFormatting(listType: "bullet_square")
                    appendBulletPrefix("▪ ")
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 11))
                    Text(dataStore.t("Punkty", "Bullets"))
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(currentListType.starts(with: "bullet") ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor).opacity(0.7))
                .cornerRadius(4)
            }
            .menuStyle(.borderlessButton)
            
            Button(action: {
                dataStore.updateActiveTextFormatting(listType: "numbered")
                appendBulletPrefix("1. ")
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "list.number")
                        .font(.system(size: 11))
                    Text("1, 2, 3")
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(currentListType == "numbered" ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor).opacity(0.7))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            
            Divider().frame(height: 18)
            
            // 7. Text Color Selection (Presets + Custom Native macOS Color Wheel)
            HStack(spacing: 4) {
                ForEach(["#000000", "#FFFFFF", "#007AFF", "#10B981", "#FF3B30", "#AF52DE", "#FF9500"], id: \.self) { hex in
                    Circle()
                        .fill(Color(NSColor(hex: hex) ?? .black))
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle().stroke(Color.primary.opacity(0.8), lineWidth: currentTextColorHex.uppercased() == hex.uppercased() ? 2 : 0.5)
                        )
                        .onTapGesture {
                            dataStore.updateActiveTextFormatting(textColorHex: hex)
                        }
                }
                
                Divider()
                    .frame(height: 14)
                    .padding(.horizontal, 6)
                
                ColorPicker("", selection: Binding(
                    get: { Color(NSColor(hex: currentTextColorHex) ?? .black) },
                    set: { newColor in
                        if let nsColor = NSColor(newColor).usingColorSpace(.sRGB) {
                            let r = Int(round(nsColor.redComponent * 255.0))
                            let g = Int(round(nsColor.greenComponent * 255.0))
                            let b = Int(round(nsColor.blueComponent * 255.0))
                            let hex = String(format: "#%02X%02X%02X", max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))
                            dataStore.updateActiveTextFormatting(textColorHex: hex)
                        }
                    }
                ))
                .labelsHidden()
                .frame(width: 24, height: 24)
                .help(dataStore.t("Wybierz dowolny kolor tekstu z koła barw macOS", "Choose any text color from macOS color wheel"))
            }
            
            Divider().frame(height: 18)
            
            // 8. Math & Academic Symbols Menu
            Menu {
                Section(dataStore.t("Matematyka & Rachunek", "Math & Calculus")) {
                    ForEach(["π", "∑", "∫", "∞", "√", "≈", "≠", "≤", "≥", "±", "×", "÷", "∂", "∆"], id: \.self) { sym in
                        Button(sym) { dataStore.insertSymbolIntoActiveText(sym) }
                    }
                }
                Section(dataStore.t("Zbiory & Logika", "Sets & Logic")) {
                    ForEach(["∈", "∉", "⊂", "⊆", "∪", "∩", "∅", "∀", "∃", "⇒", "⇔", "→", "←"], id: \.self) { sym in
                        Button(sym) { dataStore.insertSymbolIntoActiveText(sym) }
                    }
                }
                Section(dataStore.t("Litery greckie", "Greek Letters")) {
                    ForEach(["α", "β", "γ", "θ", "λ", "μ", "σ", "ω", "∆", "Ω", "φ", "ψ"], id: \.self) { sym in
                        Button(sym) { dataStore.insertSymbolIntoActiveText(sym) }
                    }
                }
                Section(dataStore.t("Indeksy i potęgi", "Indices & Powers")) {
                    ForEach(["²", "³", "⁴", "ⁿ", "₀", "₁", "₂", "ᵢ", "½", "¼", "°"], id: \.self) { sym in
                        Button(sym) { dataStore.insertSymbolIntoActiveText(sym) }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "function")
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)
                    Text(dataStore.t("Symbole", "Symbols"))
                        .font(.system(size: 11))
                    Image(systemName: "chevron.down").font(.system(size: 8))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                .cornerRadius(4)
            }
            .menuStyle(.borderlessButton)
            .help(dataStore.t("Wstaw symbole matematyczne, greckie, logiczne i potęgi", "Insert mathematical, Greek, logical and power symbols"))
            
            Spacer()
            
            // Close editing bar
            Button(action: {
                dataStore.activeEditingTextBoxId = nil
                dataStore.activeEditingStickyId = nil
            }) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .help(dataStore.t("Zakończ edycję tekstu", "Finish text editing"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
        .overlay(Divider(), alignment: .bottom)
    }
    
    private func appendBulletPrefix(_ prefix: String) {
        guard let noteId = dataStore.selectedNoteId,
              let nIdx = dataStore.notes.firstIndex(where: { $0.id == noteId }) else { return }
        let pIdx = dataStore.notes[nIdx].currentPageIndex
        if let boxId = dataStore.activeEditingTextBoxId,
           let bIdx = dataStore.notes[nIdx].pages[pIdx].textBoxes.firstIndex(where: { $0.id == boxId }) {
            let txt = dataStore.notes[nIdx].pages[pIdx].textBoxes[bIdx].text
            if !txt.hasPrefix(prefix) {
                dataStore.notes[nIdx].pages[pIdx].textBoxes[bIdx].text = prefix + txt
                dataStore.saveToDisk()
            }
        }
    }
    
    // Formatting getters
    private var currentFontName: String {
        let design = currentTextBox?.fontDesign ?? currentSticky?.fontDesign ?? "default"
        switch design {
        case "helvetica": return "Helvetica"
        case "times": return "Times New Roman"
        case "georgia": return "Georgia"
        case "courier": return "Courier"
        case "menlo": return dataStore.t("Menlo (Kod)", "Menlo (Code)")
        case "palatino": return "Palatino"
        case "futura": return "Futura"
        case "avenir": return "Avenir Next"
        case "noteworthy", "handwriting": return "Noteworthy"
        case "chalkboard": return "Chalkboard"
        case "optima": return "Optima"
        case "serif": return "Serif"
        case "monospaced": return "Monospace"
        case "rounded": return dataStore.t("Zaokrąglona", "Rounded")
        default: return dataStore.t("Domyślna (SF)", "Default (SF)")
        }
    }
    
    private var currentFontSize: Double {
        currentTextBox?.fontSize ?? currentSticky?.fontSize ?? 16
    }
    
    private var isCurrentBold: Bool {
        currentTextBox?.isBold ?? currentSticky?.isBold ?? false
    }
    
    private var isCurrentItalic: Bool {
        currentTextBox?.isItalic ?? currentSticky?.isItalic ?? false
    }
    
    private var isCurrentUnderline: Bool {
        currentTextBox?.isUnderline ?? currentSticky?.isUnderline ?? false
    }
    
    private var isCurrentStrikethrough: Bool {
        currentTextBox?.isStrikethrough ?? false
    }
    
    private var currentAlignment: String {
        currentTextBox?.textAlignment ?? currentSticky?.textAlignment ?? "left"
    }
    
    private var currentListType: String {
        currentTextBox?.listType ?? currentSticky?.listType ?? "none"
    }
    
    private var currentTextColorHex: String {
        currentTextBox?.textColorHex ?? "#000000"
    }
    
    private var currentTextBox: CanvasTextBox? {
        guard let boxId = dataStore.activeEditingTextBoxId else { return nil }
        return dataStore.selectedNote?.currentPage.textBoxes.first(where: { $0.id == boxId })
    }
    
    private var currentSticky: StickyNote? {
        guard let stickyId = dataStore.activeEditingStickyId else { return nil }
        return dataStore.selectedNote?.currentPage.stickyNotes.first(where: { $0.id == stickyId })
    }
    
    @ViewBuilder
    private func formatButton(title: String, isBold: Bool = false, isItalic: Bool = false, isUnderline: Bool = false, isStrikethrough: Bool = false, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isBold ? .bold : .regular))
                .italic(isItalic)
                .underline(isUnderline)
                .strikethrough(isStrikethrough)
                .frame(width: 22, height: 20)
                .background(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func iconButton(icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .frame(width: 22, height: 20)
                .background(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Canvas Interactive Table Overlay Component

public struct CanvasTableOverlay: View {
    let table: CanvasTable
    var isSelected: Bool
    var isDarkPaper: Bool
    var onSelect: () -> Void
    var onDelete: () -> Void
    var onUpdate: (CanvasTable) -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var initialPos: CGPoint? = nil
    @State private var isHovering: Bool = false
    @State private var isDragging: Bool = false
    
    public var body: some View {
        let effX = (initialPos?.x ?? CGFloat(table.x)) + dragOffset.width
        let effY = (initialPos?.y ?? CGFloat(table.y)) + dragOffset.height
        
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                // Header Bar (Title, Add/Remove Row & Column, Delete)
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Text("Tabela (\(table.rows)×\(table.cols))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Spacer(minLength: 4)
                    
                    // Add Row
                    Button(action: {
                        var updated = table
                        updated.rows += 1
                        updated.data.append(Array(repeating: "", count: updated.cols))
                        updated.rowHeights.append(34.0)
                        onUpdate(updated)
                    }) {
                        Text("+ Wiersz").font(.system(size: 9))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help("Dodaj wiersz na dole tabeli")
                    
                    // Add Column
                    Button(action: {
                        var updated = table
                        updated.cols += 1
                        for r in 0..<updated.rows {
                            updated.data[r].append("")
                        }
                        updated.colWidths.append(100.0)
                        onUpdate(updated)
                    }) {
                        Text("+ Kolumna").font(.system(size: 9))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help("Dodaj kolumnę po prawej")
                    
                    if table.rows > 1 {
                        Button(action: {
                            var updated = table
                            updated.rows -= 1
                            updated.data.removeLast()
                            updated.rowHeights.removeLast()
                            onUpdate(updated)
                        }) {
                            Image(systemName: "minus").font(.system(size: 9))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .help("Usuń ostatni wiersz")
                    }
                    
                    if table.cols > 1 {
                        Button(action: {
                            var updated = table
                            updated.cols -= 1
                            for r in 0..<updated.rows {
                                updated.data[r].removeLast()
                            }
                            updated.colWidths.removeLast()
                            onUpdate(updated)
                        }) {
                            Image(systemName: "minus").font(.system(size: 9))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .help("Usuń ostatnią kolumnę")
                    }
                    
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Usuń tabelę")
                }
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
                .cornerRadius(4)
                .padding(.bottom, 2)
                .opacity((isSelected || isHovering || isDragging) ? 1.0 : 0.0)
                .allowsHitTesting(isSelected || isHovering || isDragging)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(coordinateSpace: .named("canvas"))
                        .onChanged { val in
                            isDragging = true
                            isHovering = true
                            if initialPos == nil {
                                initialPos = CGPoint(x: CGFloat(table.x), y: CGFloat(table.y))
                            }
                            dragOffset = val.translation
                        }
                        .onEnded { val in
                            let start = initialPos ?? CGPoint(x: CGFloat(table.x), y: CGFloat(table.y))
                            let finalX = Double(start.x + val.translation.width)
                            let finalY = Double(start.y + val.translation.height)
                            initialPos = nil
                            dragOffset = .zero
                            isDragging = false
                            var updated = table
                            updated.x = finalX
                            updated.y = finalY
                            onUpdate(updated)
                        }
                )
                
                // Solid, Crisp Grid of Cells Directly on Canvas
                VStack(spacing: 0) {
                    ForEach(0..<table.rows, id: \.self) { r in
                        HStack(spacing: 0) {
                            ForEach(0..<table.cols, id: \.self) { c in
                                let isHeader = (r == 0)
                                let cellText = (r < table.data.count && c < table.data[r].count) ? table.data[r][c] : ""
                                let width = (c < table.colWidths.count) ? table.colWidths[c] : 100.0
                                let height = (r < table.rowHeights.count) ? table.rowHeights[r] : 34.0
                                
                                TableCellView(
                                    isHeader: isHeader,
                                    text: cellText,
                                    width: width,
                                    height: height,
                                    isDarkPaper: isDarkPaper,
                                    onTextChange: { newText in
                                        updateCellText(row: r, col: c, newText: newText)
                                    }
                                )
                            }
                        }
                    }
                }
                .overlay(
                    Rectangle()
                        .stroke(isSelected ? Color.accentColor : Color.secondary, lineWidth: isSelected ? 2.5 : 1.5)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
            }
            .frame(width: CGFloat(table.totalWidth))
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded { onSelect() })
            
            // Resize Corner Handle
            ResizeCornerHandle { delta in
                var updated = table
                let colDelta = Double(delta.width) / Double(max(1, table.cols))
                let rowDelta = Double(delta.height) / Double(max(1, table.rows))
                for i in 0..<updated.colWidths.count {
                    updated.colWidths[i] = max(50.0, updated.colWidths[i] + colDelta)
                }
                for i in 0..<updated.rowHeights.count {
                    updated.rowHeights[i] = max(24.0, updated.rowHeights[i] + rowDelta)
                }
                onUpdate(updated)
            }
            .offset(x: 4, y: 4)
            .opacity((isSelected || isHovering || isDragging) ? 1.0 : 0.0)
            .allowsHitTesting(isSelected || isHovering || isDragging)
        }
        .frame(width: CGFloat(table.totalWidth))
        .onHover { hovering in
            if !isDragging {
                isHovering = hovering
            }
        }
        .offset(x: effX, y: effY)
    }
    
    private func updateCellText(row r: Int, col c: Int, newText: String) {
        guard r < table.data.count && c < table.data[r].count else { return }
        var updated = table
        updated.data[r][c] = newText
        
        let textLen = Double(newText.count)
        let totalNeeded = textLen * 9.2 + 24.0
        let neededWidth = max(70.0, totalNeeded)
        if c < updated.colWidths.count && neededWidth > updated.colWidths[c] {
            updated.colWidths[c] = neededWidth
        }
        onUpdate(updated)
    }
}

// MARK: - Table Cell View
struct TableCellView: View {
    let isHeader: Bool
    let text: String
    let width: Double
    let height: Double
    let isDarkPaper: Bool
    let onTextChange: (String) -> Void
    
    var body: some View {
        let bgColor: Color = isHeader
            ? (isDarkPaper ? Color(red: 0.14, green: 0.18, blue: 0.28) : Color(red: 0.08, green: 0.13, blue: 0.22))
            : (isDarkPaper ? Color(red: 0.15, green: 0.17, blue: 0.21) : Color.white)
        let fgColor: Color = isHeader
            ? Color.white
            : (isDarkPaper ? Color.white : Color(red: 0.08, green: 0.10, blue: 0.15))
        let borderColor: Color = isDarkPaper ? Color(red: 0.38, green: 0.43, blue: 0.50) : Color(red: 0.72, green: 0.76, blue: 0.82)
        
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(isHeader ? "Nagłówek" : "...")
                    .font(.system(size: isHeader ? 12 : 11, weight: isHeader ? .bold : .regular))
                    .foregroundColor(isHeader ? Color.white.opacity(0.85) : Color.secondary.opacity(0.55))
                    .padding(.horizontal, 8)
            }
            
            TextField("", text: Binding(
                get: { text },
                set: { onTextChange($0) }
            ))
            .textFieldStyle(PlainTextFieldStyle())
            .font(.system(size: isHeader ? 12 : 11, weight: isHeader ? .bold : .regular))
            .foregroundColor(fgColor)
            .padding(.horizontal, 8)
        }
        .frame(width: CGFloat(width), height: CGFloat(height))
        .background(bgColor)
        .overlay(Rectangle().stroke(borderColor, lineWidth: 0.8))
    }
}
