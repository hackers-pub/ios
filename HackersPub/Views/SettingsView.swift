import SwiftUI
@preconcurrency import Apollo

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @EnvironmentObject private var fontSettings: FontSettingsManager
    @State private var showingClearCacheAlert = false
    @State private var cacheCleared = false
    @State private var cacheSize: String = NSLocalizedString("settings.calculating", comment: "Cache size calculating")
    @State private var showingAddPasskeyAlert = false
    @State private var newPasskeyName = ""
    @State private var passkeyErrorMessage: String?
    @State private var passkeyPendingRevocation: PasskeyInfo?
    @State private var isRegisteringPasskey = false
    @State private var revokingPasskeyID: String?
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
    @State private var markdownMaxLength = UserDefaults.standard.integer(forKey: "markdownMaxLength") {
        didSet {
            UserDefaults.standard.set(markdownMaxLength, forKey: "markdownMaxLength")
        }
    }
    @AppStorage("engagement.sharePressActionsSwapped") private var sharePressActionsSwapped = false
    @AppStorage("engagement.quotePressActionsSwapped") private var quotePressActionsSwapped = false
    @AppStorage("engagement.confirmBeforeShare") private var confirmBeforeShare = false
    @AppStorage("engagement.confirmBeforeDelete") private var confirmBeforeDelete = true
    @AppStorage(ExternalURLRouter.useInAppBrowserKey) private var useInAppBrowser = true

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

                TypographySettingsSection()

                TimelineSettingsSection(markdownMaxLength: $markdownMaxLength)

                EngagementSettingsSection(
                    sharePressActionsSwapped: $sharePressActionsSwapped,
                    quotePressActionsSwapped: $quotePressActionsSwapped,
                    confirmBeforeShare: $confirmBeforeShare,
                    confirmBeforeDelete: $confirmBeforeDelete
                )

                LinksSettingsSection(useInAppBrowser: $useInAppBrowser)

