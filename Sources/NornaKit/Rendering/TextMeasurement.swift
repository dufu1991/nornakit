import Foundation

/// Scoped measurement injection for platform independent layout regression fixtures.
protocol TextMeasurementProviding: Sendable {
    func width(_ text: String, size: CGFloat, bold: Bool, mono: Bool) -> CGFloat
    func lines(_ text: String, maxWidth: CGFloat, size: CGFloat, bold: Bool, mono: Bool) -> [String]
}

enum TextMeasurement {
    @TaskLocal static var provider: (any TextMeasurementProviding)?
    static let fontSize = DiagramStyle.fontSize
    static let lineHeight = DiagramStyle.lineHeight

    static func width(_ text: String, size: CGFloat = fontSize, bold: Bool = false, mono: Bool = false) -> CGFloat {
        provider?.width(text, size: size, bold: bold, mono: mono)
            ?? InlineText.line(text, size: size, bold: bold, mono: mono).width
    }

    static func lines(_ text: String, maxWidth: CGFloat = 200, size: CGFloat = fontSize,
                      bold: Bool = false, mono: Bool = false) -> [String] {
        provider?.lines(text, maxWidth: maxWidth, size: size, bold: bold, mono: mono)
            ?? InlineText.wrappedLines(text, maxWidth: maxWidth, size: size, bold: bold, mono: mono)
    }

    static func nodeSize(lines: [String], shape: NodeShape) -> CGSize {
        let width = lines.map { self.width($0) }.max() ?? 0
        let height = CGFloat(lines.count) * lineHeight
        switch shape {
        // Shape measurements follow Pele's PAD_X = 18 and PAD_Y = 12 geometry.
        // See THIRD_PARTY_NOTICES.md for upstream attribution.
        case .diamond: return CGSize(width: width + 16 + 1.6 * (height + 8), height: (width + 16) / 1.6 + height + 8)
        case .circle, .doubleCircle:
            let diameter = max(44, hypot(width, height) + (shape == .doubleCircle ? 28 : 16))
            return CGSize(width: diameter, height: diameter)
        case .hexagon, .asymmetric, .parallelogram, .parallelogramAlt, .trapezoid, .trapezoidAlt:
            return CGSize(width: max(80, (width + 36) / 0.6), height: height + 32)
        case .ellipse: return CGSize(width: max(100, (width + 24) * 1.42), height: max(50, (height + 12) * 1.42))
        case .stadium: return CGSize(width: width + (height + 24) * 0.5 + 28, height: height + 24)
        case .cylinder:
            let w = max(56, width + 36)
            return CGSize(width: w, height: height + 24 + 2 * min(12, max(6, w / 14)))
        case .subroutine: return CGSize(width: width + 52, height: height + 24)
        default: return CGSize(width: max(48, width + 36), height: height + 24)
        }
    }
}
