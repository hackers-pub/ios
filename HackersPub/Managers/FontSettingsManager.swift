import SwiftUI
import Combine
import UIKit

class FontSettingsManager: ObservableObject {
    static let shared = FontSettingsManager()

    // User preferences stored in UserDefaults with manual publishing
    @Published var selectedFontName: String {
        didSet {
            UserDefaults.standard.set(selectedFontName, forKey: "selectedFontName")
        }
    }

    @Published var fontSizeMultiplier: Double {
        didSet {
            UserDefaults.standard.set(fontSizeMultiplier, forKey: "fontSizeMultiplier")
        }
    }

    @Published var useSystemDynamicType: Bool {
        didSet {
            UserDefaults.standard.set(useSystemDynamicType, forKey: "useSystemDynamicType")
        }
    }

    private(set) var commonFonts: [String] = []
    private(set) var allAvailableFonts: [String] = []

    private init() {
        // Load saved preferences
        self.selectedFontName = UserDefaults.standard.string(forKey: "selectedFontName") ?? "System"
        self.fontSizeMultiplier = UserDefaults.standard.double(forKey: "fontSizeMultiplier") != 0 ? UserDefaults.standard.double(forKey: "fontSizeMultiplier") : 1.0
        self.useSystemDynamicType = UserDefaults.standard.object(forKey: "useSystemDynamicType") as? Bool ?? true

        loadAllAvailableFonts()
        setupCommonFonts()
    }

    // Load all fonts available on the device
    private func loadAllAvailableFonts() {
        var families = Set<String>()
        var allFonts = Set<String>()

        // Always include System as the first option
        allFonts.insert("System")

        for familyName in UIFont.familyNames.sorted() {
            families.insert(familyName)
            let fontNames = UIFont.fontNames(forFamilyName: familyName)
            for fontName in fontNames {
                allFonts.insert(fontName)
            }
        }

        allAvailableFonts = Array(allFonts).sorted { font1, font2 in
            if font1 == "System" { return true }
            if font2 == "System" { return false }
            return font1.localizedCaseInsensitiveCompare(font2) == .orderedAscending
        }
    }

    // Setup common fonts from detected fonts
    private func setupCommonFonts() {
        // List of commonly used font families (will be filtered by what's actually available)
        let commonFamilyNames = [
            "System",
            "New York",
            "Arial",
            "Helvetica",
            "Helvetica Neue",
            "Times New Roman",
            "Courier",
            "Courier New",
            "Avenir",
            "Avenir Next",
        ]

        var common = [String]()

        for fontName in commonFamilyNames {
            if fontName == "System" || isFontAvailable(fontName) {
                common.append(fontName)
            }
        }

        commonFonts = common
    }

    // Get font name for CSS
    var cssFontFamily: String {
        switch selectedFontName {
        case "System":
            return "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"

        default:
            // For custom fonts, wrap in quotes and provide fallback
            return "'\(selectedFontName)', -apple-system, sans-serif"
        }
    }

    func uiFont(for textStyle: UIFont.TextStyle, weight: UIFont.Weight = .regular) -> UIFont {
        let size = scaledSize(for: textStyle)

        if selectedFontName == "System" {
            return UIFont.systemFont(ofSize: size, weight: weight)
        }

        if let font = UIFont(name: selectedFontName, size: size) {
            return font
        }

        // Fallback to system font
        return UIFont.systemFont(ofSize: size, weight: weight)
    }

    func font(for textStyle: UIFont.TextStyle) -> Font {
        let size = scaledSize(for: textStyle)

        if selectedFontName == "System" {
            return .system(size: size)
        }

        return .custom(selectedFontName, size: size)
    }

    // Get scaled font size based on user preference
    func scaledSize(for textStyle: UIFont.TextStyle) -> CGFloat {
        if useSystemDynamicType {
            // Disable multipling font size
            return UIFont.preferredFont(forTextStyle: textStyle).pointSize
        } else {
            // Base sizes when not using dynamic type
            let baseSize: CGFloat = {
                switch textStyle {
                case .largeTitle: return 34
                case .title1: return 28
                case .title2: return 22
                case .title3: return 20
                case .headline: return 17
                case .body: return 17
                case .callout: return 16
                case .subheadline: return 15
                case .footnote: return 13
                case .caption1: return 12
                case .caption2: return 11
                default: return 17
                }
            }()
            return baseSize * fontSizeMultiplier
        }
    }

    func searchFonts(query: String) -> [String] {
        if query.isEmpty {
            return commonFonts
        }
        return allAvailableFonts.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    func isFontAvailable(_ fontName: String) -> Bool {
        if fontName == "System" { return true }
        return UIFont(name: fontName, size: 12) != nil
    }

    func resetToDefaults() {
        selectedFontName = "System"
        fontSizeMultiplier = 1.0
        useSystemDynamicType = true
    }
}
