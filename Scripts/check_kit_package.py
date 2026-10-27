#!/usr/bin/env python3
"""Build a real Kit-only consumer and reject compiled examples or copied sample data."""
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    with tempfile.TemporaryDirectory(prefix="norna-kit-consumer-") as temporary:
        directory = Path(temporary)
        (directory / "Package.swift").write_text(f'''// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "KitConsumer",
    platforms: [.macOS(.v14)],
    dependencies: [.package(name: "NornaKit", path: {json.dumps(str(ROOT))})],
    targets: [.executableTarget(name: "KitConsumer", dependencies: [.product(name: "NornaKit", package: "NornaKit")])]
)
''', encoding="utf-8")
        sources = directory / "Sources/KitConsumer"
        sources.mkdir(parents=True)
        (sources / "main.swift").write_text('''import NornaKit
let diagram = try await NativeDiagramRenderer().render("flowchart LR\\n A[Source] --> B[Native diagram]")
precondition(diagram.scene.nodes.count == 2)
precondition(diagram.svg.contains("<svg"))
''', encoding="utf-8")
        subprocess.run([
            "swift", "run", "--package-path", str(directory), "--disable-sandbox",
            "--build-system", "native", "KitConsumer",
        ], check=True)
        artifacts = directory / ".build"
        unwanted = []
        for path in artifacts.rglob("*"):
            compiled_support = path.suffix in {".o", ".swiftmodule"} and any(
                part.startswith(("NornaExamples", "NornaStudio")) for part in path.relative_to(artifacts).parts)
            sample_bundle = path.suffix == ".bundle" and "NornaExamples" in path.name
            sample_data = path.name in {"examples.json", "official-examples.json", "official-status.json", "layout-fixtures.json"}
            if compiled_support or sample_bundle or sample_data:
                unwanted.append(str(path.relative_to(artifacts)))
        if unwanted:
            raise RuntimeError("Kit-only integration included sample artifacts: " + ", ".join(unwanted))
    print("Verified Kit-only rendering and SVG export without compiled examples or bundled sample data.")


if __name__ == "__main__":
    main()
