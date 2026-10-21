import AppKit
import ImageIO
import UniformTypeIdentifiers

public enum DiagramExportFormat: String, CaseIterable, Identifiable, Sendable {
    case png, jpeg, tiff, svg, pdf
    public var id: String { rawValue }
    public var title: String { rawValue.uppercased() }
    public var fileExtension: String { self == .jpeg ? "jpg" : self == .tiff ? "tiff" : rawValue }
    public var isVector: Bool { self == .svg || self == .pdf }
    public var supportsTransparency: Bool { self != .jpeg }
    public var contentType: UTType {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        case .tiff: .tiff
        case .svg: .svg
        case .pdf: .pdf
        }
    }
}

public enum DiagramExportBackground: String, CaseIterable, Identifiable, Sendable {
    case theme, transparent
    public var id: String { rawValue }
    public var title: String { self == .theme ? "当前画布背景" : "透明背景" }
}

public struct DiagramExportOptions: Hashable, Sendable {
    public var format: DiagramExportFormat
    public var background: DiagramExportBackground
    public var scale: Double
    public var quality: Double
    public var padding: Double

    public init(format: DiagramExportFormat = .png, background: DiagramExportBackground = .theme,
                scale: Double = 2, quality: Double = 0.92, padding: Double = 16) {
        self.format = format
        self.background = background
        self.scale = scale
        self.quality = quality
        self.padding = padding
    }
}

/// Exports scene geometry, independently of canvas zoom, panning, grid, and selection.
public enum DiagramExporter {
    public static func outputSize(for scene: DiagramScene, options: DiagramExportOptions) throws -> CGSize {
        guard scene.size.width.isFinite, scene.size.height.isFinite, scene.size.width > 0, scene.size.height > 0,
              options.padding.isFinite, (0...512).contains(options.padding),
              options.scale.isFinite, (0.25...8).contains(options.scale),
              options.quality.isFinite, (0...1).contains(options.quality) else {
            throw DiagramRenderError(message: "导出尺寸、倍率、留白或质量参数无效。", code: "export-options")
        }
        guard options.background != .transparent || options.format.supportsTransparency else {
            throw DiagramRenderError(message: "JPEG 不支持透明背景，请选择画布背景或其他格式。", code: "export-options")
        }
        let size = CGSize(width: scene.size.width + options.padding * 2, height: scene.size.height + options.padding * 2)
        if options.format.isVector { return size }
        let pixels = CGSize(width: ceil(size.width * options.scale), height: ceil(size.height * options.scale))
        guard pixels.width <= 16_384, pixels.height <= 16_384, pixels.width * pixels.height <= 32_000_000 else {
            throw DiagramRenderError(message: "导出尺寸过大，请降低倍率或留白。单边最多 16384 像素，总计最多 3200 万像素。", code: "export-limit")
        }
        return pixels
    }

