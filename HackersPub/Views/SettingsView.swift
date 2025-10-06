import SwiftUI
@preconcurrency import Apollo

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @State private var showingClearCacheAlert = false
    @State private var cacheCleared = false
    @State private var cacheSize: String = NSLocalizedString("settings.calculating", comment: "Cache size calculating")

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

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
                guard let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                    continuation.resume(returning: 0)
                    return
                }

                var totalSize: Int64 = 0

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
}
