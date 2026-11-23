import SwiftUI
import WebKit

struct LauncherView: View {
    @State private var apps: [LauncherApp] = []
    @State private var showingSettings = false
    @State private var searchText = ""
    @State private var expandedWebApp: LauncherApp?
    @State private var webViewHeight: CGFloat = 400
    @State private var webViewWidth: CGFloat = 360
    @FocusState private var isSearchFocused: Bool

    private let appsStorageKey = "savedLauncherApps"

    var filteredApps: [LauncherApp] {
        if searchText.isEmpty {
            return apps
        }
        return apps.filter { app in
            app.name.localizedCaseInsensitiveContains(searchText) ||
            (app.bundleIdentifier?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var recentApps: [LauncherApp] {
        apps
            .filter { $0.lastLaunchedAt != nil }
            .sorted { ($0.lastLaunchedAt ?? .distantPast) > ($1.lastLaunchedAt ?? .distantPast) }
            .prefix(3)
            .map { $0 }
    }

    var otherApps: [LauncherApp] {
        let recentIds = Set(recentApps.map { $0.id })
        return filteredApps.filter { !recentIds.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with search
            VStack(spacing: 8) {
                HStack {
                    Text("Quick Launch")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Réglages")
                }

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 14))

                    TextField("Rechercher...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .focused($isSearchFocused)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isSearchFocused = true
                            }
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)

            Divider()

            // Content: either app list or web view
            if let webApp = expandedWebApp {
                // Inline Web View
                InlineWebView(
                    app: webApp,
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedWebApp = nil
                        }
                    },
                    webViewHeight: $webViewHeight,
                    webViewWidth: $webViewWidth
                )
                .frame(width: webViewWidth, height: webViewHeight)
            } else {
                // App List
                ScrollView {
                    LazyVStack(spacing: 4) {
                        // Recent section
                        if !recentApps.isEmpty && searchText.isEmpty {
                            SectionHeader(title: "Récents")
                            ForEach(recentApps) { app in
                                AppRowView(
                                    app: app,
                                    onWebView: { openWebViewInline(app) }
                                )
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                            }
                            Divider().padding(.horizontal, 8).padding(.vertical, 4)
                        }

                        // Other apps
                        SectionHeader(title: searchText.isEmpty ? "Applications" : "Résultats")
                        ForEach(otherApps) { app in
                            AppRowView(
                                app: app,
                                onWebView: { openWebViewInline(app) }
                            )
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                        }

                        if otherApps.isEmpty && recentApps.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.tertiary)
                                Text(searchText.isEmpty ? "Aucune app" : "Aucun résultat")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 300)
            }

            Divider()

            // Footer
            HStack {
                Button("Quitter") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)

                Spacer()

                Text("\(apps.count) apps")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)
        }
        .frame(width: expandedWebApp != nil ? webViewWidth : 360, height: expandedWebApp != nil ? webViewHeight : 420)
        .background(.regularMaterial)
        .sheet(isPresented: $showingSettings) {
            SettingsView(apps: $apps)
                .frame(width: 400, height: 500)
        }
        .animation(.easeInOut(duration: 0.2), value: expandedWebApp)
        .animation(.easeInOut(duration: 0.15), value: webViewHeight)
        .animation(.easeInOut(duration: 0.15), value: webViewWidth)
        .onChange(of: apps) { _, _ in
            saveApps()
        }
        .onChange(of: webViewHeight) { _, newHeight in
            if expandedWebApp != nil {
                NotificationCenter.default.post(name: .webViewHeightChanged, object: newHeight)
            }
        }
        .onChange(of: webViewWidth) { _, newWidth in
            if expandedWebApp != nil {
                NotificationCenter.default.post(name: .webViewWidthChanged, object: newWidth)
            }
        }
        .onAppear {
            loadApps()
            setupKeyboardShortcut()
        }
    }

    private func launchApp(_ app: LauncherApp) {
        var updatedApp = app
        updatedApp.lastLaunchedAt = Date()
        updatedApp.launchCount += 1
        if let index = apps.firstIndex(where: { $0.id == app.id }) {
            apps[index] = updatedApp
            saveApps()
        }

        let isAppInstalled = app.bundleIdentifier != nil &&
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier!) != nil

        if isAppInstalled {
            if let urlString = app.url, let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
                return
            }

            if let bundleId = app.bundleIdentifier,
               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, _ in }
            }
        } else if let webURL = app.webURL, let url = URL(string: webURL) {
            NSWorkspace.shared.open(url)
        }
    }

    private func openWebViewInline(_ app: LauncherApp) {
        guard app.hasWebView else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedWebApp = app
        }
    }

    private func setupKeyboardShortcut() {
        // Handled by AppDelegate
    }

    private func loadApps() {
        if let data = UserDefaults.standard.data(forKey: appsStorageKey),
           let decoded = try? JSONDecoder().decode([LauncherApp].self, from: data) {
            apps = decoded
        } else {
            apps = LauncherApp.defaultApps
            saveApps() // Save defaults on first launch
        }
    }

    private func saveApps() {
        if let encoded = try? JSONEncoder().encode(apps) {
            UserDefaults.standard.set(encoded, forKey: appsStorageKey)
        }
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

struct AppRowView: View {
    let app: LauncherApp
    let onWebView: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // App icon
            Group {
                if let nsImage = app.icon {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: app.systemIcon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(app.iconColor)
                }
            }
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(app.iconColor.opacity(0.15))
            )

            // App info
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let bundleId = app.bundleIdentifier {
                    Text(bundleId)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Web view indicator
            if app.hasWebView {
                Image(systemName: "tv.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(app.iconColor.opacity(0.6))
            }

            // Launch indicator
            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .opacity(isHovered ? 1 : 0.5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onWebView)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            if app.hasWebView {
                Button("Vue web intégrée") { onWebView() }
                Divider()
            }
            if let urlString = app.url, let url = URL(string: urlString) {
                Button("Lancer l'app native") {
                    NSWorkspace.shared.open(url)
                }
            }
            if let bundleId = app.bundleIdentifier,
               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                Button("Lancer via bundle ID") {
                    let config = NSWorkspace.OpenConfiguration()
                    NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, _ in }
                }
            }
        }
    }
}

