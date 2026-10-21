import AppKit
import NornaKit

@main
struct RenderShowcase {
    static func main() async throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let renderer = NativeDiagramRenderer()
        for language in ["zh", "en"] {
            let zh = language == "zh"
            let source = zh ? """
            flowchart LR
                A([输入想法]) --> B[编写 Mermaid]
                B --> C{原生引擎}
                C --> D[清晰的图表]
                C --> E[导出 SVG]
            """ : """
            flowchart LR
                A([An idea]) --> B[Write Mermaid]
                B --> C{Native engine}
                C --> D[Clear diagrams]
                C --> E[Export SVG]
            """
            let artifact = try await renderer.render(source)
            try source.write(to: output.appendingPathComponent("hero-\(language).mmd"), atomically: true, encoding: .utf8)
            for (name, theme) in [("light", DiagramTheme.appleLight), ("dark", DiagramTheme.appleDark)] {
                let scene = artifact.scene
                let scale: CGFloat = 2
                let padding: CGFloat = 32
                let size = CGSize(width: scene.size.width + padding * 2, height: scene.size.height + padding * 2)
                let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(ceil(size.width * scale)), pixelsHigh: Int(ceil(size.height * scale)), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
                NSGraphicsContext.saveGraphicsState()
                graphics.cgContext.translateBy(x: 0, y: CGFloat(bitmap.pixelsHigh))
                graphics.cgContext.scaleBy(x: scale, y: -scale)
                NSGraphicsContext.current = NSGraphicsContext(cgContext: graphics.cgContext, flipped: true)
                CoreGraphicsDiagramPainter.color(theme.background).setFill()
                CGRect(origin: .zero, size: size).fill()
                graphics.cgContext.translateBy(x: padding, y: padding)
                CoreGraphicsDiagramPainter.draw(scene, theme: theme, colorStyle: .themed)
                NSGraphicsContext.restoreGraphicsState()
                let png = bitmap.representation(using: .png, properties: [:])!
                try png.write(to: output.appendingPathComponent("hero-\(language)-\(name).png"))
            }
        }
    }
}
