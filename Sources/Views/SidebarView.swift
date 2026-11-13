import SwiftUI
import AppKit

public struct SidebarView: View {
    @ObservedObject var dataStore: DataStore
    
    // Add Category Sheet State
    @State private var isShowingAddCategorySheet = false
    @State private var newCategoryName = ""
    @State private var newCategoryIcon = "folder.fill"
    @State private var newCategoryColor = "#0A84FF"
    
    // Add Subcategory Sheet State
    @State private var isShowingAddSubcategorySheet = false
    @State private var subcategoryParentId: UUID? = nil
    @State private var newSubcategoryName = ""
    @State private var newSubcategoryIcon = "folder"
    @State private var newSubcategoryColor = "#30B0C7"
    
    // Rename Dialog States
    @State private var renamingNoteId: UUID? = nil
    @State private var renameNoteText = ""
    @State private var isShowingRenameNoteSheet = false
    
    @State private var renamingCategoryId: UUID? = nil
    @State private var renameCategoryText = ""
    @State private var isShowingRenameCategorySheet = false
    
    @State private var renamingSubcatIds: (UUID, UUID)? = nil // (category, subcategory)
    @State private var renameSubcategoryText = ""
    @State private var isShowingRenameSubcategorySheet = false
    
    // Expanded categories tracking
    @State private var expandedCategoryIds: Set<UUID> = []
    @State private var expandedSubcategoryIds: Set<UUID> = []
    
    // Extensive student & academic icons
    private let availableIcons = [
        "graduationcap.fill", "books.vertical.fill", "atom", "function",
        "chart.bar.xaxis", "chart.line.uptrend.xyaxis", "brain.head.profile", "laptopcomputer",
        "flask.fill", "building.columns.fill", "pencil.and.ruler.fill", "dna",
        "stethoscope", "globe.europe.africa.fill", "character.book.closed.fill", "book.closed.fill",
        "lightbulb.fill", "doc.text.fill", "folder.fill", "briefcase.fill",
        "hammer.fill", "heart.fill", "star.fill", "tag.fill"
    ]
    
    private let availableColors = [
        "#0A84FF", "#30B0C7", "#10B981", "#34C759",
        "#F59E0B", "#FF9500", "#FF2D55", "#EC4899",
        "#AF52DE", "#5856D6", "#64748B", "#1E293B"
    ]
    
