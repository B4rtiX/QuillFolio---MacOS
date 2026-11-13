import SwiftUI
import AppKit

public struct MainView: View {
    @StateObject private var dataStore = DataStore()
    @State private var isLoading: Bool = true
    
    public var body: some View {
        ZStack {
            NavigationSplitView {
                SidebarView(dataStore: dataStore)
                    .frame(minWidth: 240, idealWidth: 280, maxWidth: 350)
            } detail: {
                VStack(spacing: 0) {
                    // Top Global Toolbar
                    ToolbarView(
                        dataStore: dataStore,
                        note: dataStore.selectedNote,
                        onExportPDF: {
                            if let note = dataStore.selectedNote {
                                ExportHelper.exportNoteToPDF(note: note)
                            }
                        },
                        onExportPNG: {
                            if let note = dataStore.selectedNote {
                                ExportHelper.exportPageToPNG(note: note, pageIndex: note.currentPageIndex)
                            }
                        }
                    )
                    
                    // Detail Content (Settings, Note Canvas Area or Home Dashboard)
                    if dataStore.showSettings {
                        SettingsView(dataStore: dataStore)
                    } else if !dataStore.showHomeDashboard, let selectedNoteBinding = selectedNoteBinding {
                        NoteCanvasAreaView(dataStore: dataStore, note: selectedNoteBinding)
                    } else {
                        HomeDashboardView(
                            dataStore: dataStore,
                            onOpenNote: { noteId in
                                dataStore.selectedNoteId = noteId
                                dataStore.showHomeDashboard = false
                                dataStore.showSettings = false
                            },
                            onCreateNoteWithStyle: { style, color in
                                dataStore.createNote()
                                if let id = dataStore.selectedNoteId, let idx = dataStore.notes.firstIndex(where: { $0.id == id }) {
                                    dataStore.notes[idx].paperStyle = style
                                    dataStore.notes[idx].paperColor = color
                                    dataStore.saveToDisk()
                                }
                                dataStore.showHomeDashboard = false
                                dataStore.showSettings = false
                            }
                        )
                    }
                }
            }
            .frame(minWidth: 950, minHeight: 650)
            
            // Animated Splash Screen on launch
            if isLoading && dataStore.showSplashScreenOnLaunch {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .onAppear {
            dataStore.applyAppTheme()
            if dataStore.showSplashScreenOnLaunch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        isLoading = false
                    }
                }
            } else {
                isLoading = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            dataStore.showSettings = true
            dataStore.showHomeDashboard = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .undoAction)) { _ in
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
            dataStore.undo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .redoAction)) { _ in
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
            dataStore.redo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomInAction)) { _ in
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
            dataStore.zoomIn()
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomOutAction)) { _ in
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
            dataStore.zoomOut()
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomResetAction)) { _ in
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
            dataStore.zoomReset()
        }
        .onReceive(NotificationCenter.default.publisher(for: .createNewNote)) { _ in
            dataStore.createNote()
            dataStore.showHomeDashboard = false
            dataStore.showSettings = false
        }
    }
    
    private var selectedNoteBinding: Binding<Note>? {
        guard let id = dataStore.selectedNoteId,
              let index = dataStore.notes.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return $dataStore.notes[index]
    }
}

// MARK: - Empty State View

public struct EmptyStateView: View {
    var dataStore: DataStore? = nil
    var onCreateNote: () -> Void
    
    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "pencil.and.outline")
                .font(.system(size: 54))
                .foregroundColor(.accentColor.opacity(0.8))
            
            Text(dataStore?.t("Wybierz lub stwórz notatkę", "Select or create a note") ?? "Wybierz lub stwórz notatkę")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(dataStore?.t("Twórz kategorie, rysuj odręcznie z obsługą nacisku pióra,\nkorzystaj z auto-korekty figur oraz klasycznych pól tekstowych.", "Create categories, draw with stylus pressure dynamics,\nuse auto-shapes and flexible text boxes.") ?? "Twórz kategorie, rysuj odręcznie z obsługą nacisku pióra,\nkorzystaj z auto-korekty figur oraz klasycznych pól tekstowych.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: onCreateNote) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(dataStore?.t("Utwórz nową notatkę", "Create new note") ?? "Utwórz nową notatkę")
                }
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.underPageBackgroundColor))
    }
}
