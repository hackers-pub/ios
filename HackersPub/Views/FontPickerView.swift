import SwiftUI

struct FontPickerView: View {
    @EnvironmentObject private var fontSettings: FontSettingsManager
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var fontCategory: FontCategory = .common

    enum FontCategory: String, CaseIterable, Identifiable {
        case common
        case all

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .common:
                return NSLocalizedString("fontPicker.category.common", comment: "Common fonts category")
            case .all:
                return NSLocalizedString("fontPicker.category.all", comment: "All fonts category")
            }
        }
    }

    private var filteredFonts: [String] {
        let fontsToFilter: [String]

        switch fontCategory {
        case .common:
            fontsToFilter = fontSettings.commonFonts
        case .all:
            fontsToFilter = fontSettings.allAvailableFonts
        }

        if searchText.isEmpty {
            return fontsToFilter
        } else {
            return fontsToFilter.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        List {
            Section {
                Picker(NSLocalizedString("fontPicker.category", comment: "Font category picker label"), selection: $fontCategory) {
                    ForEach(FontCategory.allCases) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text(footerText)
                    .font(.caption)
            }

            Section {
                ForEach(filteredFonts, id: \.self) { fontName in
                    fontRow(for: fontName)
                }
            } header: {
                Text(String(format: NSLocalizedString("fontPicker.fontsCount", comment: "Fonts count"), filteredFonts.count))
            }
        }
        .navigationTitle(NSLocalizedString("fontPicker.title", comment: "Font picker title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .searchable(text: $searchText, prompt: NSLocalizedString("fontPicker.search", comment: "Search fonts placeholder"))
    }

    private var footerText: String {
        switch fontCategory {
        case .common:
            return NSLocalizedString("fontPicker.footer.common", comment: "Common fonts footer")
        case .all:
            return String(format: NSLocalizedString("fontPicker.footer.all", comment: "All fonts footer"), fontSettings.allAvailableFonts.count)
        }
    }

    private func fontRow(for fontName: String) -> some View {
        Button {
            fontSettings.selectedFontName = fontName
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(fontName)
                        .foregroundStyle(.primary)
                        .font(.custom(fontName == "System" ? "System" : fontName, size: 17))

                    Text(NSLocalizedString("fontPicker.preview", comment: "Font preview text"))
                        .font(.custom(fontName == "System" ? "System" : fontName, size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if fontSettings.selectedFontName == fontName {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct FontPickerView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            FontPickerView()
                .environmentObject(FontSettingsManager.shared)
        }
    }
}