    public var body: some View {
        List {
            // MARK: - Smart Filters
            Section(dataStore.t("Szybki dostęp", "Quick Access")) {
                Button(action: {
                    dataStore.showSettings = false
                    dataStore.showHomeDashboard = false
                    dataStore.selectedCategoryId = nil
                    dataStore.selectedSubcategoryId = nil
                    dataStore.filterFavoritesOnly = false
                }) {
                    HStack {
                        Image(systemName: "tray.full.fill")
                            .foregroundColor(.accentColor)
                        Text(dataStore.t("Wszystkie notatki", "All Notes"))
                            .fontWeight(!dataStore.showSettings && dataStore.selectedCategoryId == nil && !dataStore.filterFavoritesOnly ? .semibold : .regular)
                        Spacer()
                        Text("\(dataStore.notes.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    dataStore.showSettings = false
                    dataStore.showHomeDashboard = false
                    dataStore.filterFavoritesOnly = true
                    dataStore.selectedCategoryId = nil
                    dataStore.selectedSubcategoryId = nil
                }) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(dataStore.t("Ulubione", "Favorites"))
                            .fontWeight(!dataStore.showSettings && dataStore.filterFavoritesOnly ? .semibold : .regular)
                        Spacer()
                        Text("\(dataStore.notes.filter { $0.isFavorite }.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                // Settings Row
                Button(action: {
                    dataStore.showSettings = true
                    dataStore.showHomeDashboard = false
                }) {
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(dataStore.showSettings ? .accentColor : .secondary)
                        Text(dataStore.t("Ustawienia", "Settings"))
                            .fontWeight(dataStore.showSettings ? .semibold : .regular)
                            .foregroundColor(dataStore.showSettings ? .accentColor : .primary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            
            // MARK: - Hierarchical Tree: Categories -> Subcategories -> Notes
            Section {
                ForEach(dataStore.categories) { category in
                    let isCatExpanded = Binding(
                        get: { expandedCategoryIds.contains(category.id) },
                        set: { if $0 { expandedCategoryIds.insert(category.id) } else { expandedCategoryIds.remove(category.id) } }
                    )
                    
                    DisclosureGroup(isExpanded: isCatExpanded) {
                        // 1. Notes directly inside this category (without subcategory)
                        let directNotes = dataStore.notes.filter { $0.categoryId == category.id && $0.subcategoryId == nil }
                        ForEach(directNotes) { note in
                            TreeNoteRow(
                                dataStore: dataStore,
                                note: note,
                                isSelected: dataStore.selectedNoteId == note.id && !dataStore.showSettings,
                                onSelect: {
                                    dataStore.showSettings = false
                                    dataStore.showHomeDashboard = false
                                    dataStore.selectedNoteId = note.id
                                },
                                onRename: {
                                    renamingNoteId = note.id
                                    renameNoteText = note.title
                                    isShowingRenameNoteSheet = true
                                },
                                onMove: { catId, subId in
                                    dataStore.moveNote(noteId: note.id, toCategoryId: catId, toSubcategoryId: subId)
                                },
                                onDuplicate: { dataStore.duplicateNote(id: note.id) },
                                onToggleFavorite: { dataStore.toggleFavorite(for: note.id) },
                                onDelete: { dataStore.deleteNote(id: note.id) },
                                categories: dataStore.categories
                            )
                            .padding(.leading, 8)
                        }
                        
                        // 2. Subcategories with their notes nested underneath
                        ForEach(category.subcategories) { subcat in
                            let isSubExpanded = Binding(
                                get: { expandedSubcategoryIds.contains(subcat.id) },
                                set: { if $0 { expandedSubcategoryIds.insert(subcat.id) } else { expandedSubcategoryIds.remove(subcat.id) } }
                            )
                            
                            DisclosureGroup(isExpanded: isSubExpanded) {
                                let subcatNotes = dataStore.notes.filter { $0.subcategoryId == subcat.id }
                                ForEach(subcatNotes) { note in
                                    TreeNoteRow(
                                        dataStore: dataStore,
                                        note: note,
                                        isSelected: dataStore.selectedNoteId == note.id && !dataStore.showSettings,
                                        onSelect: {
                                            dataStore.showSettings = false
                                            dataStore.showHomeDashboard = false
                                            dataStore.selectedNoteId = note.id
                                        },
                                        onRename: {
                                            renamingNoteId = note.id
                                            renameNoteText = note.title
                                            isShowingRenameNoteSheet = true
                                        },
                                        onMove: { catId, subId in
                                            dataStore.moveNote(noteId: note.id, toCategoryId: catId, toSubcategoryId: subId)
                                        },
                                        onDuplicate: { dataStore.duplicateNote(id: note.id) },
                                        onToggleFavorite: { dataStore.toggleFavorite(for: note.id) },
                                        onDelete: { dataStore.deleteNote(id: note.id) },
                                        categories: dataStore.categories
                                    )
                                    .padding(.leading, 12)
                                }
                                
                                Button(action: {
                                    dataStore.showSettings = false
                                    dataStore.showHomeDashboard = false
                                    dataStore.selectedCategoryId = category.id
                                    dataStore.selectedSubcategoryId = subcat.id
                                    dataStore.createNote(title: "\(dataStore.t("Notatka", "Note")) - \(subcat.name)")
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.caption2)
                                        Text(dataStore.t("Nowa notatka...", "New Note..."))
                                            .font(.caption)
                                    }
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 12)
                                    .padding(.vertical, 2)
                                }
                                .buttonStyle(.plain)
                            } label: {
                                TreeSubcategoryHeader(
                                    dataStore: dataStore,
                                    subcat: subcat,
                                    noteCount: dataStore.notes.filter { $0.subcategoryId == subcat.id }.count,
                                    isSelected: dataStore.selectedSubcategoryId == subcat.id && !dataStore.showSettings,
                                    onSelect: {
                                        dataStore.showSettings = false
                                        dataStore.selectedCategoryId = category.id
                                        dataStore.selectedSubcategoryId = subcat.id
                                        dataStore.filterFavoritesOnly = false
                                        if !expandedSubcategoryIds.contains(subcat.id) {
                                            expandedSubcategoryIds.insert(subcat.id)
                                        }
                                    },
                                    onRename: {
                                        renamingSubcatIds = (category.id, subcat.id)
                                        renameSubcategoryText = subcat.name
                                        isShowingRenameSubcategorySheet = true
                                    },
                                    onAddNote: {
                                        dataStore.showSettings = false
                                        dataStore.showHomeDashboard = false
                                        dataStore.selectedCategoryId = category.id
                                        dataStore.selectedSubcategoryId = subcat.id
                                        dataStore.createNote(title: "\(dataStore.t("Notatka", "Note")) - \(subcat.name)")
                                    },
                                    onDelete: {
                                        dataStore.deleteSubcategory(categoryId: category.id, subcategoryId: subcat.id)
                                    }
                                )
                            }
                        }
                        
                        // Add subcategory or note shortcut
                        HStack(spacing: 8) {
                            Button(action: {
                                subcategoryParentId = category.id
                                newSubcategoryName = ""
                                isShowingAddSubcategorySheet = true
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "folder.badge.plus")
                                        .font(.caption2)
                                    Text(dataStore.t("Podkategoria", "Subcategory"))
                                        .font(.caption)
                                }
                                .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                dataStore.showSettings = false
                                dataStore.showHomeDashboard = false
                                dataStore.selectedCategoryId = category.id
                                dataStore.selectedSubcategoryId = nil
                                dataStore.createNote(title: "\(dataStore.t("Notatka", "Note")) - \(category.name)")
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "plus")
                                        .font(.caption2)
                                    Text(dataStore.t("Notatka", "Note"))
                                        .font(.caption)
                                }
                                .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.leading, 8)
                        .padding(.vertical, 3)
                    } label: {
                        TreeCategoryHeader(
                            dataStore: dataStore,
                            category: category,
                            noteCount: countTotalCategoryNotes(categoryId: category.id),
                            isSelected: dataStore.selectedCategoryId == category.id && dataStore.selectedSubcategoryId == nil && !dataStore.showSettings,
                            onSelect: {
                                dataStore.showSettings = false
                                dataStore.selectedCategoryId = category.id
                                dataStore.selectedSubcategoryId = nil
                                dataStore.filterFavoritesOnly = false
                                if !expandedCategoryIds.contains(category.id) {
                                    expandedCategoryIds.insert(category.id)
                                }
                            },
                            onRename: {
                                renamingCategoryId = category.id
                                renameCategoryText = category.name
                                isShowingRenameCategorySheet = true
                            },
                            onAddSubcategory: {
                                subcategoryParentId = category.id
                                newSubcategoryName = ""
                                isShowingAddSubcategorySheet = true
                            },
                            onAddNote: {
                                dataStore.showSettings = false
                                dataStore.showHomeDashboard = false
                                dataStore.selectedCategoryId = category.id
                                dataStore.selectedSubcategoryId = nil
                                dataStore.createNote(title: "\(dataStore.t("Notatka", "Note")) - \(category.name)")
                            },
                            onDelete: {
                                dataStore.deleteCategory(id: category.id)
                            }
                        )
                    }
                }
                
                // Notes without category (if any)
                let uncategorized = dataStore.notes.filter { $0.categoryId == nil }
                if !uncategorized.isEmpty {
                    Section(dataStore.t("Inne (bez kategorii)", "Other (Uncategorized)")) {
                        ForEach(uncategorized) { note in
                            TreeNoteRow(
                                dataStore: dataStore,
                                note: note,
                                isSelected: dataStore.selectedNoteId == note.id && !dataStore.showSettings,
                                onSelect: {
                                    dataStore.showSettings = false
                                    dataStore.showHomeDashboard = false
                                    dataStore.selectedNoteId = note.id
                                },
                                onRename: {
                                    renamingNoteId = note.id
                                    renameNoteText = note.title
                                    isShowingRenameNoteSheet = true
                                },
                                onMove: { catId, subId in
                                    dataStore.moveNote(noteId: note.id, toCategoryId: catId, toSubcategoryId: subId)
                                },
                                onDuplicate: { dataStore.duplicateNote(id: note.id) },
                                onToggleFavorite: { dataStore.toggleFavorite(for: note.id) },
                                onDelete: { dataStore.deleteNote(id: note.id) },
                                categories: dataStore.categories
                            )
                        }
                    }
                }
            } header: {
                HStack {
                    Text(dataStore.t("Kategorie i Notatki", "Categories & Notes"))
                    Spacer()
                    Button(action: {
                        newCategoryName = ""
                        isShowingAddCategorySheet = true
                    }) {
                        Image(systemName: "plus")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help(dataStore.t("Dodaj nową kategorię", "Add new category"))
                }
            }
        }
        .onAppear {
            // Expand all categories by default on first load
            for cat in dataStore.categories {
                expandedCategoryIds.insert(cat.id)
                for sub in cat.subcategories {
                    expandedSubcategoryIds.insert(sub.id)
                }
            }
        }
        // MARK: - Add Category Sheet
        .sheet(isPresented: $isShowingAddCategorySheet) {
            VStack(alignment: .leading, spacing: 14) {
                Text(dataStore.t("Nowa kategoria", "New Category"))
                    .font(.headline)
                
                TextField(dataStore.t("Nazwa kategorii (np. Analiza Matematyczna)", "Category name (e.g. Calculus)"), text: $newCategoryName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text(dataStore.t("Wybierz ikonę (symbole akademickie i ogólne):", "Choose an icon (academic & general symbols):"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 36))], spacing: 8) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button(action: { newCategoryIcon = icon }) {
                                Image(systemName: icon)
                                    .font(.system(size: 16))
                                    .frame(width: 36, height: 36)
                                    .background(newCategoryIcon == icon ? Color.accentColor.opacity(0.2) : Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(newCategoryIcon == icon ? Color.accentColor : Color.clear, lineWidth: 1.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(2)
                }
                .frame(height: 140)
                
                Text(dataStore.t("Kolor kategorii:", "Category color:"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(availableColors, id: \.self) { hex in
                        Circle()
                            .fill(Color(NSColor(hex: hex) ?? .blue))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle().stroke(Color.primary, lineWidth: newCategoryColor == hex ? 2 : 0)
                            )
                            .onTapGesture { newCategoryColor = hex }
                    }
                }
                
                Divider()
                
                HStack {
                    Button(dataStore.t("Anuluj", "Cancel")) {
                        isShowingAddCategorySheet = false
                    }
                    Spacer()
                    Button(dataStore.t("Utwórz kategorię", "Create Category")) {
                        if !newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty {
                            dataStore.addCategory(
                                name: newCategoryName,
                                icon: newCategoryIcon,
                                colorHex: newCategoryColor
                            )
                        }
                        isShowingAddCategorySheet = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(18)
            .frame(width: 380, height: 390)
        }
        // MARK: - Add Subcategory Sheet
        .sheet(isPresented: $isShowingAddSubcategorySheet) {
            VStack(alignment: .leading, spacing: 14) {
                Text(dataStore.t("Nowa podkategoria", "New Subcategory"))
                    .font(.headline)
                
                TextField(dataStore.t("Nazwa podkategorii (np. Całki i Szeregi)", "Subcategory name (e.g. Integrals & Series)"), text: $newSubcategoryName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text(dataStore.t("Kolor podkategorii:", "Subcategory color:"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(availableColors, id: \.self) { hex in
                        Circle()
                            .fill(Color(NSColor(hex: hex) ?? .blue))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle().stroke(Color.primary, lineWidth: newSubcategoryColor == hex ? 2 : 0)
                            )
                            .onTapGesture { newSubcategoryColor = hex }
                    }
                }
                
                Divider()
                
                HStack {
                    Button(dataStore.t("Anuluj", "Cancel")) {
                        isShowingAddSubcategorySheet = false
                    }
                    Spacer()
                    Button(dataStore.t("Utwórz podkategorię", "Create Subcategory")) {
                        if let parentId = subcategoryParentId,
                           !newSubcategoryName.trimmingCharacters(in: .whitespaces).isEmpty {
                            dataStore.addSubcategory(
                                to: parentId,
                                name: newSubcategoryName,
                                colorHex: newSubcategoryColor
                            )
                        }
                        isShowingAddSubcategorySheet = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newSubcategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(18)
            .frame(width: 360, height: 220)
        }
        // MARK: - Rename Note Sheet
        .sheet(isPresented: $isShowingRenameNoteSheet) {
            VStack(alignment: .leading, spacing: 14) {
                Text(dataStore.t("Zmień nazwę notatki", "Rename Note"))
                    .font(.headline)
                
                TextField(dataStore.t("Nowa nazwa", "New name"), text: $renameNoteText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                HStack {
                    Button(dataStore.t("Anuluj", "Cancel")) { isShowingRenameNoteSheet = false }
                    Spacer()
                    Button(dataStore.t("Zapisz", "Save")) {
                        if let noteId = renamingNoteId {
                            dataStore.renameNote(id: noteId, newTitle: renameNoteText)
                        }
                        isShowingRenameNoteSheet = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(renameNoteText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(18)
            .frame(width: 320)
        }
        // MARK: - Rename Category Sheet
        .sheet(isPresented: $isShowingRenameCategorySheet) {
            VStack(alignment: .leading, spacing: 14) {
                Text(dataStore.t("Zmień nazwę kategorii", "Rename Category"))
                    .font(.headline)
                
                TextField(dataStore.t("Nowa nazwa", "New name"), text: $renameCategoryText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                HStack {
                    Button(dataStore.t("Anuluj", "Cancel")) { isShowingRenameCategorySheet = false }
                    Spacer()
                    Button(dataStore.t("Zapisz", "Save")) {
                        if let catId = renamingCategoryId {
                            dataStore.renameCategory(id: catId, newName: renameCategoryText)
                        }
                        isShowingRenameCategorySheet = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(renameCategoryText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(18)
            .frame(width: 320)
        }
        // MARK: - Rename Subcategory Sheet
        .sheet(isPresented: $isShowingRenameSubcategorySheet) {
            VStack(alignment: .leading, spacing: 14) {
                Text(dataStore.t("Zmień nazwę podkategorii", "Rename Subcategory"))
                    .font(.headline)
                
                TextField(dataStore.t("Nowa nazwa", "New name"), text: $renameSubcategoryText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                HStack {
                    Button(dataStore.t("Anuluj", "Cancel")) { isShowingRenameSubcategorySheet = false }
                    Spacer()
                    Button(dataStore.t("Zapisz", "Save")) {
                        if let (catId, subId) = renamingSubcatIds {
                            dataStore.renameSubcategory(categoryId: catId, subcategoryId: subId, newName: renameSubcategoryText)
                        }
                        isShowingRenameSubcategorySheet = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(renameSubcategoryText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(18)
            .frame(width: 320)
        }
    }
    
    private func countTotalCategoryNotes(categoryId: UUID) -> Int {
        dataStore.notes.filter { $0.categoryId == categoryId }.count
    }
}

// MARK: - Tree View Row Components

private struct TreeCategoryHeader: View {
    let dataStore: DataStore
    let category: Category
    let noteCount: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onAddSubcategory: () -> Void
    let onAddNote: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: category.icon)
                .foregroundColor(Color(NSColor(hex: category.colorHex) ?? .blue))
            Text(category.name)
                .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
            Spacer()
            if noteCount > 0 {
                Text("\(noteCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button(dataStore.t("Zmień nazwę kategorii...", "Rename Category..."), action: onRename)
            Button(dataStore.t("Dodaj podkategorię...", "Add Subcategory..."), action: onAddSubcategory)
            Button(dataStore.t("Nowa notatka w tej kategorii...", "New Note in this Category..."), action: onAddNote)
            Divider()
            Button(dataStore.t("Usuń kategorię", "Delete Category"), role: .destructive, action: onDelete)
        }
    }
}

private struct TreeSubcategoryHeader: View {
    let dataStore: DataStore
    let subcat: Subcategory
    let noteCount: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onAddNote: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: subcat.icon)
                .font(.system(size: 11))
                .foregroundColor(Color(NSColor(hex: subcat.colorHex) ?? .cyan))
            Text(subcat.name)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
            Spacer()
            if noteCount > 0 {
                Text("\(noteCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .padding(.leading, 4)
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button(dataStore.t("Zmień nazwę podkategorii...", "Rename Subcategory..."), action: onRename)
            Button(dataStore.t("Nowa notatka w tej podkategorii...", "New Note in this Subcategory..."), action: onAddNote)
            Divider()
            Button(dataStore.t("Usuń podkategorię", "Delete Subcategory"), role: .destructive, action: onDelete)
        }
    }
}

private struct TreeNoteRow: View {
    let dataStore: DataStore
    let note: Note
    let isSelected: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onMove: (UUID?, UUID?) -> Void
    let onDuplicate: () -> Void
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void
    let categories: [Category]
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: note.paperStyle.iconName)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            Text(note.title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
            
            Spacer()
            
            if note.isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.yellow)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button(dataStore.t("Zmień nazwę...", "Rename..."), action: onRename)
            
            // Submenu: Przenieś do innej kategorii
            Menu(dataStore.t("Przenieś do kategorii...", "Move to Category...")) {
                Button(dataStore.t("Bez kategorii", "Uncategorized")) {
                    onMove(nil, nil)
                }
                Divider()
                ForEach(categories) { cat in
                    Button(cat.name) {
                        onMove(cat.id, nil)
                    }
                    ForEach(cat.subcategories) { sub in
                        Button("  ↳ \(sub.name)") {
                            onMove(cat.id, sub.id)
                        }
                    }
                }
            }
            
            Button(dataStore.t("Duplikuj notatkę", "Duplicate Note"), action: onDuplicate)
            Button(note.isFavorite ? dataStore.t("Usuń z ulubionych", "Remove from Favorites") : dataStore.t("Dodaj do ulubionych", "Add to Favorites"), action: onToggleFavorite)
            Divider()
            Button(dataStore.t("Usuń notatkę", "Delete Note"), role: .destructive, action: onDelete)
        }
    }
}
