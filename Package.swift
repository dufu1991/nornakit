// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NornaKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "NornaKit", targets: ["NornaKit"]),
        .executable(name: "NornaStudio", targets: ["NornaStudio"])
    ],
    targets: [
        .target(name: "NornaKit"),
        .target(name: "NornaExamples", dependencies: ["NornaKit"], resources: [.copy("Resources")]),
        .executableTarget(name: "NornaStudio", dependencies: ["NornaKit", "NornaExamples"],
            exclude: ["Resources/Assets.xcassets", "Resources/NornaSculpted.icon"], resources: [.copy("Resources/NornaKit.icns"), .process("Resources/en.lproj"), .process("Resources/zh-Hans.lproj")]),
        .testTarget(name: "NornaKitTests", dependencies: ["NornaKit", "NornaExamples"]),
        .testTarget(name: "NornaStudioTests", dependencies: ["NornaStudio", "NornaKit", "NornaExamples"])
    ],
    swiftLanguageModes: [.v5]
)
