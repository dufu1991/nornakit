import AppKit

public struct DiagramColors: Sendable {
    public let background: String
    public let foreground: String
    public let muted: String
    public let line: String
    public let surface: String
    public let surfaceAlt: String
    public let border: String
    public let accent: String
    public var series: [String] = ["#4c78a8", "#f58518", "#54a24b", "#e45756", "#72b7b2", "#eeca3b", "#b279a2", "#9d755d"]
}

/// Color treatment is independent of light, dark, and increased-contrast appearance.
public enum DiagramColorStyle: String, CaseIterable, Identifiable, Sendable {
    case neutral, themed, custom

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .neutral: "无主题色"
        case .themed: "主题色"
        case .custom: "自定义"
        }
    }
}

public struct DiagramAccentColor: Hashable, Sendable {
    public let hex: String
    public static let norna = DiagramAccentColor(red: 81, green: 72, blue: 216)

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        hex = String(format: "#%02x%02x%02x", red, green, blue)
    }

    public init?(hex: String) {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard digits.utf8.count == 6,
              digits.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }),
              let value = UInt32(digits, radix: 16) else { return nil }
        self.hex = String(format: "#%06x", value)
    }
}

public enum DiagramTheme: String, CaseIterable, Identifiable, Sendable {
    case paper, midnight, ocean
    case appleLight, appleDark, appleLightHighContrast, appleDarkHighContrast
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .paper: "纸白"
        case .midnight: "午夜"
        case .ocean: "海蓝"
        case .appleLight: "系统浅色"
        case .appleDark: "系统深色"
        case .appleLightHighContrast: "系统浅色高对比度"
        case .appleDarkHighContrast: "系统深色高对比度"
        }
    }
    public var background: String { colors.background }
    public var colors: DiagramColors {
        switch self {
        case .paper:
            DiagramColors(background: "#ffffff", foreground: "#1f1f1f", muted: "#6e6e6e", line: "#1f1f1f", surface: "#f3f3f3", surfaceAlt: "#e6e6e6", border: "#8a8a8a", accent: "#5b7bd5")
        case .midnight:
            DiagramColors(background: "#191c24", foreground: "#e6eaf2", muted: "#9ba6ba", line: "#a7b4cc", surface: "#262c39", surfaceAlt: "#333d50", border: "#65738d", accent: "#9cafff")
        case .ocean:
            DiagramColors(background: "#f5f9ff", foreground: "#183957", muted: "#5c758e", line: "#5280a6", surface: "#e6f0fc", surfaceAlt: "#d3e5f9", border: "#9ab9d6", accent: "#3475cf")
        case .appleLight, .appleDark, .appleLightHighContrast, .appleDarkHighContrast:
            ApplePaletteCache.shared.colors(for: self)
        }
    }

    /// Neutral preserves the existing palette, including categorical data-series colors.
    public func colors(for colorStyle: DiagramColorStyle, customAccent: DiagramAccentColor = .norna) -> DiagramColors {
        switch colorStyle {
        case .neutral: colors
        case .themed: ApplePaletteCache.shared.themedColors(for: self)
        case .custom: ApplePaletteCache.shared.customColors(for: self, accent: customAccent)
        }
    }

    public static func invalidateSystemColors() { ApplePaletteCache.shared.invalidate() }
}

private final class ApplePaletteCache: @unchecked Sendable {
    static let shared = ApplePaletteCache()
    private let lock = NSLock()
    private var palettes: [DiagramTheme: DiagramColors] = [:]
    private var themedPalettes: [DiagramTheme: DiagramColors] = [:]
    private var customPalettes: [DiagramTheme: (accent: DiagramAccentColor, colors: DiagramColors)] = [:]

    func invalidate() {
        lock.lock(); defer { lock.unlock() }
        palettes.removeAll()
        themedPalettes.removeAll()
        customPalettes.removeAll()
    }

    func customColors(for theme: DiagramTheme, accent: DiagramAccentColor) -> DiagramColors {
        let base = theme.colors
        lock.lock(); defer { lock.unlock() }
        if let cached = customPalettes[theme], cached.accent == accent { return cached.colors }
        let dark = [.midnight, .appleDark, .appleDarkHighContrast].contains(theme)
        let increasedContrast = [.appleLightHighContrast, .appleDarkHighContrast].contains(theme)
        let surface = blend(accent.hex, base.surface, dark ? 0.12 : 0.07)
        let surfaceAlt = blend(accent.hex, base.background, dark ? 0.14 : 0.10)
        var line = base.foreground
        for step in 0...40 {
            let candidate = blend(accent.hex, base.foreground, 1 - Double(step) / 40)
            if [base.background, surface, surfaceAlt].allSatisfy({ contrast(candidate, $0) >= 4.5 }) {
                line = candidate
                break
            }
        }
        let result = DiagramColors(background: base.background, foreground: base.foreground, muted: base.muted,
            line: line, surface: surface, surfaceAlt: surfaceAlt,
            border: blend(line, base.background, increasedContrast ? 1 : 0.8), accent: line, series: base.series)
        // Retain only the most recent custom color per appearance while a color well is dragged.
        customPalettes[theme] = (accent, result)
        return result
    }

