import AppKit
import XCTest
@testable import NornaKit

final class NativeDrawingTests: XCTestCase {
    @MainActor
    func testNativeRoutingRasterizationAndSVGFixtures() async throws {
        for id in ["subgraphs", "nested", "groupLinks", "cycle"] {
            let example = try XCTUnwrap(DiagramExample.all.first { $0.id == id })
            let artifact = try await NativeFlowchartRenderer().render(example.source)
            let bitmap = try rasterize(artifact.scene)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            XCTAssertGreaterThan(png.count, 2_000)
            let interior = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2))
            XCTAssertGreaterThan(interior.alphaComponent, 0.9)
            if let directory = ProcessInfo.processInfo.environment["NORNA_FIXTURE_DIR"] {
                let url = URL(fileURLWithPath: directory, isDirectory: true)
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                try png.write(to: url.appendingPathComponent(id + ".png"))
                try artifact.themedSVG(.appleLight).write(to: url.appendingPathComponent(id + ".svg"), atomically: true, encoding: .utf8)
                try example.source.write(to: url.appendingPathComponent(id + ".mmd"), atomically: true, encoding: .utf8)
            }
        }
    }

    @MainActor
    private func rasterize(_ scene: DiagramScene) throws -> NSBitmapImageRep {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(ceil(scene.size.width * 2)),
                                                   pixelsHigh: Int(ceil(scene.size.height * 2)), bitsPerSample: 8,
                                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let base = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let cg = base.cgContext
        cg.translateBy(x: 0, y: CGFloat(bitmap.pixelsHigh))
        cg.scaleBy(x: 2, y: -2)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
        cg.setFillColor(NSColor.white.cgColor)
        cg.fill(CGRect(origin: .zero, size: scene.size))
        CoreGraphicsDiagramPainter.draw(scene, theme: .appleLight)
        return bitmap
    }
}
