import Foundation

/// Shared by measurement, layout, the native painter, and the SVG exporter.
enum DiagramStyle {
    static let fontSize: CGFloat = 16
    static let lineHeight: CGFloat = 22
    static let edgeFontSize: CGFloat = 12
    static let edgeLineHeight: CGFloat = 18
    static let nodeSeparation: CGFloat = 40
    static let rankSeparation: CGFloat = 48
    static let groupPadding: CGFloat = 20
    static let cornerRadius: CGFloat = 8
    static let scenePadding: CGFloat = 8
}
