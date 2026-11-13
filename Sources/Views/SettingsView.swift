import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject var dataStore: DataStore
    
    public enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "general"
        case canvas = "canvas"
        case drawing = "drawing"
        case typography = "typography"
        case storage = "storage"
        case about = "about"
        
        public var id: String { rawValue }
        
        public func title(dataStore: DataStore) -> String {
            switch self {
            case .general: return dataStore.t("Ogólne & Język", "General & Language")
            case .canvas: return dataStore.t("Papier & Szablony", "Canvas & Paper")
            case .drawing: return dataStore.t("Rysowanie & Tablet", "Drawing & Stylus")
            case .typography: return dataStore.t("Typografia & Tekst", "Typography & Text")
            case .storage: return dataStore.t("Pamięć & Kopia", "Storage & Backup")
            case .about: return dataStore.t("O programie", "About Quillfolio")
            }
        }
        
        public var icon: String {
            switch self {
            case .general: return "gearshape.fill"
            case .canvas: return "doc.richtext"
            case .drawing: return "hand.draw.fill"
            case .typography: return "textformat"
            case .storage: return "externaldrive.fill"
            case .about: return "info.circle.fill"
            }
        }
    }
    
    @State private var selectedTab: SettingsTab = .general
    @State private var showingResetConfirmation = false
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar with Back Button
            HStack(spacing: 12) {
                Button(action: {
                    dataStore.showSettings = false
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text(dataStore.t("Wróć do notatek", "Back to Notes"))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text(dataStore.t("Ustawienia Quillfolio", "Quillfolio Settings"))
                        .font(.system(size: 16, weight: .bold))
                }
                
                Spacer()
                
                // Done button
                Button(action: {
                    dataStore.showSettings = false
                }) {
                    Text(dataStore.t("Gotowe", "Done"))
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
            .overlay(Divider(), alignment: .bottom)
            
            // Content Area with Sidebar Navigation
            HSplitView {
                // Left Tabs Sidebar
                VStack(spacing: 4) {
                    ForEach(SettingsTab.allCases) { tab in
                        Button(action: {
                            selectedTab = tab
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 14))
                                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                                    .frame(width: 20)
                                
                                Text(tab.title(dataStore: dataStore))
                                    .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                                    .foregroundColor(selectedTab == tab ? .primary : .secondary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                    
                    // Quick Language Switcher in Sidebar footer
                    VStack(alignment: .leading, spacing: 6) {
                        Text(dataStore.t("Język interfejsu:", "Interface Language:"))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 6) {
                            ForEach(AppLanguage.allCases) { lang in
                                Button(action: {
                                    dataStore.language = lang
                                }) {
                                    HStack(spacing: 4) {
                                        Text(lang.flag)
                                        Text(lang.displayName)
                                            .font(.system(size: 11, weight: dataStore.language == lang ? .bold : .regular))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(dataStore.language == lang ? Color.accentColor.opacity(0.2) : Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(dataStore.language == lang ? Color.accentColor : Color.clear, lineWidth: 1.2)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                }
                .padding(14)
                .frame(minWidth: 200, idealWidth: 220, maxWidth: 260)
                .background(Color(NSColor.underPageBackgroundColor).opacity(0.5))
                
                // Right Detail Content
                ScrollView([.vertical], showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 22) {
                        switch selectedTab {
                        case .general:
                            generalSettingsView
                        case .canvas:
                            canvasSettingsView
                        case .drawing:
                            drawingSettingsView
                        case .typography:
                            typographySettingsView
                        case .storage:
                            storageSettingsView
                        case .about:
                            aboutSettingsView
                        }
                    }
                    .padding(28)
                    .frame(maxWidth: 720, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 1. General & Language Settings View
    
    private var generalSettingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: dataStore.t("Język aplikacji", "App Language"),
                subtitle: dataStore.t("Wybierz język interfejsu użytkownika, menu i podpowiedzi", "Choose the interface, menu, and tooltip language")
            )
            
            // Language Cards
            HStack(spacing: 14) {
                ForEach(AppLanguage.allCases) { lang in
                    Button(action: {
                        dataStore.language = lang
                    }) {
                        HStack(spacing: 12) {
                            Text(lang.flag)
                                .font(.system(size: 32))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lang.displayName)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.primary)
                                Text(lang.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if dataStore.language == lang {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 18))
                            } else {
                                Circle()
                                    .stroke(Color.secondary.opacity(0.4), lineWidth: 1.5)
                                    .frame(width: 18, height: 18)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(dataStore.language == lang ? Color.accentColor.opacity(0.12) : Color(NSColor.controlBackgroundColor))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(dataStore.language == lang ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: dataStore.language == lang ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Divider().padding(.vertical, 4)
            
            sectionHeader(
                title: dataStore.t("Wygląd i motyw", "Appearance & Theme"),
                subtitle: dataStore.t("Dostosuj motyw graficzny aplikacji do swoich preferencji", "Adjust the visual theme of the app to your preference")
            )
            
            HStack(spacing: 14) {
                themeCard(id: "system", title: dataStore.t("Systemowy", "System"), icon: "circle.lefthalf.filled")
                themeCard(id: "light", title: dataStore.t("Jasny", "Light"), icon: "sun.max.fill")
                themeCard(id: "dark", title: dataStore.t("Ciemny", "Dark"), icon: "moon.fill")
            }
            
            Divider().padding(.vertical, 4)
            
            sectionHeader(
                title: dataStore.t("Opcje startowe", "Startup Options"),
                subtitle: dataStore.t("Zachowanie aplikacji podczas uruchamiania", "App startup behavior")
            )
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $dataStore.showSplashScreenOnLaunch) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dataStore.t("Animowany ekran powitalny (Splash Screen)", "Animated Splash Screen"))
                            .font(.system(size: 13, weight: .medium))
                        Text(dataStore.t("Wyświetla krótki nowoczesny ekran ładowania przy starcie", "Shows a brief modern splash screen on application launch"))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
        }
    }
    
    private func themeCard(id: String, title: String, icon: String) -> some View {
        Button(action: {
            dataStore.appTheme = id
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(dataStore.appTheme == id ? .accentColor : .secondary)
                Text(title)
                    .font(.system(size: 13, weight: dataStore.appTheme == id ? .bold : .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(dataStore.appTheme == id ? Color.accentColor.opacity(0.12) : Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(dataStore.appTheme == id ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: dataStore.appTheme == id ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 2. Canvas & Paper Settings View
    
    private var canvasSettingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: dataStore.t("Domyślny styl papieru", "Default Paper Style"),
                subtitle: dataStore.t("Styl papieru ustawiany automatycznie dla nowo tworzonych notatek", "Paper style applied automatically to newly created notes")
            )
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                ForEach(PaperStyle.allCases) { style in
                    Button(action: {
                        dataStore.defaultPaperStyle = style
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: style.iconName)
                                .font(.system(size: 26))
                                .foregroundColor(dataStore.defaultPaperStyle == style ? .accentColor : .secondary)
                            
                            Text(style.localizedName(language: dataStore.language))
                                .font(.system(size: 12, weight: dataStore.defaultPaperStyle == style ? .bold : .medium))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 76)
                        .padding(10)
                        .background(dataStore.defaultPaperStyle == style ? Color.accentColor.opacity(0.12) : Color(NSColor.controlBackgroundColor))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(dataStore.defaultPaperStyle == style ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: dataStore.defaultPaperStyle == style ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Divider().padding(.vertical, 4)
            
            sectionHeader(
                title: dataStore.t("Domyślny kolor kartki", "Default Paper Color"),
                subtitle: dataStore.t("Podstawowy odcień i faktura tła notatnika", "Base color and background tone for the notebook canvas")
            )
            
            VStack(spacing: 8) {
                ForEach(PaperColor.allCases) { color in
                    Button(action: {
                        dataStore.defaultPaperColor = color
                    }) {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(color.backgroundColor)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(color.localizedName(language: dataStore.language))
                                    .font(.system(size: 13, weight: dataStore.defaultPaperColor == color ? .bold : .medium))
                                    .foregroundColor(.primary)
                                Text(color.isDark ? dataStore.t("Ciemne tło (automatycznie biały tusz)", "Dark canvas (automatically uses white ink)") : dataStore.t("Jasne tło (standardowy ciemny tusz)", "Light canvas (standard dark ink)"))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if dataStore.defaultPaperColor == color {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 16))
                            }
                        }
                        .padding(10)
                        .background(dataStore.defaultPaperColor == color ? Color.accentColor.opacity(0.12) : Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(dataStore.defaultPaperColor == color ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: dataStore.defaultPaperColor == color ? 1.8 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - 3. Drawing & Stylus Settings View
    
    private var drawingSettingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: dataStore.t("Domyślne narzędzie do rysowania", "Default Drawing Tool"),
                subtitle: dataStore.t("Narzędzie aktywowane domyślnie po otwarciu notatki", "Active tool selected by default when opening a note")
            )
            
            HStack(spacing: 8) {
                ForEach([DrawingTool.pen, .calligraphy, .brush, .pencil, .highlighter], id: \.self) { tool in
                    Button(action: {
                        dataStore.defaultDrawingTool = tool
                        dataStore.selectedTool = tool
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: tool.iconName)
                                .font(.system(size: 18))
                                .foregroundColor(dataStore.defaultDrawingTool == tool ? .accentColor : .primary)
                            Text(tool.localizedName(language: dataStore.language))
                                .font(.system(size: 10, weight: dataStore.defaultDrawingTool == tool ? .bold : .regular))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .padding(6)
                        .background(dataStore.defaultDrawingTool == tool ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(dataStore.defaultDrawingTool == tool ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Divider().padding(.vertical, 4)
            
            sectionHeader(
                title: dataStore.t("Wygładzanie i jakość kresek", "Stroke Smoothing & Quality"),
                subtitle: dataStore.t("Zaawansowane algorytmy cyfrowego atramentu", "Advanced digital ink algorithms")
            )
            
            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $dataStore.strokeSmoothingEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dataStore.t("Wektoryzacja i wygładzanie krzywymi Béziera", "Bézier Spline Vector Smoothing"))
                            .font(.system(size: 13, weight: .medium))
                        Text(dataStore.t("Eliminuje drżenie ręki i poszarpania, dając idealnie zaokrąglone pismo odręczne", "Removes hand jitter and jagged corners, producing smooth handwriting"))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
                
                Toggle(isOn: $dataStore.simulatePressureIfZero) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dataStore.t("Symulacja nacisku na podstawie prędkości ruchu", "Velocity-Based Pressure Simulation"))
                            .font(.system(size: 13, weight: .medium))
                        Text(dataStore.t("Daje naturalną zmienną grubość linii podczas pracy myszą lub gładzikiem", "Provides dynamic line thickness when drawing with mouse or trackpad"))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            
            Divider().padding(.vertical, 4)
            
            sectionHeader(
                title: dataStore.t("Czułość tabletu i auto-kształty", "Stylus Sensitivity & Auto-Shapes"),
                subtitle: dataStore.t("Konfiguracja reakcji na nacisk i rozpoznawania figur", "Configure pressure curve and geometric shape hold delay")
            )
            
            VStack(alignment: .leading, spacing: 16) {
                // Pressure Slider
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(dataStore.t("Czułość nacisku piórka:", "Stylus Pressure Sensitivity:"))
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text("\(String(format: "%.1f", dataStore.pressureSensitivity))x")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    Slider(value: $dataStore.pressureSensitivity, in: 0.5...2.5, step: 0.1)
                    HStack {
                        Text(dataStore.t("Lekki dotyk (Miękka)", "Soft (Light Touch)"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(dataStore.t("Mocny docisk (Twarda)", "Firm (Heavy Press)"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // Auto Correct Delay Slider
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(dataStore.t("Czas przytrzymania dla auto-kształtu:", "Auto-Shape Hold Duration:"))
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text("\(String(format: "%.2f", dataStore.autoCorrectDelay)) s")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    Slider(value: $dataStore.autoCorrectDelay, in: 0.25...1.2, step: 0.05)
                    HStack {
                        Text(dataStore.t("Szybko (0.25s)", "Fast (0.25s)"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(dataStore.t("Długie przytrzymanie (1.20s)", "Long Hold (1.20s)"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
        }
    }
    
    // MARK: - 4. Typography & Text Settings View
    
    private var typographySettingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: dataStore.t("Domyślna typografia pól tekstowych", "Default Text Box Typography"),
                subtitle: dataStore.t("Ustawienia początkowe dla nowych pól tekstowych i karteczek", "Initial settings for new text boxes and sticky notes")
            )
            
            VStack(alignment: .leading, spacing: 14) {
                // Font Family
                VStack(alignment: .leading, spacing: 6) {
                    Text(dataStore.t("Krój czcionki:", "Font Family:"))
                        .font(.system(size: 12, weight: .medium))
                    
                    Picker("", selection: $dataStore.defaultFontFamily) {
                        Text("San Francisco (System)").tag("default")
                        Text("Helvetica Neue").tag("helvetica")
                        Text("Times New Roman").tag("times")
                        Text("Georgia").tag("georgia")
                        Text("Menlo (Kod / Monospace)").tag("menlo")
                        Text("Palatino").tag("palatino")
                        Text("Futura").tag("futura")
                        Text("Avenir Next").tag("avenir")
                        Text("Noteworthy (Odręczna)").tag("noteworthy")
                        Text("Chalkboard").tag("chalkboard")
                        Text("Optima").tag("optima")
                    }
                    .pickerStyle(.menu)
                }
                
                // Font Size
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(dataStore.t("Domyślny rozmiar:", "Default Font Size:"))
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text("\(Int(dataStore.defaultFontSize)) pt")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    Slider(value: $dataStore.defaultFontSize, in: 10...36, step: 1)
                }
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            
            Divider().padding(.vertical, 4)
            
            sectionHeader(
                title: dataStore.t("Podgląd tekstu na żywo", "Live Typography Preview"),
                subtitle: dataStore.t("Tak będzie wyglądać domyślny tekst na Twojej kartce", "This is how default text will render on your canvas")
            )
            
            VStack(alignment: .leading, spacing: 8) {
                Text(dataStore.t("Szybki brązowy lis przeskakuje nad leniwym psem.", "The quick brown fox jumps over the lazy dog."))
                    .font(resolveCustomFont(name: dataStore.defaultFontFamily, size: dataStore.defaultFontSize, isBold: false, isItalic: false))
                    .foregroundColor(.primary)
                
                Text(dataStore.t("Wzory: a² + b² = c²  |  Pole koła: P = π · r²", "Formulas: a² + b² = c²  |  Circle area: A = π · r²"))
                    .font(resolveCustomFont(name: dataStore.defaultFontFamily, size: max(11, dataStore.defaultFontSize - 2), isBold: true, isItalic: false))
                    .foregroundColor(.accentColor)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    // MARK: - 5. Storage & Backup Settings View
    
    private var storageSettingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: dataStore.t("Lokalizacja danych i pamięć", "Data Storage & Location"),
                subtitle: dataStore.t("Miejsce przechowywania wszystkich Twoich notatek na dysku Maca", "Where all your notes and drawings are saved locally on your Mac")
            )
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.accentColor)
                    Text(dataStore.t("Katalog zapisu:", "Storage Folder:"))
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                }
                
                Text(dataStore.storageDirectoryPath)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                
                Button(action: {
                    let path = dataStore.storageDirectoryPath
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                        Text(dataStore.t("Pokaż folder w Finderze", "Reveal Folder in Finder"))
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            
            Divider().padding(.vertical, 4)
            
            sectionHeader(
                title: dataStore.t("Statystyki notatnika", "Notebook Statistics"),
                subtitle: dataStore.t("Podsumowanie zgromadzonych materiałów i rysunków", "Summary of stored notes, pages, and handwritten ink strokes")
            )
            
            HStack(spacing: 12) {
                statCard(title: dataStore.t("Notatek", "Notes"), value: "\(dataStore.notes.count)", icon: "doc.text.fill")
                statCard(title: dataStore.t("Stron", "Pages"), value: "\(dataStore.totalPagesCount)", icon: "book.fill")
                statCard(title: dataStore.t("Kresek atramentu", "Ink Strokes"), value: "\(dataStore.totalStrokesCount)", icon: "pencil.tip")
                statCard(title: dataStore.t("Kategorii", "Categories"), value: "\(dataStore.categories.count)", icon: "folder.fill")
            }
            
            Divider().padding(.vertical, 4)
            
            sectionHeader(
                title: dataStore.t("Przywracanie ustawień", "Reset Settings"),
                subtitle: dataStore.t("Przywróć domyślne konfiguracje programu bez usuwania notatek", "Restore factory default configurations without deleting any notes")
            )
            
            Button(action: {
                showingResetConfirmation = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text(dataStore.t("Przywróć ustawienia domyślne...", "Reset All Settings to Defaults..."))
                }
                .font(.system(size: 12))
                .foregroundColor(.red)
            }
            .buttonStyle(.bordered)
            .alert(isPresented: $showingResetConfirmation) {
                Alert(
                    title: Text(dataStore.t("Przywrócić ustawienia domyślne?", "Reset settings to defaults?")),
                    message: Text(dataStore.t("Wszystkie preferencje wyglądu, czcionek, narzędzi i języka zostaną przywrócone do wartości fabrycznych. Twoje notatki i rysunki pozostaną nienaruszone.", "All visual, typography, tool, and language preferences will be reset to factory defaults. Your notes and drawings will remain completely safe.")),
                    primaryButton: .destructive(Text(dataStore.t("Przywróć", "Reset"))) {
                        dataStore.resetSettingsToDefaults()
                    },
                    secondaryButton: .cancel(Text(dataStore.t("Anuluj", "Cancel")))
                )
            }
        }
    }
    
    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.accentColor)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - 6. About Quillfolio View
    
    private var aboutSettingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 18) {
                if let appIcon = NSImage(named: "AppIcon") ?? NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 72, height: 72)
                        .cornerRadius(16)
                        .shadow(radius: 4)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quillfolio")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    
                    Text(dataStore.t("Wersja 1.0 (macOS Edition)", "Version 1.0 (macOS Edition)"))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text(dataStore.t("Profesjonalne studio notatek odręcznych, geometrii i organizacji wiedzy", "Professional handwriting, geometry, and knowledge studio"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 12) {
                featureRow(
                    icon: "pencil.and.outline",
                    title: dataStore.t("Cyfrowy atrament wektorowy", "Vector Digital Ink"),
                    desc: dataStore.t("Wygładzanie krzywymi Béziera, pełna obsługa nacisku rysika i eliminacja ząbkowania.", "Bézier spline smoothing, full stylus pressure dynamics, and anti-aliasing.")
                )
                featureRow(
                    icon: "wand.and.stars",
                    title: dataStore.t("Inteligentne auto-kształty", "Smart Auto-Shapes"),
                    desc: dataStore.t("Automatyczne prostowanie figur geometrycznych przy przytrzymaniu (koła, trapezy, sześciokąty, strzałki).", "Automatic geometric shape snap upon drawing hold (circles, trapezoids, hexagons, arrows).")
                )
                featureRow(
                    icon: "tablecells",
                    title: dataStore.t("Pola tekstowe i elastyczne tabele", "Text Boxes & Dynamic Tables"),
                    desc: dataStore.t("Komórki z automatycznym poszerzaniem, bogate formatowanie i symbole matematyczne.", "Auto-expanding cells, rich typography, and academic math symbol support.")
                )
                featureRow(
                    icon: "globe.europe.africa.fill",
                    title: dataStore.t("Dwujęzyczność (PL / EN)", "Bilingual Interface (PL / EN)"),
                    desc: dataStore.t("Pełna lokalizacja na język polski i angielski z natychmiastowym przełączaniem.", "Full English and Polish localization with instant real-time UI switching.")
                )
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
            .cornerRadius(10)
        }
    }
    
    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}