struct InlineWebView: View {
    let app: LauncherApp
    let onClose: () -> Void
    @Binding var webViewHeight: CGFloat
    @Binding var webViewWidth: CGFloat
    @State private var webView: WKWebView?
    @State private var isLoading = true
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var currentURL: String = ""
    @State private var isDragging = false
    @State private var dragType: DragType = .none

    private let minHeight: CGFloat = 300
    private let maxHeight: CGFloat = 800
    private let minWidth: CGFloat = 360
    private let maxWidth: CGFloat = 1200

    enum DragType {
        case none, vertical, horizontal, corner
    }

    var body: some View {
        VStack(spacing: 0) {
            // Compact toolbar
            HStack(spacing: 8) {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Fermer la vue web")

                Divider().frame(height: 16)

                Button {
                    if canGoBack { webView?.goBack() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .disabled(!canGoBack)
                .help("Précédent")

                Button {
                    if canGoForward { webView?.goForward() }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .disabled(!canGoForward)
                .help("Suivant")

                Button {
                    webView?.reload()
                } label: {
                    Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .help(isLoading ? "Annuler" : "Actualiser")

                Divider().frame(height: 16)

                HStack(spacing: 6) {
                    Image(systemName: app.systemIcon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(app.iconColor)
                    Text(app.name)
                        .font(.system(size: 13, weight: .medium))
                }

                Spacer()

                // URL display
                Text(currentURL.isEmpty ? (app.webURL ?? "") : currentURL)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .frame(maxWidth: 180)
                    .truncationMode(.middle)

                Spacer()

                // Width toggle button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        webViewWidth = webViewWidth > 600 ? 360 : 800
                    }
                } label: {
                    Image(systemName: webViewWidth > 600 ? "arrow.left.and.right" : "arrow.left.and.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(webViewWidth > 600 ? "Réduire largeur" : "Élargir")

                // Height toggle button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        webViewHeight = webViewHeight > 500 ? 400 : 700
                    }
                } label: {
                    Image(systemName: webViewHeight > 500 ? "arrow.up.and.down" : "arrow.up.and.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(webViewHeight > 500 ? "Réduire hauteur" : "Agrandir hauteur")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial)

            Divider()

            // Web View with horizontal resize handle
            HStack(spacing: 0) {
                ZStack {
                    WebViewRepresentable(
                        url: app.webURL ?? "",
                        webView: $webView,
                        isLoading: $isLoading,
                        canGoBack: $canGoBack,
                        canGoForward: $canGoForward,
                        currentURL: $currentURL
                    )

                    if isLoading {
                        VStack(spacing: 10) {
                            ProgressView()
                                .scaleEffect(1.0)
                        Text("Chargement de \(app.name)...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.regularMaterial)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Horizontal resize handle (right edge)
            Rectangle()
                .fill(Color.clear)
                .frame(width: 8)
                .contentShape(Rectangle())
                .overlay(
                    Image(systemName: "line.3.vertical")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newWidth = webViewWidth + value.translation.width
                            webViewWidth = min(max(newWidth, minWidth), maxWidth)
                            isDragging = true
                            dragType = .horizontal
                        }
                        .onEnded { _ in
                            isDragging = false
                            dragType = .none
                        }
                )
                .onHover { hovering in
                    if hovering || (isDragging && dragType == .horizontal) {
                        NSCursor.resizeLeftRight.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
        }
        // Bottom resize area with corner
        HStack(spacing: 0) {
            // Bottom edge (vertical resize)
            Rectangle()
                .fill(Color.clear)
                .frame(height: 8)
                .contentShape(Rectangle())
                .overlay(
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newHeight = webViewHeight - value.translation.height
                            webViewHeight = min(max(newHeight, minHeight), maxHeight)
                            isDragging = true
                            dragType = .vertical
                        }
                        .onEnded { _ in
                            isDragging = false
                            dragType = .none
                        }
                )
                .onHover { hovering in
                    if hovering || (isDragging && dragType == .vertical) {
                        NSCursor.resizeUpDown.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }

            // Bottom-right corner (diagonal resize)
            Rectangle()
                .fill(Color.clear)
                .frame(width: 8, height: 8)
                .contentShape(Rectangle())
                .overlay(
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newWidth = webViewWidth + value.translation.width
                            let newHeight = webViewHeight - value.translation.height
                            webViewWidth = min(max(newWidth, minWidth), maxWidth)
                            webViewHeight = min(max(newHeight, minHeight), maxHeight)
                            isDragging = true
                            dragType = .corner
                        }
                        .onEnded { _ in
                            isDragging = false
                            dragType = .none
                        }
                )
                .onHover { hovering in
                    if hovering || (isDragging && dragType == .corner) {
                        NSCursor.resizeUpDown.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
        }
    }
}

struct WebViewRepresentable: NSViewRepresentable {
    let url: String
    @Binding var webView: WKWebView?
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var currentURL: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // Enable fullscreen video support
        if #available(macOS 12.0, *) {
            config.preferences.isElementFullscreenEnabled = true
        }

        // Additional settings for WhatsApp Web compatibility
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        // Allow third-party cookies (needed for WhatsApp Web)
        if #available(macOS 11.0, *) {
            config.websiteDataStore = WKWebsiteDataStore.default()
            config.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                // Cookies will be shared with default store
            }
        }

        let wkWebView = WKWebView(frame: .zero, configuration: config)
        wkWebView.navigationDelegate = context.coordinator
        wkWebView.uiDelegate = context.coordinator

        // Allow mixed content and third-party cookies
        if #available(macOS 10.15, *) {
            wkWebView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"
        }

        if let url = URL(string: url) {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
            wkWebView.load(request)
        }

        DispatchQueue.main.async {
            self.webView = wkWebView
        }

        return wkWebView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        canGoBack = nsView.canGoBack
        canGoForward = nsView.canGoForward
        currentURL = nsView.url?.absoluteString ?? ""
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: WebViewRepresentable

        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
                self.parent.currentURL = webView.url?.absoluteString ?? ""
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
                self.parent.currentURL = webView.url?.absoluteString ?? ""
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        // Handle media capture permission requests (microphone/camera for WebRTC)
        func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            print("🎤 Media capture permission requested: \(type) for \(origin.host ?? "unknown")")
            // Grant permission for microphone and camera
            if type == .microphone || type == .camera || type == .cameraAndMicrophone {
                decisionHandler(.grant)
            } else {
                decisionHandler(.deny)
            }
        }

        // Handle permission state changes
        @available(macOS 10.15, *)
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
            // Allow JavaScript and media capture
            preferences.allowsContentJavaScript = true
            decisionHandler(.allow, preferences)
        }
    }
}
}