#if os(iOS)
                AppIconSettingsSection(
                    currentAppIcon: currentAppIcon,
                    appIcons: appIcons,
                    onSelect: setAppIcon
                )
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
                    AuthenticatedSettingsSection(
                        passkeys: authManager.passkeys,
                        isLoadingPasskeys: authManager.isLoadingPasskeys,
                        isRegisteringPasskey: isRegisteringPasskey,
                        revokingPasskeyID: revokingPasskeyID,
                        onAddPasskey: {
                            newPasskeyName = UIDevice.current.name
                            showingAddPasskeyAlert = true
                        },
                        onRemovePasskey: { passkey in
                            passkeyPendingRevocation = passkey
                        },
                        onSignOut: {
                            Task {
                                await authManager.signOut()
                                dismiss()
                            }
                        }
                    )
                }
            }
            .navigationTitle(NSLocalizedString("nav.settings", comment: "Settings navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    }
                    label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(NSLocalizedString("settings.done", comment: "Done button"))
                }
            }
            .modifier(settingsAlerts)
            .task {
                await calculateCacheSize()
                if authManager.isAuthenticated {
                    await authManager.loadPasskeys()
                }
            }
        }
    }

    private var settingsAlerts: SettingsAlertsModifier {
        SettingsAlertsModifier(
            showingClearCacheAlert: $showingClearCacheAlert,
            showingAddPasskeyAlert: $showingAddPasskeyAlert,
            newPasskeyName: $newPasskeyName,
            passkeyPendingRevocation: $passkeyPendingRevocation,
            passkeyErrorMessage: $passkeyErrorMessage,
            onClearCache: {
                Task {
                    await clearCache()
                }
            },
            onRegisterPasskey: {
                Task {
                    await registerPasskey()
                }
            },
            onRevokePasskey: { passkey in
                Task {
                    await revokePasskey(passkey)
                }
            }
        )
    }

    private func registerPasskey() async {
        let name = newPasskeyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        isRegisteringPasskey = true
        defer { isRegisteringPasskey = false }

        do {
            try await authManager.registerPasskey(name: name)
        } catch {
            passkeyErrorMessage = error.localizedDescription
        }
    }

    private func revokePasskey(_ passkey: PasskeyInfo) async {
        revokingPasskeyID = passkey.id
        defer { revokingPasskeyID = nil }

        do {
            try await authManager.revokePasskey(id: passkey.id)
        } catch {
            passkeyErrorMessage = error.localizedDescription
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

#if os(iOS)
private struct AppIconSettingsSection: View {
    let currentAppIcon: String
    let appIcons: [(name: String, displayName: String)]
    let onSelect: (String) -> Void

    var body: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(appIcons, id: \.name) { icon in
                        Button {
                            onSelect(icon.name)
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
    }
}
#endif

private struct TypographySettingsSection: View {
    @EnvironmentObject private var fontSettings: FontSettingsManager

    var body: some View {
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

                Slider(
                    value: SliderHelper.snappedBinding(
                        $fontSettings.fontSizeMultiplier,
                        step: 0.05,
                        range: 0.75...3.0
                    ),
                    in: 0.75...3.0,
                    step: 0.05
                )
                .disabled(fontSettings.useSystemDynamicType)
            }
            .opacity(fontSettings.useSystemDynamicType ? 0.5 : 1.0)

            Toggle(
                NSLocalizedString("settings.typography.useSystemDynamicType", comment: "Use system dynamic type toggle"),
                isOn: $fontSettings.useSystemDynamicType
            )

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
    }
}

private struct SettingsAlertsModifier: ViewModifier {
    @Binding var showingClearCacheAlert: Bool
    @Binding var showingAddPasskeyAlert: Bool
    @Binding var newPasskeyName: String
    @Binding var passkeyPendingRevocation: PasskeyInfo?
    @Binding var passkeyErrorMessage: String?

    let onClearCache: () -> Void
    let onRegisterPasskey: () -> Void
    let onRevokePasskey: (PasskeyInfo) -> Void

    func body(content: Content) -> some View {
        content
            .alert(NSLocalizedString("settings.clearCacheAlert.title", comment: "Clear cache alert title"), isPresented: $showingClearCacheAlert) {
                Button(NSLocalizedString("settings.clearCacheAlert.cancel", comment: "Cancel button"), role: .cancel) { }
                Button(NSLocalizedString("settings.clearCacheAlert.clear", comment: "Clear button"), role: .destructive, action: onClearCache)
            } message: {
                Text(NSLocalizedString("settings.clearCacheAlert.message", comment: "Clear cache alert message"))
            }
            .alert(NSLocalizedString("settings.passkeys.add", comment: "Add passkey alert title"), isPresented: $showingAddPasskeyAlert) {
                TextField(NSLocalizedString("settings.passkeys.name", comment: "Passkey name field"), text: $newPasskeyName)
                Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) { }
                Button(NSLocalizedString("settings.passkeys.add", comment: "Add passkey button"), action: onRegisterPasskey)
                    .disabled(newPasskeyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text(NSLocalizedString("settings.passkeys.addMessage", comment: "Add passkey message"))
            }
            .alert(NSLocalizedString("settings.passkeys.remove", comment: "Remove passkey alert title"), isPresented: removePasskeyAlertBinding) {
                Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) { }
                Button(NSLocalizedString("settings.passkeys.remove", comment: "Remove passkey button"), role: .destructive) {
                    if let passkey = passkeyPendingRevocation {
                        onRevokePasskey(passkey)
                    }
                }
            } message: {
                Text(removePasskeyMessage)
            }
            .alert(NSLocalizedString("settings.passkeys.errorTitle", comment: "Passkey error alert title"), isPresented: Binding(
                get: { passkeyErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        passkeyErrorMessage = nil
                    }
                }
            )) {
                Button(NSLocalizedString("compose.error.ok", comment: "OK button"), role: .cancel) {
                    passkeyErrorMessage = nil
                }
            } message: {
                Text(passkeyErrorMessage ?? "")
            }
    }

    private var removePasskeyAlertBinding: Binding<Bool> {
        Binding(
            get: { passkeyPendingRevocation != nil },
            set: { isPresented in
                if !isPresented {
                    passkeyPendingRevocation = nil
                }
            }
        )
    }

    private var removePasskeyMessage: String {
        String(
            format: NSLocalizedString("settings.passkeys.removeMessage", comment: "Remove passkey confirmation message"),
            passkeyPendingRevocation?.name ?? ""
        )
    }
}

