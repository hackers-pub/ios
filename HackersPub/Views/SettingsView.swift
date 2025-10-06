import SwiftUI
@preconcurrency import Apollo

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @State private var showingClearCacheAlert = false
    @State private var cacheCleared = false
    @State private var cacheSize: String = "Calculating..."

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

                        Text("Hackers' Pub")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    HStack {
                        Text("Cache Size")
                        Spacer()
                        Text(cacheSize)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showingClearCacheAlert = true
                    } label: {
                        HStack {
                            Text("Clear Cache")
                            Spacer()
                            if cacheCleared {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                } header: {
                    Text("Cache")
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
                                Text("Sign Out")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    Task {
                        await clearCache()
                    }
                }
            } message: {
                Text("This will clear all cached data. Your timelines will be refreshed.")
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
        await Task.detached {
            let fileManager = FileManager.default
            guard let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                return 0
            }

            var totalSize: Int64 = 0

            if let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
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

            return totalSize
        }.value
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
