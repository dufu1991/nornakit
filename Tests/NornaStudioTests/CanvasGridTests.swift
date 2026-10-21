import AppKit
import NornaKit
import XCTest
@testable import NornaStudio

final class CanvasGridTests: XCTestCase {
    @MainActor
    func testGridIsVisibleInLightDarkAndHighContrastAppearances() throws {
        for theme in [DiagramTheme.appleLight, .appleDark, .appleLightHighContrast, .appleDarkHighContrast] {
            let hidden = try rasterize(theme: theme, showGrid: false)
            let visible = try rasterize(theme: theme, showGrid: true)
            var maximumDifference = 0.0
            var changedPixels = 0
            for y in 0..<visible.pixelsHigh {
                for x in 0..<visible.pixelsWide {
                    let a = try XCTUnwrap(hidden.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                    let b = try XCTUnwrap(visible.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                    let difference = max(abs(a.redComponent - b.redComponent), abs(a.greenComponent - b.greenComponent), abs(a.blueComponent - b.blueComponent))
                    maximumDifference = max(maximumDifference, difference)
                    if difference > 0.1 { changedPixels += 1 }
                }
            }
            XCTAssertGreaterThan(maximumDifference, 0.1, "Grid must remain perceptible in \(theme).")
            XCTAssertGreaterThan(changedPixels, 20, "Grid should cover multiple positions in \(theme).")
        }
    }

    @MainActor
    func testTogglingGridInvalidatesCanvasImmediately() {
        _ = NSApplication.shared
        let canvas = DiagramCanvasView(frame: CGRect(x: 0, y: 0, width: 64, height: 64))
        let window = NSWindow(contentRect: canvas.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = canvas
        defer { window.close() }
        canvas.needsDisplay = false
        canvas.showGrid = true
        XCTAssertTrue(canvas.needsDisplay)
        canvas.needsDisplay = false
        canvas.showGrid = false
        XCTAssertTrue(canvas.needsDisplay)
    }

    @MainActor
    private func rasterize(theme: DiagramTheme, showGrid: Bool) throws -> NSBitmapImageRep {
        let canvas = DiagramCanvasView(frame: CGRect(x: 0, y: 0, width: 64, height: 64))
        canvas.theme = theme
        canvas.showGrid = showGrid
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 128, pixelsHigh: 128,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let graphics = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        graphics.cgContext.translateBy(x: 0, y: 128)
        graphics.cgContext.scaleBy(x: 2, y: -2)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: graphics.cgContext, flipped: true)
        canvas.draw(canvas.bounds)
        return bitmap
    }
}
