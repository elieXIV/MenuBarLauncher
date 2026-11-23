import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Binding var apps: [LauncherApp]
    @Environment(\.dismiss) var dismiss

    @State private var newAppName = ""
    @State private var newAppBundleId = ""
    @State private var newAppURL = ""
    @State private var newAppWebURL = ""
    @State private var newAppIcon = "app.fill"
    @State private var newAppColor = Color.blue
    @State private var showingAddSheet = false
    @State private var launchAtLogin = false
    @State private var showingInstalledAppsPicker = false
    @State private var installedApps: [InstalledApp] = []
    @State private var selectedInstalledApp: InstalledApp?
    @State private var recordingShortcut = false
    @State private var currentShortcut = Shortcut.defaultShortcut
    @State private var currentDisplayMode = DisplayMode.popover

    let commonIcons = [
        "app.fill", "music.note.list", "tv.fill", "message.fill",
        "terminal.fill", "safari.fill", "folder.fill", "chart.bar.fill",
        "gamecontroller.fill", "video.fill", "photo.fill", "doc.fill",
        "chevron.left.forwardslash.chevron.right", "server.rack",
        "cloud.fill", "lock.fill", "key.fill", "hammer.fill"
    ]

    let presetApps = LauncherApp.presetApps

    var body: some View {
        NavigationStack {
            List {
                // General section
                Section {
                    Toggle("Lancer au démarrage de la session", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, newValue in
                            toggleLaunchAtLogin(newValue)
                        }
                        .onAppear {
                            launchAtLogin = checkLaunchAtLoginStatus()
                        }

                    // Display mode picker
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "rectangle.on.rectangle")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text("Mode d'affichage")
                                .foregroundStyle(.primary)
                        }

                        Picker("Mode d'affichage", selection: $currentDisplayMode) {
                            ForEach(DisplayMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: currentDisplayMode) { _, newMode in
                            saveDisplayMode(newMode)
                        }

                        Text(currentDisplayMode == .popover
                            ? "Apparaît attaché à l'icône de la barre de menu"
                            : "Fenêtre indépendante, repositionnable, toujours au premier plan")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .onAppear {
                        if let modeString = UserDefaults.standard.string(forKey: "displayMode"),
                           let mode = DisplayMode(rawValue: modeString) {
                            currentDisplayMode = mode
                        }
                    }

                    // Restart app button
                    Button {
                        restartApp()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(.blue)
                                .frame(width: 20)
                            Text("Redémarrer l'application")
                        }
                    }
                    .buttonStyle(.plain)

                    // Keyboard shortcut
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "keyboard")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text("Raccourci global pour ouvrir le launcher")
                                .foregroundStyle(.primary)
                        }

                        ShortcutRecorder(
                            shortcut: $currentShortcut,
                            isRecording: $recordingShortcut,
                            onSave: saveShortcut
                        )

                        Text("Clique dans la zone ci-dessus et presse ta combinaison de touches")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                } header: {
                    Text("Général")
                }

                // Installed apps section
                Section {
                    ForEach(apps.sorted { $0.order < $1.order }) { app in
                        AppSettingsRow(app: app, apps: $apps)
                    }
                    .onMove { indices, newOffset in
                        apps.move(fromOffsets: indices, toOffset: newOffset)
                        updateOrder()
                    }
                    .onDelete { indexSet in
                        apps.remove(atOffsets: indexSet)
                        updateOrder()
                    }
                } header: {
                    Text("Vos apps (\(apps.count))")
                }

                // Quick add from installed apps
                Section("Ajouter depuis vos apps installées") {
                    Button {
                        loadInstalledApps()
                        showingInstalledAppsPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "square.grid.2x2.fill")
                                .foregroundStyle(.blue)
                                .frame(width: 20)
                            Text("Parcourir les apps installées")
                        }
                    }
                    .buttonStyle(.plain)
                }

                // Quick add presets
                Section("Presets rapides") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                        ForEach(presetApps) { preset in
                            PresetAppButton(
                                name: preset.name,
                                bundleId: preset.bundleIdentifier ?? "",
                                icon: preset.systemIcon,
                                color: preset.iconColor,
                                isAlreadyAdded: apps.contains { $0.bundleIdentifier == preset.bundleIdentifier },
                                action: { addPresetApp(preset) }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Custom app (manual entry)
                Section("App personnalisée (manuel)") {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Ajouter manuellement (nom, bundle ID, URLs...)", systemImage: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .navigationTitle("Réglages")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddCustomAppView(
                    apps: $apps,
                    name: $newAppName,
                    bundleId: $newAppBundleId,
                    url: $newAppURL,
                    webURL: $newAppWebURL,
                    icon: $newAppIcon,
                    color: $newAppColor,
                    icons: commonIcons
                )
            }
            .sheet(isPresented: $showingInstalledAppsPicker) {
                InstalledAppsPickerView(
                    installedApps: installedApps,
                    selectedApp: $selectedInstalledApp,
                    onAdd: { app in
                        addInstalledApp(app)
                        showingInstalledAppsPicker = false
                    }
                )
                .frame(width: 500, height: 600)
            }
        }
    }

    private func addPresetApp(_ preset: LauncherApp) {
        guard !apps.contains(where: { $0.bundleIdentifier == preset.bundleIdentifier }) else { return }
        var newApp = preset
        newApp.id = UUID()
        newApp.order = apps.count
        apps.append(newApp)
        updateOrder()
    }

    private func addInstalledApp(_ installedApp: InstalledApp) {
        guard !apps.contains(where: { $0.bundleIdentifier == installedApp.bundleIdentifier }) else { return }
        let newApp = LauncherApp(
            name: installedApp.name,
            bundleIdentifier: installedApp.bundleIdentifier,
            url: installedApp.urlScheme,
            webURL: installedApp.webURL,
            systemIcon: installedApp.systemIcon,
            iconColor: installedApp.iconColor,
            order: apps.count
        )
        apps.append(newApp)
        updateOrder()
    }

    private func loadInstalledApps() {
        installedApps = getInstalledApps()
    }

    private func getInstalledApps() -> [InstalledApp] {
        let workspace = NSWorkspace.shared
        let appsFolder = URL(fileURLWithPath: "/Applications")
        let fileManager = FileManager.default

        var installedApps: [InstalledApp] = []

        // Get apps from /Applications
        if let contents = try? fileManager.contentsOfDirectory(at: appsFolder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for url in contents where url.pathExtension == "app" {
                let bundle = Bundle(url: url)
                if let bundleId = bundle?.bundleIdentifier,
                   let name = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String ?? bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
                    let icon = workspace.icon(forFile: url.path)
                    icon.size = NSSize(width: 32, height: 32)

                    // Try to guess URL scheme and web URL
                    let (urlScheme, webURL, systemIcon, iconColor) = guessAppDetails(bundleId: bundleId, name: name)

                    installedApps.append(InstalledApp(
                        name: name,
                        bundleIdentifier: bundleId,
                        urlScheme: urlScheme,
                        webURL: webURL,
                        systemIcon: systemIcon,
                        iconColor: iconColor,
                        appIcon: icon
                    ))
                }
            }
        }

        // Also check ~/Applications
        let homeAppsFolder = URL(fileURLWithPath: NSHomeDirectory() + "/Applications")
        if let contents = try? fileManager.contentsOfDirectory(at: homeAppsFolder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for url in contents where url.pathExtension == "app" {
                let bundle = Bundle(url: url)
                if let bundleId = bundle?.bundleIdentifier,
                   let name = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String ?? bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
                    // Avoid duplicates
                    if !installedApps.contains(where: { $0.bundleIdentifier == bundleId }) {
                        let icon = workspace.icon(forFile: url.path)
                        icon.size = NSSize(width: 32, height: 32)
                        let (urlScheme, webURL, systemIcon, iconColor) = guessAppDetails(bundleId: bundleId, name: name)
                        installedApps.append(InstalledApp(
                            name: name,
                            bundleIdentifier: bundleId,
                            urlScheme: urlScheme,
                            webURL: webURL,
                            systemIcon: systemIcon,
                            iconColor: iconColor,
                            appIcon: icon
                        ))
                    }
                }
            }
        }

        return installedApps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func guessAppDetails(bundleId: String, name: String) -> (String?, String?, String, Color) {
        let lowerName = name.lowercased()
        let lowerBundle = bundleId.lowercased()

        // Known apps with URL schemes and web URLs
        let knownApps: [(bundleIds: [String], names: [String], urlScheme: String?, webURL: String?, icon: String, color: Color)] = [
            (["com.spotify.client"], ["spotify"], "spotify:", "https://open.spotify.com", "music.note.list", Color(hex: "1DB954")!),
            (["tv.twitch"], ["twitch"], "twitch:", "https://www.twitch.tv/directory", "tv.fill", Color(hex: "9146FF")!),
            (["com.hnc.Discord"], ["discord"], "discord:", "https://discord.com/app", "message.fill", Color(hex: "5865F2")!),
            (["com.microsoft.VSCode"], ["visual studio code", "vscode"], "vscode:", "https://github.com", "chevron.left.forwardslash.chevron.right", Color(hex: "007ACC")!),
            (["com.google.Chrome"], ["chrome", "google chrome"], nil, "https://www.google.com", "globe", Color(hex: "4285F4")!),
            (["org.mozilla.firefox"], ["firefox"], nil, "https://www.mozilla.org", "globe.americas.fill", Color(hex: "FF7139")!),
            (["com.tinyspeck.slackmacgap"], ["slack"], "slack:", "https://app.slack.com", "bubble.left.and.bubble.right.fill", Color(hex: "4A154B")!),
            (["notion.id"], ["notion"], "notion:", "https://notion.so", "doc.richtext.fill", Color(hex: "000000")!),
            (["com.figma.Desktop"], ["figma"], "figma:", "https://figma.com", "pencil.and.ruler.fill", Color(hex: "F24E1E")!),
            (["com.apple.dt.Xcode"], ["xcode"], nil, nil, "hammer.fill", Color(hex: "147EFB")!),
            (["com.apple.Terminal"], ["terminal"], nil, nil, "terminal.fill", Color(hex: "FF6B35")!),
            (["com.apple.Safari"], ["safari"], nil, nil, "safari.fill", Color(hex: "00A1E4")!),
            (["com.apple.finder"], ["finder"], nil, nil, "folder.fill", Color(hex: "007AFF")!),
            (["com.apple.ActivityMonitor"], ["activity monitor", "moniteur d'activité"], nil, nil, "chart.bar.fill", Color(hex: "FF3B30")!),
            (["net.whatsapp.WhatsApp", "com.whatsapp"], ["whatsapp"], "whatsapp:", "https://web.whatsapp.com/", "message.fill", Color(hex: "25D366")!),
        ]

        for app in knownApps {
            if app.bundleIds.contains(lowerBundle) || app.names.contains(where: { lowerName.contains($0) }) {
                return (app.urlScheme, app.webURL, app.icon, app.color)
            }
        }

        // Default generic
        return (nil, nil, "app.fill", .blue)
    }

    private func updateOrder() {
        for (index, _) in apps.enumerated() {
            apps[index].order = index
        }
    }

    private func checkLaunchAtLoginStatus() -> Bool {
        #if os(macOS)
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        #endif
        return false
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        #if os(macOS)
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to toggle launch at login: \(error)")
                DispatchQueue.main.async {
                    self.launchAtLogin = !enabled
                }
            }
        }
        #endif
    }

    private func restartApp() {
        let appPath = "/Users/elie/MenuBarLauncher/.build/MenuBarLauncher.app"
        let script = """
        do shell script "pkill -f 'MenuBarLauncher'; sleep 0.5; open '\(appPath)'"
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error = error {
                print("Restart failed: \(error)")
            }
        }
        dismiss()
    }

    private func saveShortcut(_ shortcut: Shortcut) {
        UserDefaults.standard.set(shortcut.keyCode, forKey: "globalShortcutKeyCode")
        UserDefaults.standard.set(shortcut.modifiers.rawValue, forKey: "globalShortcutModifiers")
        // Notify AppDelegate to update the monitor
        NotificationCenter.default.post(name: .shortcutChanged, object: shortcut)
    }

    private func saveDisplayMode(_ mode: DisplayMode) {
        print("🔄 SettingsView.saveDisplayMode called: \(mode)")
        UserDefaults.standard.set(mode.rawValue, forKey: "displayMode")
        print("🔄 Posting displayModeChanged notification")
        NotificationCenter.default.post(name: .displayModeChanged, object: mode)
        print("🔄 Notification posted")
    }
}

struct InstalledApp: Identifiable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let urlScheme: String?
    let webURL: String?
    let systemIcon: String
    let iconColor: Color
    let appIcon: NSImage
}

// ShortcutRecorder using NSEvent for proper keyCode capture
struct ShortcutRecorder: View {
    @Binding var shortcut: Shortcut
    @Binding var isRecording: Bool
    var onSave: (Shortcut) -> Void
    @State private var localMonitor: Any?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(isRecording ? Color.blue.opacity(0.15) : Color.primary.opacity(0.05))
                .stroke(isRecording ? Color.blue : Color.secondary.opacity(0.3), lineWidth: isRecording ? 2 : 1)

            HStack {
                Text(shortcut.displayString)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(isRecording ? .blue : .primary)

                if isRecording {
                    Image(systemName: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .symbolEffect(.pulse)
                }

                Spacer()

                Image(systemName: "keyboard")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(height: 44)
        .contentShape(Rectangle())
        .onTapGesture {
            startRecording()
        }
        .onAppear {
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
                localMonitor = nil
            }
        }
        .onDisappear {
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
                localMonitor = nil
            }
        }
    }

    private func startRecording() {
        isRecording = true

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])

            if !modifiers.isEmpty {
                let newShortcut = Shortcut(keyCode: event.keyCode, modifiers: modifiers)
                DispatchQueue.main.async {
                    self.shortcut = newShortcut
                    self.isRecording = false
                    self.onSave(newShortcut)
                }
                return nil
            }
            return event
        }
    }
}

struct InstalledAppsPickerView: View {
    let installedApps: [InstalledApp]
    @Binding var selectedApp: InstalledApp?
    let onAdd: (InstalledApp) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""

    var filteredApps: [InstalledApp] {
        if searchText.isEmpty {
            return installedApps
        }
        return installedApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                    TextField("Rechercher une app...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(12)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Divider()

                // List
                List(filteredApps) { app in
                    HStack(spacing: 12) {
                        Image(nsImage: app.appIcon)
                            .resizable()
                            .frame(width: 32, height: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .font(.system(size: 14, weight: .medium))
                            Text(app.bundleIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if app.urlScheme != nil || app.webURL != nil {
                            Image(systemName: "tv.fill")
                                .font(.caption)
                                .foregroundStyle(app.iconColor)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onAdd(app)
                    }
                }
            }
            .navigationTitle("Apps installées (\(installedApps.count))")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }
}

struct AppSettingsRow: View {
    let app: LauncherApp
    @Binding var apps: [LauncherApp]

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: app.systemIcon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(app.iconColor)
                .frame(width: 28, height: 28)
                .background(app.iconColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 14, weight: .medium))
                if let bundleId = app.bundleIdentifier {
                    Text(bundleId)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let url = app.url {
                    Text(url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if app.hasWebView {
                Image(systemName: "tv.fill")
                    .font(.caption)
                    .foregroundStyle(app.iconColor)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                if let index = apps.firstIndex(where: { $0.id == app.id }) {
                    apps.remove(at: index)
                }
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }
}

struct PresetAppButton: View {
    let name: String
    let bundleId: String
    let icon: String
    let color: Color
    let isAlreadyAdded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(isAlreadyAdded ? .secondary : color)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isAlreadyAdded ? Color.secondary.opacity(0.1) : color.opacity(0.15))
                    )

                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isAlreadyAdded ? .secondary : .primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isAlreadyAdded ? Color.secondary.opacity(0.3) : color.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isAlreadyAdded)
        .opacity(isAlreadyAdded ? 0.6 : 1)
    }
}

struct AddCustomAppView: View {
    @Binding var apps: [LauncherApp]
    @Binding var name: String
    @Binding var bundleId: String
    @Binding var url: String
    @Binding var webURL: String
    @Binding var icon: String
    @Binding var color: Color
    let icons: [String]

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Informations") {
                    TextField("Nom de l'app", text: $name)

                    TextField("Identifiant de bundle (ex: com.apple.Safari)", text: $bundleId)

                    TextField("URL Scheme (ex: spotify:, twitch:)", text: $url)

                    TextField("URL Web (ex: https://twitch.tv)", text: $webURL)
                }

                Section("Icône") {
                    Picker("Symbole", selection: $icon) {
                        ForEach(icons, id: \.self) { symbol in
                            Label(symbol, systemImage: symbol)
                                .tag(symbol)
                        }
                    }
                    .pickerStyle(.menu)

                    ColorPicker("Couleur", selection: $color)
                }
            }
            .navigationTitle("Nouvelle app")
            .frame(width: 450, height: 500)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        let newApp = LauncherApp(
                            name: name,
                            bundleIdentifier: bundleId.isEmpty ? nil : bundleId,
                            url: url.isEmpty ? nil : url,
                            webURL: webURL.isEmpty ? nil : webURL,
                            systemIcon: icon,
                            iconColor: color,
                            order: apps.count
                        )
                        apps.append(newApp)
                        dismiss()
                    }
                    .disabled(name.isEmpty || (bundleId.isEmpty && url.isEmpty && webURL.isEmpty))
                }
            }
        }
    }
}