    public static func data(for scene: DiagramScene, theme: DiagramTheme = .appleLight,
                            colorStyle: DiagramColorStyle = .themed, customAccent: DiagramAccentColor = .norna,
                            options: DiagramExportOptions = .init()) throws -> Data {
        let size = try outputSize(for: scene, options: options)
        try Task.checkCancellation()
        if options.format == .svg {
            return Data(SVGExporter.export(scene, theme: theme, colorStyle: colorStyle, customAccent: customAccent,
                background: options.background, padding: options.padding).utf8)
        }
        if options.format == .pdf {
            return try pdf(scene, theme: theme, colorStyle: colorStyle, customAccent: customAccent, options: options, size: size)
        }
        let image = try rasterImage(scene, theme: theme, colorStyle: colorStyle, customAccent: customAccent,
            background: options.background, padding: options.padding, scale: options.scale, size: size)
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, options.format.contentType.identifier as CFString, 1, nil) else {
            throw DiagramRenderError(message: "系统无法创建所选图片格式。", code: "export-format")
        }
        var properties: [CFString: Any] = [kCGImagePropertyDPIWidth: 72 * options.scale, kCGImagePropertyDPIHeight: 72 * options.scale]
        if options.format == .jpeg { properties[kCGImageDestinationLossyCompressionQuality] = options.quality }
        if options.format == .tiff { properties[kCGImagePropertyTIFFDictionary] = [kCGImagePropertyTIFFCompression: 5] }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw DiagramRenderError(message: "图片编码失败，请尝试其他格式或降低倍率。", code: "export-encoding")
        }
        try Task.checkCancellation()
        return data as Data
    }

    /// Bounded, full-diagram PNG proof for the export sheet. It never allocates the full export resolution.
    public static func preview(for scene: DiagramScene, theme: DiagramTheme, colorStyle: DiagramColorStyle,
                               customAccent: DiagramAccentColor = .norna, options: DiagramExportOptions) throws -> Data {
        _ = try outputSize(for: scene, options: options)
        var proof = options
        proof.format = .png
        proof.scale = min(1.5, 1000 / max(scene.size.width + proof.padding * 2, scene.size.height + proof.padding * 2))
        // Very large vector scenes still get a bounded proof below the public raster scale range.
        let size = CGSize(width: ceil((scene.size.width + proof.padding * 2) * proof.scale),
                          height: ceil((scene.size.height + proof.padding * 2) * proof.scale))
        let image = try rasterImage(scene, theme: theme, colorStyle: colorStyle, customAccent: customAccent,
            background: proof.background, padding: proof.padding, scale: proof.scale, size: size)
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw DiagramRenderError(message: "无法生成导出预览。", code: "export-preview")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw DiagramRenderError(message: "无法编码导出预览。", code: "export-preview")
        }
        return data as Data
    }

    private static func rasterImage(_ scene: DiagramScene, theme: DiagramTheme, colorStyle: DiagramColorStyle,
                                    customAccent: DiagramAccentColor, background: DiagramExportBackground,
                                    padding: Double, scale: Double, size: CGSize) throws -> CGImage {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw DiagramRenderError(message: "无法分配导出画布，请降低倍率。", code: "export-memory")
        }
        draw(scene, in: context, theme: theme, colorStyle: colorStyle, customAccent: customAccent,
            background: background, padding: padding, scale: scale, size: size)
        guard let image = context.makeImage() else {
            throw DiagramRenderError(message: "无法生成导出图片。", code: "export-render")
        }
        return image
    }

    private static func pdf(_ scene: DiagramScene, theme: DiagramTheme, colorStyle: DiagramColorStyle,
                            customAccent: DiagramAccentColor, options: DiagramExportOptions, size: CGSize) throws -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: size)
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, [kCGPDFContextCreator: "NornaKit"] as CFDictionary) else {
            throw DiagramRenderError(message: "无法创建 PDF 文档。", code: "export-pdf")
        }
        context.beginPDFPage(nil)
        draw(scene, in: context, theme: theme, colorStyle: colorStyle, customAccent: customAccent,
            background: options.background, padding: options.padding, scale: 1, size: size)
        context.endPDFPage()
        context.closePDF()
        try Task.checkCancellation()
        return data as Data
    }

    private static func draw(_ scene: DiagramScene, in context: CGContext, theme: DiagramTheme,
                             colorStyle: DiagramColorStyle, customAccent: DiagramAccentColor,
                             background: DiagramExportBackground, padding: Double, scale: Double, size: CGSize) {
        context.saveGState()
        defer { context.restoreGState() }
        if background == .theme {
            context.setFillColor(CoreGraphicsDiagramPainter.color(theme.background).cgColor)
            context.fill(CGRect(origin: .zero, size: size))
        }
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: scale, y: -scale)
        context.translateBy(x: padding, y: padding)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        CoreGraphicsDiagramPainter.draw(scene, theme: theme, colorStyle: colorStyle, customAccent: customAccent)
    }
}
