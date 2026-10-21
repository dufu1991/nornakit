import AppKit
import ImageIO

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let source = root.appendingPathComponent("Branding", isDirectory: true)
let output = root.appendingPathComponent("build/Branding/IconSystem", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let read: (String) throws -> String = { try String(contentsOf: source.appendingPathComponent($0), encoding: .utf8) }
let write: (String, String) throws -> Void = { name, contents in
    try contents.write(to: output.appendingPathComponent(name), atomically: true, encoding: .utf8)
}
let symbol = try read("symbol.svg")
let mono = try read("symbol-mono.svg")
let favicon = try read("favicon.svg")
try write("symbol.svg", symbol)
try write("symbol-dark.svg", symbol.replacingOccurrences(of: "#5148d8", with: "#aaa4ff"))
try write("symbol-mono.svg", mono)
try write("favicon.svg", favicon)
try write("safari-pinned-tab.svg", mono.replacingOccurrences(of: "currentColor", with: "#000"))
try write("README.md", try read("README.md"))

let image: (String) -> NSImage = { NSImage(data: Data($0.utf8))! }
let bitmap: (Int, Int) -> NSBitmapImageRep = { width, height in
    NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
}
let paint: (NSBitmapImageRep, () -> Void) -> Void = { canvas, body in
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: canvas)
    NSGraphicsContext.current?.imageInterpolation = .high
    body()
    NSGraphicsContext.restoreGraphicsState()
}
let save: (NSBitmapImageRep, String) throws -> Void = { canvas, name in
    try canvas.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
}
let raster: (NSImage, Int, String) throws -> Void = { artwork, size, name in
    let canvas = bitmap(size, size)
    paint(canvas) { artwork.draw(in: NSRect(x: 0, y: 0, width: size, height: size)) }
    try save(canvas, name)
}

// Fixed light appearance for PNG and ICO. Adaptive appearance stays in the SVG.
let fixedFavicon = favicon.replacingOccurrences(of: "@media(prefers-color-scheme:dark){.tile{fill:#aaa4ff}.mark{fill:#171719;stroke:#171719}}", with: "")
let sizes = [16, 32, 48, 64, 128, 256]
for size in sizes { try raster(image(fixedFavicon), size, "favicon-\(size).png") }
for size in [32, 128, 512] { try raster(image(symbol), size, "symbol-\(size).png") }

// A standard ICO directory containing independent native-size PNG frames.
var ico = Data()
let append16: (UInt16) -> Void = { value in var value = value.littleEndian; withUnsafeBytes(of: &value) { ico.append(contentsOf: $0) } }
let append32: (UInt32) -> Void = { value in var value = value.littleEndian; withUnsafeBytes(of: &value) { ico.append(contentsOf: $0) } }
append16(0); append16(1); append16(UInt16(sizes.count))
var offset = UInt32(6 + sizes.count * 16)
var frames: [Data] = []
for size in sizes {
    let data = try Data(contentsOf: output.appendingPathComponent("favicon-\(size).png"))
    ico.append(contentsOf: [UInt8(size == 256 ? 0 : size), UInt8(size == 256 ? 0 : size), 0, 0])
    append16(1); append16(32); append32(UInt32(data.count)); append32(offset)
    offset += UInt32(data.count)
    frames.append(data)
}
for frame in frames { ico.append(frame) }
try ico.write(to: output.appendingPathComponent("favicon.ico"))

let glyph = symbol.components(separatedBy: "  <g")[1].components(separatedBy: "</g>")[0]
let tile: (Double) -> String = { scale in
    let shift = 64 * (1 - scale)
    return """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">
    <rect width="128" height="128" fill="#5148d8"/>
    <g transform="translate(\(shift) \(shift)) scale(\(scale))"><g\(glyph.replacingOccurrences(of: "#5148d8", with: "#ffffff"))</g></g></svg>
    """
}
try raster(image(tile(0.82)), 180, "apple-touch-icon.png")
try raster(image(tile(0.82)), 192, "web-icon-192.png")
try raster(image(tile(0.82)), 512, "web-icon-512.png")
try raster(image(tile(0.66)), 512, "web-icon-maskable-512.png")

