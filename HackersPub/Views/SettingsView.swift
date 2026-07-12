@preconcurrency import Apollo
import Kingfisher
import SwiftUI

protocol SettingsCacheBacking {
    func clearApolloCache() async throws
    func clearKingfisherMemoryCache()
    func clearKingfisherDiskCache() async
    func clearSharedURLCache()
    func cacheSize() async throws -> Int64
}

enum CacheClearResult: Equatable {
    case bestEffort(size: Int64)
    case failure(size: Int64?)
}

private enum SettingsCacheMeasurementError: Error {
    case documentsDirectoryUnavailable
}

struct SettingsCacheController {
    private let backing: any SettingsCacheBacking

    init(backing: any SettingsCacheBacking) {
        self.backing = backing
    }

    static let live = SettingsCacheController(backing: LiveSettingsCacheBacking())

    func cacheSize() async throws -> Int64 {
        try await backing.cacheSize()
    }

    func clearAndMeasure() async -> CacheClearResult {
        let clearedApolloCache: Bool
        do {
            try await backing.clearApolloCache()
            clearedApolloCache = true
        } catch {
            clearedApolloCache = false
        }

        backing.clearKingfisherMemoryCache()
        await backing.clearKingfisherDiskCache()
        backing.clearSharedURLCache()

        do {
            let size = try await backing.cacheSize()
            return clearedApolloCache ? .bestEffort(size: size) : .failure(size: size)
        } catch {
            return .failure(size: nil)
        }
    }
}

private struct LiveSettingsCacheBacking: SettingsCacheBacking {
    func clearApolloCache() async throws {
        try await apolloClient.clearCache()
    }

    func clearKingfisherMemoryCache() {
        KingfisherManager.shared.cache.clearMemoryCache()
    }

    func clearKingfisherDiskCache() async {
        await KingfisherManager.shared.cache.clearDiskCache()
    }

    func clearSharedURLCache() {
        URLCache.shared.removeAllCachedResponses()
    }

    func cacheSize() async throws -> Int64 {
        async let apolloCacheSize = Self.apolloSQLiteCacheSize()
        async let kingfisherCacheSize = Self.kingfisherDiskCacheSize()
        let urlCacheSize = Int64(URLCache.shared.currentDiskUsage)
        let apolloSize = try await apolloCacheSize
        let kingfisherSize = try await kingfisherCacheSize
        return apolloSize + kingfisherSize + urlCacheSize
    }

    private static func apolloSQLiteCacheSize() async throws -> Int64 {
        try await Task.detached(priority: .utility) { () throws -> Int64 in
            guard let documentsDirectory = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first else {
                throw SettingsCacheMeasurementError.documentsDirectoryUnavailable
            }

            let fileURL = documentsDirectory.appendingPathComponent(ApolloCacheConfiguration.fileName)
            return try ApolloSQLiteCacheMetric.physicalSize(at: fileURL)
        }.value
    }

    private static func kingfisherDiskCacheSize() async throws -> Int64 {
        let size = try await KingfisherManager.shared.cache.diskStorageSize
        return Int64(size)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @EnvironmentObject private var fontSettings: FontSettingsManager
    @State private var showingClearCacheAlert = false
    @State private var cacheClearCompleted = false
    @State private var isClearingCache = false
    @State private var cacheClearErrorMessage: String?
    @State private var cacheClearFeedbackGeneration = 0
    @State private var cacheSize: String = NSLocalizedString("settings.calculating", comment: "Cache size calculating")
    @State private var showingAddPasskeyAlert = false
    @State private var newPasskeyName = ""
    @State private var passkeyErrorMessage: String?
    @State private var passkeyPendingRevocation: PasskeyInfo?
    @State private var isRegisteringPasskey = false
    @State private var revokingPasskeyID: String?
    @State private var passkeyLoadTaskOwner = PasskeyTaskOwner()
    @State private var passkeyRegistrationTaskOwner = PasskeyTaskOwner()
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
    @AppStorage(MarkdownMaxLengthPreference.key)
    private var markdownMaxLength = MarkdownMaxLengthPreference.defaultValue
    @AppStorage("engagement.sharePressActionsSwapped") private var sharePressActionsSwapped = false
    @AppStorage("engagement.quotePressActionsSwapped") private var quotePressActionsSwapped = false
    @AppStorage("engagement.confirmBeforeShare") private var confirmBeforeShare = false
    @AppStorage("engagement.confirmBeforeDelete") private var confirmBeforeDelete = true
    @AppStorage(ExternalURLRouter.useInAppBrowserKey) private var useInAppBrowser = true
    private let cacheController = SettingsCacheController.live

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

    private let appIcons: [(name: String, displayNameKey: String)] = [
        ("Logo", "settings.appIcon.default"),
        ("Cry", "settings.appIcon.cry"),
        ("Curious", "settings.appIcon.curious"),
        ("Frown", "settings.appIcon.frown"),
        ("Wink", "settings.appIcon.wink")
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
                            if isClearingCache {
                                ProgressView()
                                    .accessibilityHidden(true)
                            } else if cacheClearCompleted {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.green)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .disabled(isClearingCache)
                    .accessibilityLabel(NSLocalizedString("settings.clearCache", comment: "Clear cache button"))
                    .accessibilityValue(cacheClearAccessibilityValue)
                } header: {
                    Text(NSLocalizedString("settings.cache", comment: "Cache section header"))
                }

                if authManager.isAuthenticated {
                    AuthenticatedSettingsSection(
                        passkeys: authManager.passkeys,
                        passkeysLoadError: authManager.passkeysLoadError,
                        isLoadingPasskeys: authManager.isLoadingPasskeys,
                        isRegisteringPasskey: isRegisteringPasskey,
                        revokingPasskeyID: revokingPasskeyID,
                        onAddPasskey: {
                            newPasskeyName = UIDevice.current.localizedModel
                            showingAddPasskeyAlert = true
                        },
                        onRemovePasskey: { passkey in
                            passkeyPendingRevocation = passkey
                        },
                        onRetryPasskeys: {
                            startPasskeyLoad()
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
                guard !Task.isCancelled, authManager.isAuthenticated else { return }
                startPasskeyLoad()
            }
            .onDisappear {
                cancelPasskeyTasks()
            }
        }
    }

    private var settingsAlerts: SettingsAlertsModifier {
        SettingsAlertsModifier(
            showingClearCacheAlert: $showingClearCacheAlert,
            cacheClearErrorMessage: $cacheClearErrorMessage,
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
                startPasskeyRegistration()
            },
            onRevokePasskey: { passkey in
                Task {
                    await revokePasskey(passkey)
                }
            }
        )
    }

