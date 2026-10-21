import AppKit
import CoreText

/// One inline model drives measurement, wrapping, native drawing, and SVG export.
enum InlineText {
    struct SymbolSpec: Equatable {
        let name: String
        let mode: String
        let colors: [String]
        let source: String
    }

    enum Segment: Equatable {
        case text(String), symbol(String), configuredSymbol(SymbolSpec)

        var source: String {
            switch self {
            case .text(let value): return value
            case .symbol(let name): return ":sf:\(name):"
            case .configuredSymbol(let spec): return spec.source
            }
        }
    }

    struct Style: Equatable {
        var bold = false
        var italic = false
        var mono = false
        var underline = false
        var strike = false
        var color: String?
        static let plain = Style()

        var tags: [(String, String)] {
            var result: [(String, String)] = []
            if bold { result.append(("[b]", "[/b]")) }
            if italic { result.append(("[i]", "[/i]")) }
            if mono { result.append(("[code]", "[/code]")) }
            if underline { result.append(("[u]", "[/u]")) }
            if strike { result.append(("[s]", "[/s]")) }
            if let color { result.append(("[color=\(color)]", "[/color]")) }
            return result
        }
    }

    struct StyledSegment: Equatable {
        var segment: Segment
        let style: Style
    }

    struct Run {
        let segment: Segment
        let style: Style
        let font: NSFont
        let x: CGFloat
        let width: CGFloat
        let image: NSImage?
    }

    struct Line {
        let runs: [Run]
        let width: CGFloat
    }

    private final class SymbolEntry {
        let image: NSImage?
        init(_ image: NSImage?) { self.image = image }
    }
    private static let symbolPattern = try! NSRegularExpression(pattern: #":sf:([A-Za-z0-9][A-Za-z0-9._-]*)(?:@(monochrome|hierarchical|multicolor|palette\(#[A-Fa-f0-9]{6}(?:,#[A-Fa-f0-9]{6}){0,2}\)))?:"#)
    private static let tagPattern = try! NSRegularExpression(pattern: #"\[(/?)(b|i|code|u|s|color)(?:=(#[A-Fa-f0-9]{6}))?\]"#)
    private static let symbols: NSCache<NSString, SymbolEntry> = { let value = NSCache<NSString, SymbolEntry>(); value.countLimit = 512; return value }()
    private static let pngs: NSCache<NSString, NSData> = { let value = NSCache<NSString, NSData>(); value.totalCostLimit = 4_000_000; return value }()

    static func segments(_ text: String) -> [Segment] {
        let source = text as NSString
        var result: [Segment] = [], cursor = 0
        for match in symbolPattern.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            if match.range.location > cursor { result.append(.text(source.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))) }
            let name = source.substring(with: match.range(at: 1))
            if match.range(at: 2).location == NSNotFound { result.append(.symbol(name)) }
            else {
                let value = source.substring(with: match.range(at: 2))
                let colors = value.hasPrefix("palette(") ? String(value.dropFirst(8).dropLast()).components(separatedBy: ",") : []
                result.append(.configuredSymbol(SymbolSpec(name: name, mode: colors.isEmpty ? value : "palette", colors: colors, source: source.substring(with: match.range))))
            }
            cursor = NSMaxRange(match.range)
        }
        if cursor < source.length { result.append(.text(source.substring(from: cursor))) }
        return result
    }

    /// Only balanced, properly nested supported tags affect styling. Other tags remain literal.
    static func styledSegments(_ text: String) -> [StyledSegment] {
        let source = text as NSString
        let tags = tagPattern.matches(in: text, range: NSRange(location: 0, length: source.length)).filter { match in
            let name = source.substring(with: match.range(at: 2)), closing = match.range(at: 1).length > 0
            return name == "color" ? closing || match.range(at: 3).location != NSNotFound : match.range(at: 3).location == NSNotFound
        }
        var stack: [Int] = [], valid = Set<Int>()
        for (index, tag) in tags.enumerated() {
            if tag.range(at: 1).length == 0 { stack.append(index) }
            else if let opening = stack.last, source.substring(with: tags[opening].range(at: 2)) == source.substring(with: tag.range(at: 2)) {
                valid.insert(opening); valid.insert(index); stack.removeLast()
            } else { stack.removeAll() }
        }
        var result: [StyledSegment] = [], styles = [Style.plain], cursor = 0
        for (index, tag) in tags.enumerated() where valid.contains(index) {
            if tag.range.location > cursor {
                result += segments(source.substring(with: NSRange(location: cursor, length: tag.range.location - cursor))).map { StyledSegment(segment: $0, style: styles.last!) }
            }
            if tag.range(at: 1).length > 0 { styles.removeLast() }
            else {
                var style = styles.last!
                switch source.substring(with: tag.range(at: 2)) {
                case "b": style.bold = true
                case "i": style.italic = true
                case "code": style.mono = true
                case "u": style.underline = true
                case "s": style.strike = true
                default: style.color = source.substring(with: tag.range(at: 3))
                }
                styles.append(style)
            }
            cursor = NSMaxRange(tag.range)
        }
        if cursor < source.length { result += segments(source.substring(from: cursor)).map { StyledSegment(segment: $0, style: styles.last!) } }
        return result
    }

