import AppKit

// Run from the repository root with an Xcode installation containing Icon Composer.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let icon = root.appendingPathComponent("Sources/NornaStudio/Resources/NornaSculpted.icon")
let assets = root.appendingPathComponent("build/Branding/AppIcon", isDirectory: true)
let iconset = assets.appendingPathComponent("Norna-LiquidGlass.iconset", isDirectory: true)
let designGeneration = CommandLine.arguments.dropFirst().first ?? (ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 ? "27" : "26")
precondition(["26", "27"].contains(designGeneration), "Design generation must be 26 or 27.")
let tool = "/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let run: (String, [String]) throws -> Void = { executable, arguments in
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw NSError(domain: "NornaIcon", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Icon rendering failed."])
    }
}
let render: (String, URL, Int, Int) throws -> Void = { appearance, destination, size, scale in
    try run(tool, [icon.path, "--export-image", "--output-file", destination.path, "--platform", "macOS",
        "--rendition", appearance, "--width", String(size), "--height", String(size), "--scale", String(scale), "--design-generation", designGeneration])
}
let appearances = [("Default", "亮色"), ("Dark", "暗色"), ("ClearLight", "透明亮色"),
                   ("ClearDark", "透明暗色"), ("TintedLight", "染色亮色"), ("TintedDark", "染色暗色")]
for (appearance, _) in appearances {
    try render(appearance, assets.appendingPathComponent("norna-icon-\(appearance).png"), 512, 1)
}
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        try render("Default", iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"), size, scale)
    }
}
try render("Default", assets.appendingPathComponent("norna-liquid-glass.png"), 1024, 1)
try run("/usr/bin/iconutil", ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Sources/NornaStudio/Resources/Norna.icns").path])

// Contact sheet only; each icon is an unmodified native macOS rendition.
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1200, pixelsHigh: 780,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: 1200, height: 780).fill()
("Norna Studio · macOS \(designGeneration)" as NSString).draw(at: NSPoint(x: 48, y: 712), withAttributes: [
    .font: NSFont.systemFont(ofSize: 26, weight: .semibold), .foregroundColor: NSColor.black])
for (index, item) in appearances.enumerated() {
    let column = index % 3, row = index / 3
    let x = CGFloat(column * 384 + 80), y = CGFloat(394 - row * 336)
    let image = NSImage(contentsOf: assets.appendingPathComponent("norna-icon-\(item.0).png"))!
    image.draw(in: NSRect(x: x, y: y + 32, width: 256, height: 256))
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    (item.1 as NSString).draw(in: NSRect(x: x, y: y, width: 256, height: 26), withAttributes: [
        .font: NSFont.systemFont(ofSize: 19, weight: .medium), .foregroundColor: NSColor.black, .paragraphStyle: paragraph])
}
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("build/Branding/macos-icon-appearances.png"))
print("Rendered six native macOS appearances, the compatibility icon, and the contact sheet.")
