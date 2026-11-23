import AppKit

let svgPath = "/Users/elie/MenuBarLauncher/Sources/MenuBarLauncher/Resources/Logos/aternos.svg"
let basePath = "/Users/elie/MenuBarLauncher/Sources/MenuBarLauncher/Resources/Assets.xcassets/AternosLogo.imageset/aternos"

if let svgData = try? Data(contentsOf: URL(fileURLWithPath: svgPath)),
   let image = NSImage(data: svgData) {
    let sizes = [32, 64, 128]
    for size in sizes {
        let outputPath = "\(basePath)@\(size == 32 ? "1" : size == 64 ? "2" : "4")x.png"
        let resizedImage = NSImage(size: NSSize(width: size, height: size))
        resizedImage.lockFocus()
        image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        resizedImage.unlockFocus()

        if let tiffData = resizedImage.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            try? pngData.write(to: URL(fileURLWithPath: outputPath))
            print("Created \(outputPath)")
        }
    }
}