import SwiftUI
import AppKit

// MARK: - Modern Home Dashboard View (Pulpit główny)

public struct HomeDashboardView: View {
    @ObservedObject var dataStore: DataStore
    var onOpenNote: (UUID) -> Void
    var onCreateNoteWithStyle: (PaperStyle, PaperColor) -> Void
    
    @State private var localSearchText: String = ""
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return dataStore.t("Dzień dobry!", "Good morning!") }
        if hour < 18 { return dataStore.t("Witaj po południu!", "Good afternoon!") }
        return dataStore.t("Dobry wieczór!", "Good evening!")
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = dataStore.language == .polish ? Locale(identifier: "pl_PL") : Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        return formatter.string(from: Date()).capitalized
    }
    
    private var filteredNotes: [Note] {
        if localSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return dataStore.notes.sorted(by: { $0.updatedAt > $1.updatedAt })
        } else {
            let q = localSearchText.lowercased()
            return dataStore.notes.filter {
                $0.title.lowercased().contains(q) ||
                $0.classicNoteText.lowercased().contains(q)
            }.sorted(by: { $0.updatedAt > $1.updatedAt })
        }
    }
    
    public var body: some View {
        ScrollView([.vertical], showsIndicators: true) {
            VStack(alignment: .leading, spacing: 28) {
                // Header Banner
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(formattedDate)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(greetingText)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        
                        Text(dataStore.t("Twoje studio notatek: pismo odręczne, auto-kształty, tabele i organizacja wiedzy.", "Your note studio: handwriting, auto-shapes, tables, and knowledge management."))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Quick stats
                    HStack(spacing: 16) {
                        statPill(title: dataStore.t("Notatek", "Notes"), value: "\(dataStore.notes.count)", icon: "doc.text.fill")
                        statPill(title: dataStore.t("Kategorii", "Categories"), value: "\(dataStore.categories.count)", icon: "folder.fill")
                        statPill(title: dataStore.t("Ulubionych", "Favorites"), value: "\(dataStore.notes.filter { $0.isFavorite }.count)", icon: "star.fill")
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 24)
                
                // Live Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(dataStore.t("Szukaj notatek po tytule lub treści...", "Search notes by title or content..."), text: $localSearchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 14))
                    if !localSearchText.isEmpty {
                        Button(action: { localSearchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.85))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, 32)
                
                // Section: Szybkie szablony
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "square.grid.2x2")
                            .foregroundColor(.accentColor)
                        Text(dataStore.t("Nowa notatka z szablonu", "New Note from Template"))
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            templateCard(
                                title: dataStore.t("Czysta kartka", "Blank Paper"),
                                subtitle: dataStore.t("Gładki biały papier", "Smooth white paper"),
                                icon: "doc",
                                style: .blank,
                                color: .white
                            )
                            templateCard(
                                title: dataStore.t("W kratkę", "Grid Paper"),
                                subtitle: dataStore.t("Standardowa kratka 5mm", "Standard 5mm grid"),
                                icon: "grid",
                                style: .grid,
                                color: .white
                            )
                            templateCard(
                                title: dataStore.t("W kropki", "Dot Grid"),
                                subtitle: dataStore.t("Siatka punktowa Bullet", "Dotted bullet grid"),
                                icon: "circle.grid.2x2",
                                style: .dots,
                                color: .white
                            )
                            templateCard(
                                title: dataStore.t("W linię", "Ruled Paper"),
                                subtitle: dataStore.t("Papier w szerokie linie", "Lined notebook paper"),
                                icon: "text.alignleft",
                                style: .lined,
                                color: .white
                            )
                            templateCard(
                                title: dataStore.t("Ciemna tablica", "Chalkboard"),
                                subtitle: dataStore.t("Ciemny łupek kredowy", "Dark slate blackboard"),
                                icon: "rectangle.fill",
                                style: .grid,
                                color: .darkSlate
                            )
                            templateCard(
                                title: dataStore.t("Żółty notatnik", "Legal Pad"),
                                subtitle: dataStore.t("Klasyczny żółty notatnik", "Classic yellow legal pad"),
                                icon: "doc.text.fill",
                                style: .lined,
                                color: .yellowLegal
                            )
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, 32)
                
                // Section: Wszystkie notatki (Karty)
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.accentColor)
                        Text("\(dataStore.t("Twoje notatki", "Your Notes")) (\(filteredNotes.count))")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Spacer()
                    }
                    
                    if filteredNotes.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary.opacity(0.6))
                            Text(dataStore.t("Brak notatek pasujących do wyszukiwania", "No notes matching your search"))
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240, maximum: 300), spacing: 16)], spacing: 16) {
                            ForEach(filteredNotes) { note in
                                noteCard(note: note)
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .background(Color(NSColor.underPageBackgroundColor))
    }
    
    // MARK: - Template Card
    
    @ViewBuilder
    private func templateCard(title: String, subtitle: String, icon: String, style: PaperStyle, color: PaperColor) -> some View {
        Button(action: {
            onCreateNoteWithStyle(style, color)
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(14)
            .frame(width: 170, height: 110)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Note Card
    
    @ViewBuilder
    private func categoryPill(for categoryId: UUID?) -> some View {
        if let catId = categoryId, let cat = dataStore.categories.first(where: { $0.id == catId }) {
            let color = Color(NSColor(hex: cat.colorHex) ?? .blue)
            HStack(spacing: 4) {
                Image(systemName: cat.icon)
                    .font(.system(size: 9))
                Text(cat.name)
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
        }
    }
    
    private func noteCard(note: Note) -> some View {
        Button(action: {
            onOpenNote(note.id)
        }) {
            VStack(alignment: .leading, spacing: 10) {
                // Header: Category Pill & Star
                HStack {
                    categoryPill(for: note.categoryId)
                    
                    Spacer()
                    
                    Button(action: {
                        dataStore.toggleFavorite(for: note.id)
                    }) {
                        Image(systemName: note.isFavorite ? "star.fill" : "star")
                            .font(.system(size: 13))
                            .foregroundColor(note.isFavorite ? .yellow : .secondary.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
                
                // Title
                Text(note.title.isEmpty ? dataStore.t("Notatka bez tytułu", "Untitled Note") : note.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .frame(height: 38, alignment: .topLeading)
                
                // Paper Preview Strip
                HStack(spacing: 6) {
                    Circle()
                        .fill(note.paperColor == .white ? Color.gray.opacity(0.3) : Color.black)
                        .frame(width: 10, height: 10)
                    Text("\(note.paperStyle.localizedName(language: dataStore.language)) • \(pageCountString(count: note.pages.count))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Footer: Date
                Text("\(dataStore.t("Edytowano:", "Edited:")) \(formattedTime(note.updatedAt))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private func pageCountString(count: Int) -> String {
        if dataStore.language == .polish {
            return "\(count) \(count == 1 ? "strona" : (count < 5 ? "strony" : "stron"))"
        } else {
            return "\(count) \(count == 1 ? "page" : "pages")"
        }
    }
    
    private func statPill(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
        .cornerRadius(8)
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = dataStore.language == .polish ? Locale(identifier: "pl_PL") : Locale(identifier: "en_US")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
