import SwiftUI
@preconcurrency import Apollo

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @EnvironmentObject private var fontSettings: FontSettingsManager
    @State private var showingClearCacheAlert = false
    @State private var cacheCleared = false
    @State private var cacheSize: String = NSLocalizedString("settings.calculating", comment: "Cache size calculating")
#if os(iOS)
    @State private var currentAppIcon: String = {
        // Map actual alternate icon name to display name
        switch UIApplication.shared.alternateIconName {
        case "AppIconCry": return "Cry"
        case "AppIconCurious": return "Curious"
        case "AppIconFrown": return "Frown"
        case "AppIconWink": return "Wink"
        default: return "Logo"
        }
    }()
#endif

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

    private let appIcons: [(name: String, displayName: String)] = [
        ("Logo", "Default"),
        ("Cry", "Cry"),
        ("Curious", "Curious"),
        ("Frown", "Frown"),
        ("Wink", "Wink")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 16) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        Text(NSLocalizedString("signIn.title", comment: "App title"))
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section {
                    HStack {
                        Text(NSLocalizedString("settings.version", comment: "Version label"))
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    NavigationLink {
                        FontPickerView()
                    } label: {
                        HStack {
                            Text(NSLocalizedString("settings.typography.fontFamily", comment: "Font family setting"))
                            Spacer()
                            Text(fontSettings.selectedFontName)
                                .foregroundStyle(.secondary)
                                .font(fontSettings.font(for: .body))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(NSLocalizedString("settings.typography.fontSize", comment: "Font size setting"))
                            Spacer()
                            Text("\(Int(fontSettings.fontSizeMultiplier * 100))%")
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: SliderHelper.snappedBinding($fontSettings.fontSizeMultiplier, step: 0.05, range: 0.75...3.0), in: 0.75...3.0, step: 0.05)
                            .disabled(fontSettings.useSystemDynamicType)
                    }
                    .opacity(fontSettings.useSystemDynamicType ? 0.5 : 1.0)

                    Toggle(NSLocalizedString("settings.typography.useSystemDynamicType", comment: "Use system dynamic type toggle"), isOn: $fontSettings.useSystemDynamicType)

                    Button(NSLocalizedString("settings.typography.resetToDefaults", comment: "Reset to defaults button")) {
                        fontSettings.resetToDefaults()
                    }
                    .foregroundStyle(.blue)
                } header: {
                    Text(NSLocalizedString("settings.typography", comment: "Typography section header"))
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("settings.typography.preview", comment: "Preview label"))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(NSLocalizedString("settings.typography.previewText", comment: "Preview text"))
                            .font(fontSettings.font(for: .body))
                            .padding(12)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

#if os(iOS)
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(appIcons, id: \.name) { icon in
                                Button {
                                    setAppIcon(icon.name)
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(icon.name)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(currentAppIcon == icon.name ? Color.blue : Color.clear, lineWidth: 3)
                                            )

                                        Text(icon.displayName)
                                            .font(.caption)
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text(NSLocalizedString("settings.appIcon", comment: "App icon section header"))
                }
#endif

                Section {
                    HStack {
                        Text(NSLocalizedString("settings.cacheSize", comment: "Cache size label"))
                        Spacer()
                        Text(cacheSize)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showingClearCacheAlert = true
                    } label: {
                        HStack {
                            Text(NSLocalizedString("settings.clearCache", comment: "Clear cache button"))
                            Spacer()
                            if cacheCleared {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                } header: {
                    Text(NSLocalizedString("settings.cache", comment: "Cache section header"))
                }

                if authManager.isAuthenticated {
                    Section {
                        Button(role: .destructive) {
                            Task {
                                await authManager.signOut()
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Text(NSLocalizedString("settings.signOut", comment: "Sign out button"))
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("nav.settings", comment: "Settings navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("settings.done", comment: "Done button")) {
                        dismiss()
                    }
                }
            }
            .alert(NSLocalizedString("settings.clearCacheAlert.title", comment: "Clear cache alert title"), isPresented: $showingClearCacheAlert) {
                Button(NSLocalizedString("settings.clearCacheAlert.cancel", comment: "Cancel button"), role: .cancel) { }
                Button(NSLocalizedString("settings.clearCacheAlert.clear", comment: "Clear button"), role: .destructive) {
                    Task {
                        await clearCache()
                    }
                }
            } message: {
                Text(NSLocalizedString("settings.clearCacheAlert.message", comment: "Clear cache alert message"))
            }
            .task {
                await calculateCacheSize()
            }
        }
    }

    private func calculateCacheSize() async {
        let size = await getCacheDirectorySize()
        cacheSize = formatBytes(size)
    }

    private func getCacheDirectorySize() async -> Int64 {
        await withCheckedContinuation { continuation in
            Task.detached {
                let fileManager = FileManager.default
                var totalSize: Int64 = 0

                // Calculate iOS cache directory size
                if let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
                    if let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
                        while let fileURL = enumerator.nextObject() as? URL {
                            do {
                                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                                if let fileSize = resourceValues.fileSize {
                                    totalSize += Int64(fileSize)
                                }
                            } catch {
                                // Skip files that can't be read
                            }
                        }
                    }
                }

                // Calculate Apollo SQLite cache size
                if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let apolloCacheURL = documentsDirectory.appendingPathComponent("apollo_cache.sqlite")
                    do {
                        let resourceValues = try apolloCacheURL.resourceValues(forKeys: [.fileSizeKey])
                        if let fileSize = resourceValues.fileSize {
                            totalSize += Int64(fileSize)
                        }
                    } catch {
                        // Apollo cache file doesn't exist or can't be read
                    }

                    // Also include SQLite WAL and SHM files
                    let walURL = documentsDirectory.appendingPathComponent("apollo_cache.sqlite-wal")
                    let shmURL = documentsDirectory.appendingPathComponent("apollo_cache.sqlite-shm")

                    for url in [walURL, shmURL] {
                        do {
                            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                            if let fileSize = resourceValues.fileSize {
                                totalSize += Int64(fileSize)
                            }
                        } catch {
                            // File doesn't exist or can't be read
                        }
                    }
                }

                continuation.resume(returning: totalSize)
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func clearCache() async {
        do {
            try await apolloClient.clearCache()
            await calculateCacheSize()
            cacheCleared = true
        } catch {
            print("Error clearing cache: \(error)")
        }
    }

    private func setAppIcon(_ iconName: String) {
#if os(iOS)
        // Map display name to actual alternate icon name
        let actualIconName: String? = {
            switch iconName {
            case "Logo": return nil
            case "Cry": return "AppIconCry"
            case "Curious": return "AppIconCurious"
            case "Frown": return "AppIconFrown"
            case "Wink": return "AppIconWink"
            default: return nil
            }
        }()

        UIApplication.shared.setAlternateIconName(actualIconName) { error in
            if let error = error {
                print("Failed request to update the app's icon: \(error)")
            } else {
                currentAppIcon = iconName
            }
        }
#endif
    }
}