private struct TimelineSettingsSection: View {
    @Binding var markdownMaxLength: Int

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(NSLocalizedString("settings.timeline.markdownMaxLength", comment: "Timeline markdown max length label"))
                    Spacer()
                    Picker(selection: $markdownMaxLength, label: Text("")) {
                        Text("300").tag(300)
                        Text("500").tag(500)
                        Text("700").tag(700)
                        Text("1,000").tag(1000)
                        Text(NSLocalizedString("settings.timeline.unlimited", comment: "Unlimited option label")).tag(0)
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
        } header: {
            Text(NSLocalizedString("settings.timeline", comment: "Timeline section header"))
        } footer: {
            Text(NSLocalizedString("settings.timeline.footer", comment: "Timeline footer"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct EngagementSettingsSection: View {
    @Binding var sharePressActionsSwapped: Bool
    @Binding var quotePressActionsSwapped: Bool
    @Binding var confirmBeforeShare: Bool
    @Binding var confirmBeforeDelete: Bool

    var body: some View {
        Section {
            Toggle(
                NSLocalizedString("settings.engagement.confirmBeforeDelete", comment: "Confirm before delete toggle"),
                isOn: $confirmBeforeDelete
            )
            Toggle(
                NSLocalizedString("settings.engagement.confirmBeforeShare", comment: "Confirm before share toggle"),
                isOn: $confirmBeforeShare
            )
            Toggle(
                NSLocalizedString("settings.engagement.swapShareActions", comment: "Swap share tap and long press actions toggle"),
                isOn: $sharePressActionsSwapped
            )
            Toggle(
                NSLocalizedString("settings.engagement.swapQuoteActions", comment: "Swap quote tap and long press actions toggle"),
                isOn: $quotePressActionsSwapped
            )
        } header: {
            Text(NSLocalizedString("settings.engagement", comment: "Engagement section header"))
        } footer: {
            Text(NSLocalizedString("settings.engagement.footer", comment: "Engagement section footer"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct LinksSettingsSection: View {
    @Binding var useInAppBrowser: Bool

    var body: some View {
        Section {
            Toggle(
                NSLocalizedString("settings.links.useInAppBrowser", comment: "Use in-app browser toggle"),
                isOn: $useInAppBrowser
            )
        } header: {
            Text(NSLocalizedString("settings.links", comment: "Links section header"))
        } footer: {
            Text(NSLocalizedString("settings.links.footer", comment: "Links section footer"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct AuthenticatedSettingsSection: View {
    let passkeys: [PasskeyInfo]
    let isLoadingPasskeys: Bool
    let isRegisteringPasskey: Bool
    let revokingPasskeyID: String?
    let onAddPasskey: () -> Void
    let onRemovePasskey: (PasskeyInfo) -> Void
    let onSignOut: () -> Void

    var body: some View {
        PasskeysSettingsSection(
            passkeys: passkeys,
            isLoading: isLoadingPasskeys,
            isRegistering: isRegisteringPasskey,
            revokingPasskeyID: revokingPasskeyID,
            onAdd: onAddPasskey,
            onRemove: onRemovePasskey
        )

        Section {
            Button(role: .destructive, action: onSignOut) {
                HStack {
                    Spacer()
                    Text(NSLocalizedString("settings.signOut", comment: "Sign out button"))
                    Spacer()
                }
            }
        }
    }
}

private struct PasskeysSettingsSection: View {
    let passkeys: [PasskeyInfo]
    let isLoading: Bool
    let isRegistering: Bool
    let revokingPasskeyID: String?
    let onAdd: () -> Void
    let onRemove: (PasskeyInfo) -> Void

    var body: some View {
        Section {
            if isLoading {
                HStack {
                    ProgressView()
                    Text(NSLocalizedString("settings.passkeys.loading", comment: "Loading passkeys label"))
                        .foregroundStyle(.secondary)
                }
            } else if passkeys.isEmpty {
                Text(NSLocalizedString("settings.passkeys.empty", comment: "No passkeys label"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(passkeys) { passkey in
                    PasskeyRow(
                        passkey: passkey,
                        isRevoking: revokingPasskeyID == passkey.id,
                        onRemove: { onRemove(passkey) }
                    )
                }
            }

            Button {
                onAdd()
            } label: {
                Label(NSLocalizedString("settings.passkeys.add", comment: "Add passkey button"), systemImage: "plus")
            }
            .disabled(isRegistering)
        } header: {
            Text(NSLocalizedString("settings.passkeys", comment: "Passkeys settings section header"))
        } footer: {
            Text(NSLocalizedString("settings.passkeys.footer", comment: "Passkeys settings footer"))
        }
    }
}

private struct PasskeyRow: View {
    let passkey: PasskeyInfo
    let isRevoking: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(passkey.name)
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isRevoking {
                ProgressView()
            } else {
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(NSLocalizedString("settings.passkeys.remove", comment: "Remove passkey accessibility label"))
            }
        }
    }

    private var detailText: String {
        if let lastUsed = passkey.lastUsed {
            return String(
                format: NSLocalizedString("settings.passkeys.lastUsed", comment: "Passkey last used label"),
                lastUsed
            )
        }
        return String(
            format: NSLocalizedString("settings.passkeys.created", comment: "Passkey created label"),
            passkey.created
        )
    }
}