    static func wrappingUnits(_ text: String) -> [String] {
        segments(text).flatMap { segment -> [String] in
            if case .text(let value) = segment { return value.map { String($0) } }
            return [segment.source]
        }
    }

    private static func coalesced(_ values: [StyledSegment]) -> [StyledSegment] {
        var result: [StyledSegment] = []
        for value in values {
            if let previous = result.last, previous.style == value.style,
               case .text(let a) = previous.segment, case .text(let b) = value.segment {
                result[result.count - 1].segment = .text(a + b)
            } else { result.append(value) }
        }
        return result
    }

    private static func serialized(_ values: [StyledSegment]) -> String {
        coalesced(values).map { value in
            value.style.tags.map(\.0).joined() + value.segment.source + value.style.tags.reversed().map(\.1).joined()
        }.joined()
    }

    static func wrappedLines(_ text: String, maxWidth: CGFloat, size: CGFloat, bold: Bool = false, mono: Bool = false) -> [String] {
        let units = styledSegments(text).flatMap { value -> [StyledSegment] in
            if case .text(let text) = value.segment { return text.map { StyledSegment(segment: .text(String($0)), style: value.style) } }
            return [value]
        }
        var result: [String] = [], current: [StyledSegment] = []
        let isLatinWord: (StyledSegment) -> Bool = { value in
            guard case .text(let text) = value.segment, let character = text.first, character.isASCII else { return false }
            return character.isLetter || character.isNumber || character == "_"
        }
        for unit in units {
            if unit.segment == .text("\n") { result.append(serialized(current)); current = []; continue }
            if !current.isEmpty, layout(current + [unit], size: size, bold: bold, mono: mono).width > maxWidth {
                // Prefer a whitespace boundary while retaining every source character and style.
                if isLatinWord(unit), current.last.map(isLatinWord) == true,
                   let boundary = current.lastIndex(where: { $0.segment == .text(" ") || $0.segment == .text("\t") }),
                   boundary > 0,
                   layout(Array(current.suffix(from: boundary + 1)) + [unit], size: size, bold: bold, mono: mono).width <= maxWidth {
                    result.append(serialized(Array(current.prefix(through: boundary))))
                    current = Array(current.suffix(from: boundary + 1))
                } else {
                    result.append(serialized(current)); current = []
                }
            }
            current.append(unit)
        }
        return result + [serialized(current)]
    }

    static func font(size: CGFloat, bold: Bool = false, mono: Bool = false, italic: Bool = false) -> NSFont {
        let font: NSFont = mono ? .monospacedSystemFont(ofSize: size, weight: bold ? .semibold : .regular) : .systemFont(ofSize: size, weight: bold ? .semibold : .regular)
        guard italic else { return font }
        return NSFont(descriptor: font.fontDescriptor.withSymbolicTraits(.italic), size: size)!
    }

    static func symbol(_ name: String, size: CGFloat, bold: Bool = false) -> NSImage? {
        symbol(SymbolSpec(name: name, mode: "monochrome", colors: [], source: ":sf:\(name):"), size: size, bold: bold)
    }

    private static func symbol(_ spec: SymbolSpec, size: CGFloat, bold: Bool) -> NSImage? {
        let key = "\(spec.source)|\(size)|\(bold)" as NSString
        if let cached = symbols.object(forKey: key) { return cached.image }
        var configuration = NSImage.SymbolConfiguration(pointSize: size, weight: bold ? .semibold : .regular, scale: .medium)
        switch spec.mode {
        case "multicolor": configuration = configuration.applying(.preferringMulticolor())
        case "hierarchical": configuration = configuration.applying(.preferringHierarchical())
        case "palette": configuration = configuration.applying(.init(paletteColors: spec.colors.map(CoreGraphicsDiagramPainter.color)))
        default: configuration = configuration.applying(.preferringMonochrome())
        }
        let image = NSImage(systemSymbolName: spec.name, accessibilityDescription: nil)?.withSymbolConfiguration(configuration)
        symbols.setObject(SymbolEntry(image), forKey: key)
        return image
    }

