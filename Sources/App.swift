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

import SwiftUI
import AppKit

@main
struct QuillfolioApp: App {
    
    init() {
        // Customize appearance
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .appSettings) {
                Button("Ustawienia... / Settings...") {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .newItem) {
                Button("Nowa notatka / New Note") {
                    NotificationCenter.default.post(name: .createNewNote, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Cofnij / Undo") {
                    NotificationCenter.default.post(name: .undoAction, object: nil)
                }
                .keyboardShortcut("z", modifiers: .command)
                
                Button("Cofnij / Undo (Ctrl+Z)") {
                    NotificationCenter.default.post(name: .undoAction, object: nil)
                }
                .keyboardShortcut("z", modifiers: .control)
                
                Button("Ponów / Redo") {
                    NotificationCenter.default.post(name: .redoAction, object: nil)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                
                Button("Ponów / Redo (Ctrl+Y)") {
                    NotificationCenter.default.post(name: .redoAction, object: nil)
                }
                .keyboardShortcut("y", modifiers: .control)
            }
            CommandMenu("Widok / View") {
                Button("Przybliż / Zoom In") {
                    NotificationCenter.default.post(name: .zoomInAction, object: nil)
                }
                .keyboardShortcut("=", modifiers: .command)
                
                Button("Przybliż / Zoom In (+)") {
                    NotificationCenter.default.post(name: .zoomInAction, object: nil)
                }
                .keyboardShortcut("+", modifiers: .command)
                
                Button("Oddal / Zoom Out") {
                    NotificationCenter.default.post(name: .zoomOutAction, object: nil)
                }
                .keyboardShortcut("-", modifiers: .command)
                
                Button("Rzeczywisty rozmiar (100%) / Actual Size") {
                    NotificationCenter.default.post(name: .zoomResetAction, object: nil)
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let createNewNote = Notification.Name("QuillfolioCreateNewNote")
    static let undoAction = Notification.Name("QuillfolioUndoAction")
    static let redoAction = Notification.Name("QuillfolioRedoAction")
    static let zoomInAction = Notification.Name("QuillfolioZoomInAction")
    static let zoomOutAction = Notification.Name("QuillfolioZoomOutAction")
    static let zoomResetAction = Notification.Name("QuillfolioZoomResetAction")
    static let openSettings = Notification.Name("QuillfolioOpenSettings")
}