    private func startPasskeyLoad() {
        passkeyLoadTaskOwner.start {
            await authManager.loadPasskeys()
        }
    }

    private func startPasskeyRegistration() {
        passkeyRegistrationTaskOwner.start {
            await registerPasskey()
        }
    }

    private func cancelPasskeyTasks() {
        passkeyLoadTaskOwner.cancel()
        passkeyRegistrationTaskOwner.cancel()
    }

    private func registerPasskey() async {
        let name = newPasskeyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        isRegisteringPasskey = true
        defer { isRegisteringPasskey = false }

        do {
            try await authManager.registerPasskey(name: name)
        } catch {
            guard !Task.isCancelled,
                  PasskeyAuthorizationErrorPolicy.shouldPresent(error)
            else { return }
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
        do {
            cacheSize = try formatBytes(await cacheController.cacheSize())
        } catch {
            cacheSize = NSLocalizedString("settings.cacheSize.unavailable", comment: "Cache size unavailable")
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func clearCache() async {
        guard !isClearingCache else { return }

        isClearingCache = true
        cacheClearCompleted = false
        cacheClearFeedbackGeneration += 1
        defer { isClearingCache = false }

        switch await cacheController.clearAndMeasure() {
        case let .bestEffort(size):
            cacheSize = formatBytes(size)
            cacheClearCompleted = true
            scheduleCacheClearFeedbackReset()
        case let .failure(size):
            if let size {
                cacheSize = formatBytes(size)
            } else {
                cacheSize = NSLocalizedString("settings.cacheSize.unavailable", comment: "Cache size unavailable")
            }
            cacheClearErrorMessage = NSLocalizedString(
                "settings.clearCache.error.message",
                comment: "Clear cache failure message"
            )
        }
    }

    private var cacheClearAccessibilityValue: String {
        if isClearingCache {
            return NSLocalizedString("settings.clearCache.clearing", comment: "Clear cache in progress")
        }
        if cacheClearCompleted {
            return NSLocalizedString("settings.clearCache.bestEffort", comment: "Best-effort cache clear completed")
        }
        return ""
    }

    private func scheduleCacheClearFeedbackReset() {
        cacheClearFeedbackGeneration += 1
        let generation = cacheClearFeedbackGeneration

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled, cacheClearFeedbackGeneration == generation else { return }
            cacheClearCompleted = false
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
        let appIcons: [(name: String, displayNameKey: String)]
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
                                                .stroke(
                                                    currentAppIcon == icon.name ? Color.blue : Color.clear,
                                                    lineWidth: 3
                                                )
                                        )

                                    Text(NSLocalizedString(icon.displayNameKey, comment: "App icon display name"))
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                }
                            }
                            .accessibilityAddTraits(currentAppIcon == icon.name ? .isSelected : [])
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
                        range: 0.75 ... 3.0
                    ),
                    in: 0.75 ... 3.0,
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
    @Binding var cacheClearErrorMessage: String?
    @Binding var showingAddPasskeyAlert: Bool
    @Binding var newPasskeyName: String
    @Binding var passkeyPendingRevocation: PasskeyInfo?
    @Binding var passkeyErrorMessage: String?

