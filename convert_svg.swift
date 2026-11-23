import AppKit

let svgPath = "/Users/elie/MenuBarLauncher/Sources/MenuBarLauncher/Resources/Logos/youtube.svg"
let pngPath = "/Users/elie/MenuBarLauncher/Sources/MenuBarLauncher/Resources/Logos/youtube.png"

if let svgData = try? Data(contentsOf: URL(fileURLWithPath: svgPath)),
   let image = NSImage(data: svgData) {
    // Create a larger representation
    let sizes = [32, 64, 128, 256]
    for size in sizes {
        let outputPath = pngPath.replacingOccurrences(of: ".png", with: "@\(size)x.png")
        if let bitmap = image.representations.first as? NSBitmapImageRep {
            bitmap.size = NSSize(width: size, height: size)
        }
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
    
    // Also create a standard one
    if let tiffData = image.tiffRepresentation,
       let bitmapRep = NSBitmapImageRep(data: tiffData),
       let pngData = bitmapRep.representation(using: .png, properties: [:]) {
        try? pngData.write(to: URL(fileURLWithPath: pngPath))
        print("Created \(pngPath)")
    }
}
