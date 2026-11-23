import Foundation
import SwiftUI
import AppKit

struct LauncherApp: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var bundleIdentifier: String?
    var url: String?
    var webURL: String?
    var systemIcon: String
    var iconColorHex: String
    var order: Int
    var lastLaunchedAt: Date?
    var launchCount: Int
    var customLogoName: String?

    init(id: UUID = UUID(),
         name: String,
         bundleIdentifier: String? = nil,
         url: String? = nil,
         webURL: String? = nil,
         systemIcon: String,
         iconColor: Color = .blue,
         order: Int = 0,
         lastLaunchedAt: Date? = nil,
         launchCount: Int = 0,
         customLogoName: String? = nil) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.url = url
        self.webURL = webURL
        self.systemIcon = systemIcon
        self.iconColorHex = iconColor.toHex()
        self.order = order
        self.lastLaunchedAt = lastLaunchedAt
        self.launchCount = launchCount
        self.customLogoName = customLogoName
    }

    var iconColor: Color {
        Color(hex: iconColorHex) ?? .blue
    }

    var icon: NSImage? {
        // First try custom logo from bundle
        if let customLogoName = customLogoName,
           let customImage = NSImage(named: customLogoName) {
            let resized = NSImage(size: NSSize(width: 28, height: 28))
            resized.lockFocus()
            customImage.draw(in: NSRect(x: 0, y: 0, width: 28, height: 28),
                           from: NSRect(origin: .zero, size: customImage.size),
                           operation: .sourceOver,
                           fraction: 1.0)
            resized.unlockFocus()
            return resized
        }

        // Then try app icon from bundle identifier
        guard let bundleId = bundleIdentifier,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        let image = NSWorkspace.shared.icon(forFile: appURL.path)
        image.size = NSSize(width: 28, height: 28)
        return image
    }

    var hasWebView: Bool {
        webURL != nil && !webURL!.isEmpty
    }

    static let defaultApps: [LauncherApp] = [
        LauncherApp(
            name: "Spotify",
            bundleIdentifier: "com.spotify.client",
            url: "spotify:",
            webURL: "https://open.spotify.com/embed/playlist/66CO0WhYSikX1YVMCNzoBw",
            systemIcon: "music.note.list",
            iconColor: Color(hex: "1DB954")!,
            order: 0
        ),
        LauncherApp(
            name: "Twitch",
            bundleIdentifier: "tv.twitch",
            url: "twitch:",
            webURL: "https://www.twitch.tv/directory",
            systemIcon: "tv.fill",
            iconColor: Color(hex: "9146FF")!,
            order: 1
        ),
        LauncherApp(
            name: "YouTube",
            bundleIdentifier: "com.google.Chrome",
            url: "https://www.youtube.com",
            webURL: "https://www.youtube.com",
            systemIcon: "play.rectangle.fill",
            iconColor: Color(hex: "FF0000")!,
            order: 2,
            customLogoName: "YouTubeLogo"
        ),
        LauncherApp(
            name: "Aternos",
            bundleIdentifier: "com.google.Chrome",
            url: "https://aternos.org",
            webURL: "https://aternos.org/server/",
            systemIcon: "server.rack",
            iconColor: Color(hex: "00A86B")!,
            order: 3,
            customLogoName: "AternosLogo"
        ),
    ]

    // Common preset apps for quick adding
    static let presetApps: [LauncherApp] = [
        LauncherApp(name: "Spotify", bundleIdentifier: "com.spotify.client", url: "spotify:", webURL: "https://open.spotify.com/embed/playlist/66CO0WhYSikX1YVMCNzoBw", systemIcon: "music.note.list", iconColor: Color(hex: "1DB954")!, order: 0),
        LauncherApp(name: "Twitch", bundleIdentifier: "tv.twitch", url: "twitch:", webURL: "https://www.twitch.tv/directory", systemIcon: "tv.fill", iconColor: Color(hex: "9146FF")!, order: 1),
        LauncherApp(name: "YouTube", bundleIdentifier: "com.google.Chrome", url: "https://www.youtube.com", webURL: "https://www.youtube.com", systemIcon: "play.rectangle.fill", iconColor: Color(hex: "FF0000")!, order: 2, customLogoName: "YouTubeLogo"),
        LauncherApp(name: "Aternos", bundleIdentifier: "com.google.Chrome", url: "https://aternos.org", webURL: "https://aternos.org/server/", systemIcon: "server.rack", iconColor: Color(hex: "00A86B")!, order: 3, customLogoName: "AternosLogo"),
        LauncherApp(name: "Discord", bundleIdentifier: "com.hnc.Discord", url: "discord:", webURL: "https://discord.com/app", systemIcon: "message.fill", iconColor: Color(hex: "5865F2")!, order: 4),
        LauncherApp(name: "VS Code", bundleIdentifier: "com.microsoft.VSCode", url: "vscode:", webURL: "https://github.com", systemIcon: "chevron.left.forwardslash.chevron.right", iconColor: Color(hex: "007ACC")!, order: 5),
        LauncherApp(name: "Terminal", bundleIdentifier: "com.apple.Terminal", url: nil, webURL: nil, systemIcon: "terminal.fill", iconColor: Color(hex: "FF6B35")!, order: 6),
        LauncherApp(name: "Safari", bundleIdentifier: "com.apple.Safari", url: nil, webURL: nil, systemIcon: "safari.fill", iconColor: Color(hex: "00A1E4")!, order: 7),
        LauncherApp(name: "Finder", bundleIdentifier: "com.apple.finder", url: nil, webURL: nil, systemIcon: "folder.fill", iconColor: Color(hex: "007AFF")!, order: 8),
        LauncherApp(name: "Chrome", bundleIdentifier: "com.google.Chrome", url: nil, webURL: nil, systemIcon: "globe", iconColor: Color(hex: "4285F4")!, order: 9),
        LauncherApp(name: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap", url: "slack:", webURL: "https://app.slack.com", systemIcon: "bubble.left.and.bubble.right.fill", iconColor: Color(hex: "4A154B")!, order: 10),
        LauncherApp(name: "Notion", bundleIdentifier: "notion.id", url: "notion:", webURL: "https://notion.so", systemIcon: "doc.richtext.fill", iconColor: Color(hex: "000000")!, order: 11),
        LauncherApp(name: "Figma", bundleIdentifier: "com.figma.Desktop", url: "figma:", webURL: "https://figma.com", systemIcon: "pencil.and.ruler.fill", iconColor: Color(hex: "F24E1E")!, order: 12),
        LauncherApp(name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode", url: nil, webURL: nil, systemIcon: "hammer.fill", iconColor: Color(hex: "147EFB")!, order: 13),
        LauncherApp(name: "WhatsApp", bundleIdentifier: "net.whatsapp.WhatsApp", url: "whatsapp:", webURL: "https://web.whatsapp.com/", systemIcon: "message.fill", iconColor: Color(hex: "25D366")!, order: 14),
    ]
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: return nil
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }

    func toHex() -> String {
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else { return "0000FF" }
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}