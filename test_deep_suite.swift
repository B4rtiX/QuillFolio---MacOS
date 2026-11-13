import Foundation
import CoreGraphics
import Cocoa

func pt(_ x: CGFloat, _ y: CGFloat, pressure: Double = 0.5) -> StrokePoint {
    StrokePoint(x: Double(x), y: Double(y), pressure: pressure, timestamp: Date().timeIntervalSince1970)
}

@main
struct DeepTestSuite {
    static var testsPassed = 0
    static var testsFailed = 0

    static func assertTrue(_ condition: Bool, _ message: String) {
        if condition {
            testsPassed += 1
            print("  ✅ PASS: \(message)")
        } else {
            testsFailed += 1
            print("  ❌ FAIL: \(message)")
        }
    }

    static func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String) {
        if a == b {
            testsPassed += 1
            print("  ✅ PASS: \(message)")
        } else {
            testsFailed += 1
            print("  ❌ FAIL: \(message) - Oczekiwano: \(b), otrzymano: \(a)")
        }
    }

    static func main() {
        print("=================================================================")
        print("🧪 ROZPOCZĘCIE KOMPLEKSOWYCH TESTÓW JEDNOSTKOWYCH NOTATNIK STUDIO")
        print("=================================================================")

        // MARK: - 1. TESTY ROZPOZNAWANIA KSZTAŁTÓW
        print("\n--- 1. MODUŁ SHAPE RECOGNIZER ---")
        let recognizer = ShapeRecognizer.shared

        // Test 1.1: Linia
        var linePts = [StrokePoint]()
        for i in 0...20 { linePts.append(pt(10 + CGFloat(i) * 10, 50)) }
        let lineShape = recognizer.recognizeShape(from: linePts)
        assertTrue(lineShape?.kind == .line, "Rozpoznawanie prostej linii")

        // Test 1.2: Strzałka pojedyncza
        var arrowPts = [StrokePoint]()
        for i in 0...30 { arrowPts.append(pt(10 + CGFloat(i) * 5, 100)) }
        arrowPts.append(pt(140, 90))
        arrowPts.append(pt(160, 100))
        arrowPts.append(pt(140, 110))
        let arrowShape = recognizer.recognizeShape(from: arrowPts)
        assertTrue(arrowShape?.kind == .arrow && arrowShape?.hasArrowEnd == true, "Rozpoznawanie pojedynczej strzałki")

        // Test 1.3: Krótka strzałka
        var shortArrowPts = [StrokePoint]()
        for i in 0...10 { shortArrowPts.append(pt(100 + CGFloat(i) * 3, 200)) }
        shortArrowPts.append(pt(122, 195))
        shortArrowPts.append(pt(130, 200))
        shortArrowPts.append(pt(122, 205))
        let shortArrowShape = recognizer.recognizeShape(from: shortArrowPts)
        assertTrue(shortArrowShape?.kind == .arrow, "Rozpoznawanie krótkiej strzałki (30 pt)")

        // Test 1.4: Strzałka dwustronna
        var doubleArrowPts = [StrokePoint]()
        doubleArrowPts.append(pt(40, 90))
        doubleArrowPts.append(pt(20, 100))
        doubleArrowPts.append(pt(40, 110))
        for i in 0...30 { doubleArrowPts.append(pt(20 + CGFloat(i) * 6, 100)) }
        doubleArrowPts.append(pt(180, 90))
        doubleArrowPts.append(pt(200, 100))
        doubleArrowPts.append(pt(180, 110))
        let doubleArrowShape = recognizer.recognizeShape(from: doubleArrowPts)
        assertTrue(doubleArrowShape?.kind == .doubleArrow, "Rozpoznawanie strzałki dwustronnej")

        // Test 1.5: Okrąg
        var circlePts = [StrokePoint]()
        let cCenter = CGPoint(x: 200, y: 200)
        let cRadius: CGFloat = 80.0
        for i in 0...60 {
            let angle = CGFloat(i) * (2.0 * .pi / 60.0)
            let jitter = (i % 2 == 0) ? CGFloat(1.5) : CGFloat(-1.5)
            circlePts.append(pt(cCenter.x + (cRadius + jitter) * cos(angle), cCenter.y + (cRadius + jitter) * sin(angle)))
        }
        circlePts.append(circlePts[0])
        let circleShape = recognizer.recognizeShape(from: circlePts)
        assertTrue(circleShape?.kind == .circle, "Rozpoznawanie okręgu z odręcznym szumem")

        // Test 1.6: Elipsa
        var ellipsePts = [StrokePoint]()
        let eRadiusX: CGFloat = 110.0
        let eRadiusY: CGFloat = 55.0
        for i in 0...60 {
            let angle = CGFloat(i) * (2.0 * .pi / 60.0)
            let jitter = (i % 2 == 0) ? CGFloat(1.0) : CGFloat(-1.0)
            ellipsePts.append(pt(cCenter.x + (eRadiusX + jitter) * cos(angle), cCenter.y + (eRadiusY + jitter) * sin(angle)))
        }
        ellipsePts.append(ellipsePts[0])
        let ellipseShape = recognizer.recognizeShape(from: ellipsePts)
        assertTrue(ellipseShape?.kind == .ellipse, "Rozpoznawanie elipsy o stosunku 2:1")

        // Test 1.7: Kwadrat
        var sqPts = [StrokePoint]()
        for x in stride(from: 50.0, through: 150.0, by: 10.0) { sqPts.append(pt(x, 50)) }
        for y in stride(from: 50.0, through: 150.0, by: 10.0) { sqPts.append(pt(150, y)) }
        for x in stride(from: 150.0, through: 50.0, by: -10.0) { sqPts.append(pt(x, 150)) }
        for y in stride(from: 150.0, through: 50.0, by: -10.0) { sqPts.append(pt(50, y)) }
        let sqShape = recognizer.recognizeShape(from: sqPts)
        assertTrue(sqShape?.kind == .square, "Rozpoznawanie kwadratu")

        // Test 1.8: Prostokąt
        var rectPts = [StrokePoint]()
        for x in stride(from: 50.0, through: 250.0, by: 10.0) { rectPts.append(pt(x, 50)) }
        for y in stride(from: 50.0, through: 120.0, by: 10.0) { rectPts.append(pt(250, y)) }
        for x in stride(from: 250.0, through: 50.0, by: -10.0) { rectPts.append(pt(x, 120)) }
        for y in stride(from: 120.0, through: 50.0, by: -10.0) { rectPts.append(pt(50, y)) }
        let rectShape = recognizer.recognizeShape(from: rectPts)
        assertTrue(rectShape?.kind == .rectangle, "Rozpoznawanie prostokąta")

        // Test 1.9: Trójkąt
        var triPts = [StrokePoint]()
        for i in 0...20 { triPts.append(pt(100 + CGFloat(i) * 5, 50 + CGFloat(i) * 5)) }
        for i in 0...20 { triPts.append(pt(200 - CGFloat(i) * 5, 150)) }
        for i in 0...20 { triPts.append(pt(100, 150 - CGFloat(i) * 5)) }
        let triShape = recognizer.recognizeShape(from: triPts)
        assertTrue(triShape?.kind == .triangle, "Rozpoznawanie trójkąta")

        // Test 1.10: Równoległobok
        var parPts = [StrokePoint]()
        for x in stride(from: 80.0, through: 220.0, by: 10.0) { parPts.append(pt(x, 50)) }
        for i in 0...10 { parPts.append(pt(220.0 - CGFloat(i) * 4.0, 50.0 + CGFloat(i) * 8.0)) }
        for x in stride(from: 180.0, through: 40.0, by: -10.0) { parPts.append(pt(x, 130)) }
        for i in 0...10 { parPts.append(pt(40.0 + CGFloat(i) * 4.0, 130.0 - CGFloat(i) * 8.0)) }
        let parShape = recognizer.recognizeShape(from: parPts)
        assertTrue(parShape?.kind == .parallelogram, "Rozpoznawanie równoległoboku")

        // Test 1.11: Trapez prostokątny lewy
        var rTrapLeft = [StrokePoint]()
        for x in stride(from: 50.0, through: 180.0, by: 10.0) { rTrapLeft.append(pt(x, 50)) }
        for i in 0...10 { rTrapLeft.append(pt(180.0 + CGFloat(i) * 6.0, 50.0 + CGFloat(i) * 8.0)) }
        for x in stride(from: 240.0, through: 50.0, by: -10.0) { rTrapLeft.append(pt(x, 130)) }
        for y in stride(from: 130.0, through: 50.0, by: -10.0) { rTrapLeft.append(pt(50, y)) }
        let rTrapLeftShape = recognizer.recognizeShape(from: rTrapLeft)
        assertTrue(rTrapLeftShape?.kind == .rightTrapezoid, "Rozpoznawanie trapezu prostokątnego (kąt po lewej)")

        // Test 1.12: Trapez prostokątny prawy
        var rTrapRight = [StrokePoint]()
        for x in stride(from: 100.0, through: 240.0, by: 10.0) { rTrapRight.append(pt(x, 50)) }
        for y in stride(from: 50.0, through: 130.0, by: 10.0) { rTrapRight.append(pt(240, y)) }
        for x in stride(from: 240.0, through: 40.0, by: -10.0) { rTrapRight.append(pt(x, 130)) }
        for i in 0...10 { rTrapRight.append(pt(40.0 + CGFloat(i) * 6.0, 130.0 - CGFloat(i) * 8.0)) }
        let rTrapRightShape = recognizer.recognizeShape(from: rTrapRight)
        assertTrue(rTrapRightShape?.kind == .rightTrapezoidRight, "Rozpoznawanie trapezu prostokątnego (kąt po prawej)")

        // Test 1.13: Sześciokąt regularny
        var hexPts = [StrokePoint]()
        for i in 0...60 {
            let angle = CGFloat(i) * (2.0 * .pi / 60.0)
            let segment = Int(floor(angle / (.pi / 3.0)))
            let baseAngle = CGFloat(segment) * (.pi / 3.0) + (.pi / 6.0)
            let r = 70.0 / cos(angle - baseAngle)
            hexPts.append(pt(200 + r * cos(angle), 200 + r * sin(angle)))
        }
        hexPts.append(hexPts[0])
        let hexShape = recognizer.recognizeShape(from: hexPts)
        assertTrue(hexShape?.kind == .hexagon, "Rozpoznawanie sześciokąta foremnego")

        // Test 1.14: Sześciokąt rozciągnięty (stretched hexagon)
        var stretchedHexPts = [StrokePoint]()
        for x in stride(from: 100.0, through: 240.0, by: 10.0) { stretchedHexPts.append(pt(x, 50)) }
        for i in 0...8 { stretchedHexPts.append(pt(240.0 + CGFloat(i) * 6.0, 50.0 + CGFloat(i) * 6.0)) }
        for i in 0...8 { stretchedHexPts.append(pt(288.0 - CGFloat(i) * 6.0, 98.0 + CGFloat(i) * 6.0)) }
        for x in stride(from: 240.0, through: 100.0, by: -10.0) { stretchedHexPts.append(pt(x, 146)) }
        for i in 0...8 { stretchedHexPts.append(pt(100.0 - CGFloat(i) * 6.0, 146.0 - CGFloat(i) * 6.0)) }
        for i in 0...8 { stretchedHexPts.append(pt(52.0 + CGFloat(i) * 6.0, 98.0 - CGFloat(i) * 6.0)) }
        stretchedHexPts.append(stretchedHexPts[0])
        let stretchedHexShape = recognizer.recognizeShape(from: stretchedHexPts)
        assertTrue(stretchedHexShape?.kind == .stretchedHexagon, "Rozpoznawanie rozciągniętego sześciokąta (nie jako elipsa!)")

        // Test 1.15: Ochrona pisma odręcznego - mała litera 'o'
        var letterOPts = [StrokePoint]()
        for i in 0...24 {
            let a = CGFloat(i) * (2.0 * .pi / 24.0)
            letterOPts.append(pt(50 + 10 * cos(a), 50 + 12 * sin(a)))
        }
        letterOPts.append(letterOPts[0])
        let letterOShape = recognizer.recognizeShape(from: letterOPts)
        assertTrue(letterOShape == nil, "Filtrowanie małej odręcznej litery 'o' (nie zamienia w okrąg)")

        // Test 1.16: Ochrona pisma ciągłego - słowo ze zmianami dx
        var cursivePts = [StrokePoint]()
        for i in 0..<80 {
            let t = CGFloat(i)
            let x = 100 + t * 2.0 + 15.0 * sin(t * 0.35)
            let y = 100 + 12.0 * cos(t * 0.35)
            cursivePts.append(pt(x, y))
        }
        let cursiveShape = recognizer.recognizeShape(from: cursivePts)
        assertTrue(cursiveShape == nil, "Filtrowanie pisma ciągłego z infleksjami kierunku (nie zamienia w figurę)")


        // MARK: - 2. TESTY MODELU I ZARZĄDZANIA NOTATKAMI (DATASTORE)
        print("\n--- 2. MODUŁ DATASTORE & ZARZĄDZANIE DANYMI ---")
        let dataStore = DataStore()
        dataStore.notes.removeAll()

        // Test 2.1: Tworzenie nowej notatki
        dataStore.createNote(title: "Testowa Notatka 1")
        assertTrue(dataStore.notes.count == 1, "Tworzenie nowej notatki")
        let note = dataStore.notes[0]
        assertEqual(note.title, "Testowa Notatka 1", "Poprawny tytuł notatki")
        assertEqual(dataStore.selectedNoteId, note.id, "Automatyczne zaznaczenie nowej notatki")

        // Test 2.2: Dodawanie strony
        dataStore.addPage(to: note.id)
        assertEqual(dataStore.selectedNote?.pages.count, 2, "Dodawanie kolejnej strony do notatki")

        // Test 2.3: Zmiana narzędzia i toggle pióro/gumka
        dataStore.selectedTool = .pen
        dataStore.togglePenEraser()
        assertEqual(dataStore.selectedTool, .eraser, "Przełączenie pióro -> gumka")
        dataStore.togglePenEraser()
        assertEqual(dataStore.selectedTool, .pen, "Przełączenie gumka -> pióro")


        // MARK: - 3. TESTY OBSŁUGI ZOOMU I SKRÓTÓW TABLETU
        print("\n--- 3. MODUŁ ZOOMU & SKRÓTÓW TABLETU ---")
        dataStore.zoomReset()
        assertEqual(dataStore.zoomScale, 1.0, "Reset powiększenia do 100% (1.0)")

        dataStore.zoomIn()
        assertTrue(abs(dataStore.zoomScale - 1.15) < 0.01, "Przybliżenie zoomIn (+15%) -> 115%")

        dataStore.zoomOut()
        assertTrue(abs(dataStore.zoomScale - 1.0) < 0.01, "Oddalenie zoomOut (-15%) -> 100%")

        for _ in 0...25 { dataStore.zoomIn() }
        assertTrue(dataStore.zoomScale <= 3.0, "Maksymalny limit przybliżenia (300% / 3.0)")

        for _ in 0...30 { dataStore.zoomOut() }
        assertTrue(dataStore.zoomScale >= 0.4, "Minimalny limit oddalenia (40% / 0.4)")

        dataStore.zoomReset()
        assertEqual(dataStore.zoomScale, 1.0, "Ponowny powrót do 1.0")


        // MARK: - 4. TESTY SYSTEMU COFNIJ / PONÓW (UNDO / REDO)
        print("\n--- 4. MODUŁ COFNIJ / PONÓW (UNDO / REDO) ---")
        let testStroke1 = DrawingStroke(tool: .pen, colorHex: "#000000", baseWidth: 3.0, points: linePts)
        dataStore.addStroke(testStroke1)
        assertTrue(dataStore.canUndo, "Możliwość cofnięcia po dodaniu kreski (canUndo == true)")
        assertEqual(dataStore.selectedNote?.currentPage.strokes.count, 1, "Płótno zawiera 1 kreskę")

        dataStore.undo()
        assertEqual(dataStore.selectedNote?.currentPage.strokes.count, 0, "Cofnięcie usunęło kreskę z płótna")
        assertTrue(dataStore.canRedo, "Możliwość ponowienia (canRedo == true)")

        dataStore.redo()
        assertEqual(dataStore.selectedNote?.currentPage.strokes.count, 1, "Ponowienie przywróciło kreskę")


        // MARK: - 5. TESTY POLA TEKSTOWEGO (CANVAS TEXT BOX)
        print("\n--- 5. MODUŁ PÓL TEKSTOWYCH (CANVAS TEXT BOX) ---")
        dataStore.addTextBox(x: 120, y: 180)
        assertTrue(dataStore.selectedNote?.currentPage.textBoxes.count == 1, "Dodanie nowego pola tekstowego")
        guard let tb = dataStore.selectedNote?.currentPage.textBoxes.first else {
            fatalError("Brak pola tekstowego!")
        }
        assertEqual(dataStore.activeEditingTextBoxId, tb.id, "Automatyczny fokus na nowo utworzone pole")

        var modifiedTb = tb
        modifiedTb.text = "Welcome to Quillfolio!"
        modifiedTb.fontSize = 18.0
        modifiedTb.fontDesign = "rounded"
        modifiedTb.textAlignment = "center"
        modifiedTb.indentLevel = 2
        dataStore.updateTextBox(modifiedTb)

        let loadedTb = dataStore.selectedNote?.currentPage.textBoxes.first
        assertEqual(loadedTb?.text, "Welcome to Quillfolio!", "Aktualizacja tekstu pola")
        assertEqual(loadedTb?.fontSize, 18.0, "Aktualizacja rozmiaru czcionki")
        assertEqual(loadedTb?.fontDesign, "rounded", "Aktualizacja kroju pisma")
        assertEqual(loadedTb?.textAlignment, "center", "Aktualizacja wyrównania tekstu")
        assertEqual(loadedTb?.indentLevel, 2, "Aktualizacja wcięcia tekstu")

        dataStore.deleteTextBox(id: tb.id)
        assertEqual(dataStore.selectedNote?.currentPage.textBoxes.count, 0, "Usunięcie pola tekstowego")


        // MARK: - 6. TESTY KARTECZEK SAMOPRZYLEPNYCH (STICKY NOTES)
        print("\n--- 6. MODUŁ KARTECZEK (STICKY NOTES) ---")
        dataStore.addStickyNote(x: 200, y: 250)
        assertTrue(dataStore.selectedNote?.currentPage.stickyNotes.count == 1, "Dodanie karteczki samoprzylepnej")
        guard let sticky = dataStore.selectedNote?.currentPage.stickyNotes.first else {
            fatalError("Brak karteczki!")
        }
        assertEqual(sticky.colorHex, "#FFF475", "Domyślny słoneczny kolor karteczki")

        var modifiedSticky = sticky
        modifiedSticky.text = "Pamiętaj o spotkaniu"
        modifiedSticky.colorHex = "#BAE6FD" // Błękitna
        dataStore.updateStickyNote(modifiedSticky)

        let loadedSticky = dataStore.selectedNote?.currentPage.stickyNotes.first
        assertEqual(loadedSticky?.text, "Pamiętaj o spotkaniu", "Aktualizacja tekstu karteczki")
        assertEqual(loadedSticky?.colorHex, "#BAE6FD", "Aktualizacja koloru karteczki")

        dataStore.deleteStickyNote(id: sticky.id)
        assertEqual(dataStore.selectedNote?.currentPage.stickyNotes.count, 0, "Usunięcie karteczki")


        // MARK: - 7. TESTY TABEL (CANVAS TABLES)
        print("\n--- 7. MODUŁ TABEL (CANVAS TABLES) ---")
        dataStore.addTable(x: 100, y: 300, rows: 3, cols: 3)
        assertTrue(dataStore.selectedNote?.currentPage.tables.count == 1, "Wstawienie tabeli 3x3")
        guard let tbl = dataStore.selectedNote?.currentPage.tables.first else {
            fatalError("Brak tabeli!")
        }
        assertEqual(tbl.rows, 3, "Tabela ma dokładnie 3 wiersze")
        assertEqual(tbl.cols, 3, "Tabela ma 3 kolumny")
        assertEqual(tbl.data.count, 3, "Macierz danych ma 3 wiersze")
        assertEqual(tbl.data[0].count, 3, "Wiersz 0 ma 3 komórki")

        // Edycja komórki tabeli
        var tableToUpdate = tbl
        tableToUpdate.data[0][1] = "Nagłówek 2"
        dataStore.updateTable(tableToUpdate)
        let updatedTbl = dataStore.selectedNote?.currentPage.tables.first!
        assertEqual(updatedTbl?.data[0][1], "Nagłówek 2", "Edycja zawartości komórki w tabeli")

        // Dodawanie wiersza
        tableToUpdate.rows += 1
        tableToUpdate.data.append(["", "", ""])
        tableToUpdate.rowHeights.append(34.0)
        dataStore.updateTable(tableToUpdate)
        let afterAddRow = dataStore.selectedNote?.currentPage.tables.first!
        assertEqual(afterAddRow?.rows, 4, "Dodanie nowego wiersza (teraz 4 wiersze)")

        // Usuwanie kolumn aż do 1 kolumny (sprawdzenie czy nie ma crashu ani błędu)
        tableToUpdate.cols = 1
        for r in 0..<tableToUpdate.rows {
            tableToUpdate.data[r] = [tableToUpdate.data[r][0]]
        }
        tableToUpdate.colWidths = [120.0]
        dataStore.updateTable(tableToUpdate)
        let afterRemoveCols = dataStore.selectedNote?.currentPage.tables.first!
        assertEqual(afterRemoveCols?.cols, 1, "Zredukowano kolumny do 1 bez uszkodzenia struktury")

        dataStore.deleteTable(id: tbl.id)
        assertEqual(dataStore.selectedNote?.currentPage.tables.count, 0, "Usunięcie tabeli")


        // MARK: - 8. TESTY OPERACJI ZAZNACZANIA, DUPLIKOWANIA I SCHOWKA
        print("\n--- 8. MODUŁ ZAZNACZANIA, DUPLIKOWANIA I SCHOWKA ---")
        let strokeToDupe = DrawingStroke(tool: .pen, colorHex: "#FF0000", baseWidth: 2.0, points: sqPts)
        dataStore.addStroke(strokeToDupe)
        dataStore.selectAllStrokes()
        assertTrue(dataStore.selectedStrokeIds.contains(strokeToDupe.id), "Zaznaczenie pociągnięć")

        dataStore.duplicateSelectedStrokes()
        assertEqual(dataStore.selectedNote?.currentPage.strokes.count, 4, "Duplikacja zaznaczonych elementów (2 -> 4)")

        dataStore.deleteSelectedStrokes()
        assertEqual(dataStore.selectedNote?.currentPage.strokes.count, 2, "Usunięcie zaznaczonych pociągnięć (4 -> 2)")


        // MARK: - 9. TESTY LOKALIZACJI I ZAKŁADKI USTAWIEŃ
        print("\n--- 9. MODUŁ LOKALIZACJI (PL / EN) I USTAWIEŃ ---")
        
        // Test języka polskiego i angielskiego
        dataStore.language = .polish
        assertEqual(dataStore.t("Polski", "English"), "Polski", "Lokalizacja: tłumaczenie w trybie polskim")
        assertEqual(PaperStyle.grid.localizedName(language: dataStore.language), "W kratkę", "Lokalizacja stylu papieru PL")
        assertEqual(PaperColor.chalkboard.localizedName(language: dataStore.language), "Tablica szkolna", "Lokalizacja koloru papieru PL")
        assertEqual(DrawingTool.pen.localizedName(language: dataStore.language), "Pióro wieczne", "Lokalizacja narzędzia rysowania PL")
        assertEqual(ShapeKind.trapezoid.localizedName(language: dataStore.language), "Trapez równoramienny", "Lokalizacja figury geometrycznej PL")

        dataStore.language = .english
        assertEqual(dataStore.t("Polski", "English"), "English", "Lokalizacja: tłumaczenie w trybie angielskim")
        assertEqual(PaperStyle.grid.localizedName(language: dataStore.language), "Grid", "Lokalizacja stylu papieru EN")
        assertEqual(PaperColor.chalkboard.localizedName(language: dataStore.language), "Chalkboard", "Lokalizacja koloru papieru EN")
        assertEqual(DrawingTool.pen.localizedName(language: dataStore.language), "Fountain Pen", "Lokalizacja narzędzia rysowania EN")
        assertEqual(ShapeKind.trapezoid.localizedName(language: dataStore.language), "Trapezoid", "Lokalizacja figury geometrycznej EN")

        // Test preferencji i domyślnych ustawień
        dataStore.defaultPaperStyle = .dots
        dataStore.defaultPaperColor = .chalkboard
        let noteWithDefaults = dataStore.createNote()
        assertEqual(noteWithDefaults.paperStyle, .dots, "Tworzenie notatki z domyślnym stylem papieru z ustawień")
        assertEqual(noteWithDefaults.paperColor, .chalkboard, "Tworzenie notatki z domyślnym kolorem papieru z ustawień")
        
        // Test ścieżki pamięci i statystyk
        assertTrue(!dataStore.storageDirectoryPath.isEmpty, "Katalog przechowywania danych nie jest pusty")
        assertTrue(dataStore.totalStrokesCount >= 0, "Poprawne zliczanie narysowanych kresek")
        assertTrue(dataStore.totalPagesCount >= 1, "Poprawne zliczanie stron w notatniku")

        // Test resetu ustawień
        dataStore.resetSettingsToDefaults()
        assertEqual(dataStore.language, .polish, "Reset ustawień: powrót do języka polskiego")
        assertEqual(dataStore.defaultPaperStyle, .grid, "Reset ustawień: domyślny styl w kratkę")
        assertEqual(dataStore.defaultPaperColor, .white, "Reset ustawień: domyślny kolor biały")
        assertEqual(dataStore.defaultDrawingTool, .pen, "Reset ustawień: domyślne pióro")


        // MARK: - PODSUMOWANIE WYNIKÓW
        print("\n=================================================================")
        print("🏁 RAPORT Z TESTÓW NOTATNIK STUDIO:")
        print("   Łącznie wykonano testów: \(testsPassed + testsFailed)")
        print("   Sukcesów: \(testsPassed)")
        print("   Błędów: \(testsFailed)")
        print("=================================================================")

        if testsFailed > 0 {
            print("❌ NIEKTÓRE TESTY NIE PRZESZŁY!")
            exit(1)
        } else {
            print("🎉 WSZYSTKIE TESTY ZAKOŃCZYŁY SIĘ 100% SUKCESEM!")
        }
    }
}