    private func blend(_ foreground: String, _ background: String, _ amount: Double) -> String {
        let a = UInt32(foreground.dropFirst(), radix: 16)!, b = UInt32(background.dropFirst(), radix: 16)!
        let channel: (Int) -> Int = { shift in
            Int((Double((a >> shift) & 255) * amount + Double((b >> shift) & 255) * (1 - amount)).rounded())
        }
        return String(format: "#%02x%02x%02x", channel(16), channel(8), channel(0))
    }

    private func contrast(_ a: String, _ b: String) -> Double {
        let luminance: (String) -> Double = { hex in
            let value = UInt32(hex.dropFirst(), radix: 16)!
            let linear: (UInt32) -> Double = {
                let channel = Double($0 & 255) / 255
                return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(value >> 16) + 0.7152 * linear(value >> 8) + 0.0722 * linear(value)
        }
        let first = luminance(a), second = luminance(b)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    func themedColors(for theme: DiagramTheme) -> DiagramColors {
        // Resolve system colors before taking the same cache lock.
        let base = theme.colors
        lock.lock(); defer { lock.unlock() }
        if let cached = themedPalettes[theme] { return cached }
        let dark = [.midnight, .appleDark, .appleDarkHighContrast].contains(theme)
        let increasedContrast = [.appleLightHighContrast, .appleDarkHighContrast].contains(theme)
        let accent: String
        switch theme {
        case .appleLight: accent = "#5148d8"
        case .appleDark: accent = "#aaa4ff"
        case .appleLightHighContrast: accent = "#4136c2"
        case .appleDarkHighContrast: accent = "#c6c1ff"
        default: accent = base.accent
        }
        let blend: (String, String, Double) -> String = { foreground, background, amount in
            let a = UInt32(foreground.dropFirst(), radix: 16)!
            let b = UInt32(background.dropFirst(), radix: 16)!
            let channel: (Int) -> Int = { shift in
                Int((Double((a >> shift) & 255) * amount + Double((b >> shift) & 255) * (1 - amount)).rounded())
            }
            return String(format: "#%02x%02x%02x", channel(16), channel(8), channel(0))
        }
        let result = DiagramColors(
            background: base.background, foreground: base.foreground, muted: base.muted,
            line: accent, surface: blend(accent, base.surface, dark ? 0.14 : 0.07),
            surfaceAlt: blend(accent, base.background, dark ? 0.16 : 0.10),
            border: blend(accent, base.background, increasedContrast ? 0.96 : 0.72),
            accent: accent, series: base.series
        )
        themedPalettes[theme] = result
        return result
    }

    func colors(for theme: DiagramTheme) -> DiagramColors {
        lock.lock(); defer { lock.unlock() }
        if let cached = palettes[theme] { return cached }
        let name: NSAppearance.Name
        switch theme {
        case .appleDark: name = .darkAqua
        case .appleLightHighContrast: name = .accessibilityHighContrastAqua
        case .appleDarkHighContrast: name = .accessibilityHighContrastDarkAqua
        default: name = .aqua
        }
        let appearance = NSAppearance(named: name)!
        var result: DiagramColors!
        appearance.performAsCurrentDrawingAppearance {
            let background = NSColor.windowBackgroundColor.usingColorSpace(.sRGB)!
            let hex: (NSColor) -> String = { value in
                let rgb = value.usingColorSpace(.sRGB)!, alpha = rgb.alphaComponent
                let channel: (CGFloat, CGFloat) -> Int = { Int((min(1, max(0, $0 * alpha + $1 * (1 - alpha))) * 255).rounded()) }
                return String(format: "#%02x%02x%02x", channel(rgb.redComponent, background.redComponent), channel(rgb.greenComponent, background.greenComponent), channel(rgb.blueComponent, background.blueComponent))
            }
            result = DiagramColors(background: hex(background), foreground: hex(.labelColor), muted: hex(.secondaryLabelColor),
                line: hex(.secondaryLabelColor), surface: hex(.controlBackgroundColor), surfaceAlt: hex(.unemphasizedSelectedContentBackgroundColor),
                border: hex(.separatorColor), accent: hex(.controlAccentColor),
                series: [.systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemTeal, .systemPink, .systemIndigo, .systemBrown].map(hex))
        }
        palettes[theme] = result
        return result
    }
}