    let onClearCache: () -> Void
    let onRegisterPasskey: () -> Void
    let onRevokePasskey: (PasskeyInfo) -> Void

    // swiftlint:disable:next function_body_length
    func body(content: Content) -> some View {
        content
            .background {
                Color.clear
                    .alert(
                        NSLocalizedString(
                            "settings.clearCacheAlert.title",
                            comment: "Clear cache alert title"
                        ),
                        isPresented: $showingClearCacheAlert
                    ) {
                        Button(
                            NSLocalizedString(
                                "settings.clearCacheAlert.cancel",
                                comment: "Cancel button"
                            ),
                            role: .cancel
                        ) {}
                        Button(NSLocalizedString("settings.clearCacheAlert.clear", comment: "Clear button"), role: .destructive, action: onClearCache)
                    } message: {
                        Text(NSLocalizedString("settings.clearCacheAlert.message", comment: "Clear cache alert message"))
                    }
            }
            .background {
                Color.clear
                    .alert(
                        NSLocalizedString("settings.clearCache.error.title", comment: "Clear cache failure title"),
                        isPresented: cacheClearErrorAlertBinding
                    ) {
                        Button(
                            NSLocalizedString(
                                "settings.clearCache.error.dismiss",
                                comment: "Dismiss clear cache failure"
                            ),
                            role: .cancel
                        ) {
                            cacheClearErrorMessage = nil
                        }
                    } message: {
                        Text(cacheClearErrorMessage ?? "")
                    }
            }
            .background {
                Color.clear
                    .alert(NSLocalizedString("settings.passkeys.add", comment: "Add passkey alert title"), isPresented: $showingAddPasskeyAlert) {
                        TextField(NSLocalizedString("settings.passkeys.name", comment: "Passkey name field"), text: $newPasskeyName)
                        Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {}
                        Button(NSLocalizedString("settings.passkeys.add", comment: "Add passkey button"), action: onRegisterPasskey)
                            .disabled(newPasskeyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } message: {
                        Text(NSLocalizedString("settings.passkeys.addMessage", comment: "Add passkey message"))
                    }
            }
            .background {
                Color.clear
                    .alert(NSLocalizedString("settings.passkeys.remove", comment: "Remove passkey alert title"), isPresented: removePasskeyAlertBinding) {
                        Button(NSLocalizedString("common.cancel", comment: "Cancel"), role: .cancel) {}
                        Button(NSLocalizedString("settings.passkeys.remove", comment: "Remove passkey button"), role: .destructive) {
                            if let passkey = passkeyPendingRevocation {
                                onRevokePasskey(passkey)
                            }
                        }
                    } message: {
                        Text(removePasskeyMessage)
                    }
            }
            .background {
                Color.clear
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

    private var cacheClearErrorAlertBinding: Binding<Bool> {
        Binding(
            get: { cacheClearErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    cacheClearErrorMessage = nil
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
                        Text("300").tag(MarkdownMaxLengthPreference.defaultValue)
                        Text("500").tag(500)
                        Text("700").tag(700)
                        Text("1,000").tag(1000)
                        Text(NSLocalizedString("settings.timeline.unlimited", comment: "Unlimited option label"))
                            .tag(MarkdownMaxLengthPreference.unlimitedValue)
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
    let passkeysLoadError: String?
    let isLoadingPasskeys: Bool
    let isRegisteringPasskey: Bool
    let revokingPasskeyID: String?
    let onAddPasskey: () -> Void
    let onRemovePasskey: (PasskeyInfo) -> Void
    let onRetryPasskeys: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        PasskeysSettingsSection(
            passkeys: passkeys,
            loadError: passkeysLoadError,
            isLoading: isLoadingPasskeys,
            isRegistering: isRegisteringPasskey,
            revokingPasskeyID: revokingPasskeyID,
            onAdd: onAddPasskey,
            onRemove: onRemovePasskey,
            onRetry: onRetryPasskeys
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
    let loadError: String?
    let isLoading: Bool
    let isRegistering: Bool
    let revokingPasskeyID: String?
    let onAdd: () -> Void
    let onRemove: (PasskeyInfo) -> Void
    let onRetry: () -> Void

    var body: some View {
        Section {
            if isLoading {
                HStack {
                    ProgressView()
                    Text(NSLocalizedString("settings.passkeys.loading", comment: "Loading passkeys label"))
                        .foregroundStyle(.secondary)
                }
            } else {
                if let loadError {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(loadError, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                        Button(NSLocalizedString("common.retry", comment: "Retry button"), action: onRetry)
                    }
                }

                if passkeys.isEmpty {
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