    static func line(_ text: String, size: CGFloat, bold: Bool = false, mono: Bool = false) -> Line {
        layout(styledSegments(text), size: size, bold: bold, mono: mono)
    }

    private static func layout(_ values: [StyledSegment], size: CGFloat, bold: Bool, mono: Bool) -> Line {
        var x: CGFloat = 0
        let runs = coalesced(values).map { value -> Run in
            let font = font(size: size, bold: bold || value.style.bold, mono: mono || value.style.mono, italic: value.style.italic)
            let image: NSImage?
            switch value.segment {
            case .symbol(let name): image = symbol(name, size: size, bold: bold || value.style.bold)
            case .configuredSymbol(let spec): image = symbol(spec, size: size, bold: bold || value.style.bold)
            case .text: image = nil
            }
            let attributed = NSAttributedString(string: value.segment.source, attributes: [.font: font])
            let width = image == nil ? CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(attributed), nil, nil, nil)) : image!.size.width
            defer { x += width }
            return Run(segment: value.segment, style: value.style, font: font, x: x, width: width,
                       image: image)
        }
        return Line(runs: runs, width: x)
    }

    static func origin(width: CGFloat, frame: CGRect, alignment: TextAlignment) -> CGFloat {
        switch alignment {
        case .leading: return frame.minX
        case .center: return frame.midX - width / 2
        case .trailing: return frame.maxX - width
        }
    }
    static func baseline(top: CGFloat, lineHeight: CGFloat, font: NSFont) -> CGFloat {
        top + (lineHeight - font.ascender + font.descender) / 2 + font.ascender
    }
    static func symbolFrame(_ image: NSImage, x: CGFloat, baseline: CGFloat) -> CGRect {
        CGRect(x: x, y: baseline - image.size.height + image.alignmentRect.minY, width: image.size.width, height: image.size.height)
    }

    private static func preparedImage(_ run: Run, color: NSColor) -> NSImage {
        let image = run.image!
        switch run.segment {
        case .configuredSymbol(let spec):
            switch spec.mode {
            case "multicolor":
                if !image.isTemplate { return image }
                return image.withSymbolConfiguration(.init(paletteColors: [color]).applying(.preferringMonochrome()))!
            case "hierarchical": return image.withSymbolConfiguration(.init(hierarchicalColor: color).applying(.preferringHierarchical()))!
            case "palette": return image
            default: break
            }
        default: break
        }
        return image.withSymbolConfiguration(.init(paletteColors: [color]).applying(.preferringMonochrome()))!
    }

    private static func decorationPositions(_ run: Run, baseline: CGFloat) -> [CGFloat] {
        (run.style.underline ? [baseline - run.font.underlinePosition] : []) + (run.style.strike ? [baseline - run.font.xHeight / 2] : [])
    }

    static func draw(_ lines: [String], frame: CGRect, size: CGFloat, lineHeight: CGFloat,
                     color: NSColor, alignment: TextAlignment = .center, bold: Bool = false, mono: Bool = false) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let baseFont = font(size: size, bold: bold, mono: mono)
        let top = frame.midY - CGFloat(lines.count) * lineHeight / 2
        for (index, text) in lines.enumerated() {
            let line = line(text, size: size, bold: bold, mono: mono)
            let x = origin(width: line.width, frame: frame, alignment: alignment)
            let baseline = baseline(top: top + CGFloat(index) * lineHeight, lineHeight: lineHeight, font: baseFont)
            for run in line.runs {
                let tint = run.style.color.map(CoreGraphicsDiagramPainter.color) ?? color
                if run.image != nil {
                    preparedImage(run, color: tint).draw(in: symbolFrame(run.image!, x: x + run.x, baseline: baseline), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
                } else {
                    let string = NSAttributedString(string: run.segment.source, attributes: [.font: run.font, .foregroundColor: tint])
                    context.saveGState()
                    context.translateBy(x: x + run.x, y: baseline); context.scaleBy(x: 1, y: -1)
                    context.textMatrix = .identity; context.textPosition = .zero
                    CTLineDraw(CTLineCreateWithAttributedString(string), context)
                    context.restoreGState()
                }
                context.saveGState()
                context.setLineCap(.butt)
                context.setStrokeColor(tint.cgColor); context.setLineWidth(max(0.6, run.font.underlineThickness))
                for y in decorationPositions(run, baseline: baseline) {
                    context.move(to: CGPoint(x: x + run.x, y: y)); context.addLine(to: CGPoint(x: x + run.x + run.width, y: y)); context.strokePath()
                }
                context.restoreGState()
            }
        }
    }

    private static func png(_ run: Run, color: NSColor, colorKey: String) -> Data? {
        guard let image = run.image else { return nil }
        let key = "\(run.segment.source)|\(run.font.fontName)|\(run.font.pointSize)|\(colorKey)" as NSString
        if let cached = pngs.object(forKey: key) { return cached as Data }
        let scale: CGFloat = 4
        guard let context = CGContext(data: nil, width: max(1, Int(ceil(image.size.width * scale))), height: max(1, Int(ceil(image.size.height * scale))),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.translateBy(x: 0, y: CGFloat(context.height)); context.scaleBy(x: scale, y: -scale)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        preparedImage(run, color: color).draw(in: CGRect(origin: .zero, size: image.size), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        guard let cgImage = context.makeImage(), let data = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else { return nil }
        pngs.setObject(data as NSData, forKey: key, cost: data.count)
        return data
    }

    static func svg(_ lines: [String], frame: CGRect, size: CGFloat, lineHeight: CGFloat, color: String,
                    alignment: TextAlignment = .center, bold: Bool = false, mono: Bool = false) -> String {
        let baseFont = font(size: size, bold: bold, mono: mono)
        let top = frame.midY - CGFloat(lines.count) * lineHeight / 2
        return lines.enumerated().map { index, text in
            let line = line(text, size: size, bold: bold, mono: mono)
            let baseline = baseline(top: top + CGFloat(index) * lineHeight, lineHeight: lineHeight, font: baseFont)
            let x = origin(width: line.width, frame: frame, alignment: alignment)
            let attributes: (Run) -> String = { run in
                "font-size=\"\(number(size))\" font-weight=\"\(bold || run.style.bold ? "600" : "400")\" fill=\"\(run.style.color ?? color)\""
                    + (mono || run.style.mono ? " font-family=\"Menlo, monospace\"" : "") + (run.style.italic ? " font-style=\"italic\"" : "")
            }
            if line.runs.allSatisfy({ $0.image == nil && $0.style == .plain }) {
                let anchor = alignment == .leading ? "start" : alignment == .trailing ? "end" : "middle"
                let anchorX = alignment == .leading ? frame.minX : alignment == .trailing ? frame.maxX : frame.midX
                let attrs = line.runs.first.map(attributes) ?? "font-size=\"\(number(size))\" fill=\"\(color)\""
                return "<text x=\"\(number(anchorX))\" y=\"\(number(baseline))\" text-anchor=\"\(anchor)\" xml:space=\"preserve\" \(attrs)>\(SVGExporter.escape(line.runs.map { $0.segment.source }.joined()))</text>"
            }
            let body = line.runs.map { run -> String in
                let tint = run.style.color ?? color
                var body: String
                if run.image != nil, let data = png(run, color: CoreGraphicsDiagramPainter.color(tint), colorKey: tint) {
                    let rect = symbolFrame(run.image!, x: x + run.x, baseline: baseline)
                    let metadata: String
                    switch run.segment {
                    case .configuredSymbol(let spec): metadata = "data-sf-symbol=\"\(spec.name)\" data-symbol-mode=\"\(spec.mode)\""
                    case .symbol(let name): metadata = "data-sf-symbol=\"\(name)\""
                    case .text: metadata = ""
                    }
                    body = "<image x=\"\(number(rect.minX))\" y=\"\(number(rect.minY))\" width=\"\(number(rect.width))\" height=\"\(number(rect.height))\" preserveAspectRatio=\"none\" href=\"data:image/png;base64,\(data.base64EncodedString())\" \(metadata)><title>\(SVGExporter.escape(run.segment.source))</title></image>"
                } else {
                    body = "<text x=\"\(number(x + run.x))\" y=\"\(number(baseline))\" xml:space=\"preserve\" \(attributes(run))>\(SVGExporter.escape(run.segment.source))</text>"
                }
                body += decorationPositions(run, baseline: baseline).map { y in
                    "<path d=\"M \(number(x + run.x)) \(number(y)) H \(number(x + run.x + run.width))\" fill=\"none\" stroke=\"\(tint)\" stroke-width=\"\(number(max(0.6, run.font.underlineThickness)))\"/>"
                }.joined()
                return body
            }.joined()
            return "<g role=\"img\" aria-label=\"\(SVGExporter.escape(text))\">\(body)</g>"
        }.joined()
    }
}
