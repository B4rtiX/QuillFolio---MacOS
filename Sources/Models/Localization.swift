import Foundation
import SwiftUI

public enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case polish = "pl"
    case english = "en"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .polish: return "Polski"
        case .english: return "English"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .polish: return "Język polski"
        case .english: return "English language"
        }
    }
    
    public var flag: String {
        switch self {
        case .polish: return "🇵🇱"
        case .english: return "🇬🇧"
        }
    }
}

public struct L10n {
    public static func tr(_ pl: String, _ en: String, language: AppLanguage) -> String {
        language == .polish ? pl : en
    }
}

// MARK: - Localized Names Extensions

extension PaperStyle {
    public func localizedName(language: AppLanguage) -> String {
        switch self {
        case .blank: return language == .polish ? "Czysta" : "Blank"
        case .lined: return language == .polish ? "W linie" : "Ruled / Lined"
        case .grid: return language == .polish ? "W kratkę" : "Grid"
        case .dots: return language == .polish ? "W kropki" : "Dotted"
        }
    }
}

extension PaperColor {
    public func localizedName(language: AppLanguage) -> String {
        switch self {
        case .white: return language == .polish ? "Biały" : "White"
        case .cream: return language == .polish ? "Kremowy (Sepia)" : "Cream (Sepia)"
        case .yellowLegal: return language == .polish ? "Żółty notatnik" : "Yellow Legal"
        case .darkSlate: return language == .polish ? "Ciemny grafit" : "Dark Slate"
        case .chalkboard: return language == .polish ? "Tablica szkolna" : "Chalkboard"
        }
    }
}

extension DrawingTool {
    public func localizedName(language: AppLanguage) -> String {
        switch self {
        case .pointer: return language == .polish ? "Kursor" : "Select & Move"
        case .pen: return language == .polish ? "Pióro wieczne" : "Fountain Pen"
        case .calligraphy: return language == .polish ? "Kaligrafia" : "Calligraphy"
        case .brush: return language == .polish ? "Pędzel" : "Brush"
        case .pencil: return language == .polish ? "Ołówek" : "Pencil"
        case .crayon: return language == .polish ? "Kredka woskowa" : "Wax Crayon"
        case .highlighter: return language == .polish ? "Zakreślacz" : "Highlighter"
        case .eraser: return language == .polish ? "Gumka" : "Eraser"
        case .lasso: return language == .polish ? "Lasso" : "Lasso Select"
        case .shape: return language == .polish ? "Kształty" : "Shapes"
        case .text: return language == .polish ? "Pole tekstowe" : "Text Box"
        case .sticky: return language == .polish ? "Karteczka" : "Sticky Note"
        case .laser: return language == .polish ? "Wskaźnik laserowy" : "Laser Pointer"
        }
    }
}

extension ShapeKind {
    public func localizedName(language: AppLanguage) -> String {
        switch self {
        case .auto: return language == .polish ? "Automatyczny" : "Automatic"
        case .line: return language == .polish ? "Linia" : "Line"
        case .arrow: return language == .polish ? "Strzałka" : "Arrow"
        case .doubleArrow: return language == .polish ? "Strzałka dwustronna" : "Double Arrow"
        case .square: return language == .polish ? "Kwadrat" : "Square"
        case .rectangle: return language == .polish ? "Prostokąt" : "Rectangle"
        case .roundedRectangle: return language == .polish ? "Zaokrąglony prostokąt" : "Rounded Rectangle"
        case .circle: return language == .polish ? "Koło / Okrąg" : "Circle"
        case .ellipse: return language == .polish ? "Elipsa" : "Ellipse"
        case .triangle: return language == .polish ? "Trójkąt" : "Triangle"
        case .rhombus: return language == .polish ? "Romb" : "Rhombus"
        case .parallelogram: return language == .polish ? "Równoległobok" : "Parallelogram"
        case .trapezoid: return language == .polish ? "Trapez równoramienny" : "Trapezoid"
        case .rightTrapezoid: return language == .polish ? "Trapez prostokątny (lewy)" : "Right Trapezoid (Left)"
        case .rightTrapezoidRight: return language == .polish ? "Trapez prostokątny (prawy)" : "Right Trapezoid (Right)"
        case .hexagon: return language == .polish ? "Sześciokąt" : "Hexagon"
        case .stretchedHexagon: return language == .polish ? "Sześciokąt rozciągnięty" : "Stretched Hexagon"
        case .star: return language == .polish ? "Gwiazda" : "Star"
        case .cloud: return language == .polish ? "Chmurka" : "Cloud"
        case .table: return language == .polish ? "Tabela" : "Table"
        }
    }
}
