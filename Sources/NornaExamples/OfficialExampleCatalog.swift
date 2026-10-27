import Foundation
import NornaKit

public struct OfficialExampleOrigin: Decodable, Sendable {
    public let url: String
    public let ordinal: Int
    public let section: String
}

public struct OfficialExample: Decodable, Identifiable, Sendable {
    public let id: String
    public let kind: DiagramKind
    public let sha256: String
    public let source: String
    public let origins: [OfficialExampleOrigin]
}

public struct OfficialExamplePage: Decodable, Sendable {
    public let url: String
    public let file: String
    public let sha256: String
    public let exampleCount: Int
}

public struct OfficialExampleSnapshot: Decodable, Sendable {
    public let schemaVersion: Int
    public let retrievedAt: String
    public let pages: [OfficialExamplePage]
    public let examples: [OfficialExample]
}

public struct OfficialValidationResult: Codable, Sendable {
    public let id: String
    public let kind: String
    public let status: String
    public let code: String?
    public let message: String?
    public let line: Int?
    public let width: Double?
    public let height: Double?
}

public enum OfficialExampleCatalog {
    // The checked-in resource is immutable; tests verify its schema, hashes, and completeness.
    public static let snapshot: OfficialExampleSnapshot = try! load()
    public static let results: [String: OfficialValidationResult] = {
        let data = try! resource("official-status")
        let results = try! JSONDecoder().decode([OfficialValidationResult].self, from: data)
        return Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) })
    }()

    public static func load() throws -> OfficialExampleSnapshot {
        try JSONDecoder().decode(OfficialExampleSnapshot.self, from: resource("official-examples"))
    }

    private static func resource(_ name: String) throws -> Data {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: ResourceBundle.self)
        #endif
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Resources") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try Data(contentsOf: url)
    }
}

private final class ResourceBundle: NSObject {}