for (appearance, name) in [("Default", "app-icon-light.png"), ("Dark", "app-icon-dark.png")] {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool")
    process.arguments = [root.appendingPathComponent("Sources/NornaStudio/Resources/NornaSculpted.icon").path,
        "--export-image", "--output-file", output.appendingPathComponent(name).path, "--platform", "macOS",
        "--rendition", appearance, "--width", "256", "--height", "256", "--scale", "1",
        "--design-generation", ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 ? "27" : "26"]
    process.standardOutput = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw NSError(domain: "NornaBrand", code: Int(process.terminationStatus),
            userInfo: [NSLocalizedDescriptionKey: "Native app icon rendering failed."])
    }
}

let text: (String, NSRect, CGFloat, NSFont.Weight, NSColor) -> Void = { value, rect, size, weight, color in
    (value as NSString).draw(in: rect, withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
}
let ink = NSColor(calibratedWhite: 0.10, alpha: 1)
let muted = NSColor(calibratedWhite: 0.43, alpha: 1)
let cover = bitmap(1200, 630)
paint(cover) {
    NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.99, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: 1200, height: 630).fill()
    image(symbol).draw(in: NSRect(x: 750, y: 155, width: 350, height: 350))
    text("Norna", NSRect(x: 84, y: 389, width: 630, height: 110), 86, .semibold, ink)
    text("Native diagrams, clearly.", NSRect(x: 88, y: 305, width: 660, height: 62), 36, .medium, ink)
    text("Pure Swift · 33 diagram families", NSRect(x: 89, y: 110, width: 650, height: 40), 24, .regular, muted)
}
try save(cover, "social-cover.png")

let proof = bitmap(1440, 900)
paint(proof) {
    NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: 1440, height: 900).fill()
    text("Norna · 按场景使用图标", NSRect(x: 60, y: 802, width: 1320, height: 48), 32, .semibold, ink)
    let app = NSImage(contentsOf: output.appendingPathComponent("app-icon-light.png"))!
    app.draw(in: NSRect(x: 66, y: 453, width: 260, height: 260))
    text("APP · 立体与系统材质", NSRect(x: 68, y: 394, width: 360, height: 35), 22, .medium, ink)
    image(symbol).draw(in: NSRect(x: 495, y: 453, width: 260, height: 260))
    text("站点 · 清晰矢量", NSRect(x: 500, y: 394, width: 360, height: 35), 22, .medium, ink)
    image(fixedFavicon).draw(in: NSRect(x: 983, y: 495, width: 170, height: 170))
    text("标签页 · 独立微型版", NSRect(x: 949, y: 394, width: 360, height: 35), 22, .medium, ink)
    text("实际尺寸", NSRect(x: 66, y: 299, width: 300, height: 32), 20, .medium, ink)
    for (index, size) in [16, 32, 48, 64].enumerated() {
        image(fixedFavicon).draw(in: NSRect(x: 68 + index * 94, y: 219, width: size, height: size))
        text("\(size) px", NSRect(x: 68 + index * 94, y: 177, width: 85, height: 26), 15, .regular, muted)
    }
    image(tile(0.82)).draw(in: NSRect(x: 523, y: 110, width: 164, height: 164))
    text("主屏幕 · 平面底板与留白", NSRect(x: 500, y: 62, width: 380, height: 32), 20, .medium, ink)
    NSImage(contentsOf: output.appendingPathComponent("social-cover.png"))!.draw(in: NSRect(x: 914, y: 113, width: 410, height: 215))
    text("分享 · 横向品牌封面", NSRect(x: 949, y: 62, width: 380, height: 32), 20, .medium, ink)
}
try save(proof, "usage-board.png")
print("Generated app, web, micro favicon, ICO, touch, maskable, and social assets in \(output.path).")
