import XCTest
@testable import NornaKit

final class SharedLayoutFixtureTests: XCTestCase {
    func testSharedFixedMeasurementGeometry() async throws {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: SharedLayoutFixtureTests.self)
        #endif
        let url = try XCTUnwrap(bundle.url(forResource: "layout-fixtures", withExtension: "json", subdirectory: "Resources"))
        let fixtures = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
        let renderer = NativeDiagramRenderer()
        var snapshots: [Fixture] = []
        for fixture in fixtures {
            let artifact = try await TextMeasurement.$provider.withValue(FixedTextMeasurement()) {
                try await renderer.render(fixture.source, options: .init(maxWidth: fixture.maxWidth.map { CGFloat($0) }))
            }
            let scene = artifact.scene
            let actual = Fixture(id: fixture.id, source: fixture.source, maxWidth: fixture.maxWidth,
                size: [scene.size.width, scene.size.height],
                nodes: scene.nodes.map { Node(id: $0.id, label: $0.label, shape: $0.shape.rawValue, frame: rect($0.frame)) },
                edges: scene.edges.map { Edge(from: $0.from, to: $0.to, label: $0.label,
                    points: $0.points.map { [$0.x, $0.y] }, labelFrame: rect($0.labelFrame), style: $0.style.rawValue,
                    arrow: $0.arrow, startMarker: $0.startMarker.rawValue, endMarker: ($0.endMarker ?? ($0.arrow ? .arrow : .none)).rawValue) },
                groups: scene.groups.map { Group(id: $0.id, parentId: $0.parentID, label: $0.label,
                    frame: rect($0.frame), titleFrame: rect($0.titleFrame), depth: $0.depth) })
            snapshots.append(actual)
            if ProcessInfo.processInfo.environment["NORNA_LAYOUT_FIXTURE_OUTPUT"] == nil {
                XCTAssertEqual(actual, fixture, "Shared fixed measurement layout changed: \(fixture.id)")
            }
        }
        if let output = ProcessInfo.processInfo.environment["NORNA_LAYOUT_FIXTURE_OUTPUT"] {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(snapshots).write(to: URL(fileURLWithPath: output))
        }
    }
    private func rect(_ value: CGRect) -> [Double] { [value.minX, value.minY, value.width, value.height] }
    private struct Fixture: Codable, Equatable {
        let id: String, source: String
        let maxWidth: Double?
        let size: [Double]
        let nodes: [Node], edges: [Edge], groups: [Group]
    }
    private struct Node: Codable, Equatable { let id: String, label: String, shape: String; let frame: [Double] }
    private struct Edge: Codable, Equatable {
        let from: String, to: String, label: String
        let points: [[Double]], labelFrame: [Double]
        let style: String
        let arrow: Bool
        let startMarker: String, endMarker: String
    }
    private struct Group: Codable, Equatable {
        let id: String, parentId: String?, label: String
        let frame: [Double], titleFrame: [Double]
        let depth: Int
    }
}

private struct FixedTextMeasurement: TextMeasurementProviding {
    func width(_ text: String, size: CGFloat, bold: Bool, mono: Bool) -> CGFloat {
        text.unicodeScalars.reduce(0) { $0 + size * ($1.value >= 0x2e80 ? 1 : 0.5) }
    }
    func lines(_ text: String, maxWidth: CGFloat, size: CGFloat, bold: Bool, mono: Bool) -> [String] {
        var lines: [String] = [], line = "", length: CGFloat = 0
        for scalar in text.unicodeScalars {
            let advance = size * (scalar.value >= 0x2e80 ? 1 : 0.5)
            if scalar == "\n" || length > 0 && length + advance > maxWidth {
                lines.append(line); line = ""; length = 0
            }
            if scalar != "\n" { line.unicodeScalars.append(scalar); length += advance }
        }
        lines.append(line)
        return lines
    }
}
