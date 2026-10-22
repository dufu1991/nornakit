"""Independently inspect exported Windows native images, SVGs and searchable PDFs."""
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

from PIL import Image
from pypdf import PdfReader

directory = Path(sys.argv[1])
result = json.loads((directory / "result.json").read_text(encoding="utf-8"))
assert result["status"] == "passed"
assert result["architecture"] in {"X64", "Arm64"}
for appearance in ("light", "dark"):
    images = {}
    for format_name in ("png", "jpeg", "tiff"):
        with Image.open(directory / f"native-{appearance}.{format_name}") as image:
            image.load()
            assert image.width == (result["width"] + 32) * 2
            assert image.height == (result["height"] + 32) * 2
            assert image.convert("RGB").getextrema() != ((255, 255),) * 3
            images[format_name] = image.size
    assert len(set(images.values())) == 1
    with Image.open(directory / f"native-{appearance}-transparent.png") as image:
        assert image.mode == "RGBA"
        assert image.getpixel((0, 0))[3] == 0
    svg = ET.parse(directory / f"native-{appearance}.svg")
    assert any(node.tag.endswith("text") and "NornaKit" in (node.text or "") for node in svg.iter())
    reader = PdfReader(directory / f"native-{appearance}.pdf")
    assert len(reader.pages) == 1
    page = reader.pages[0]
    extracted = page.extract_text()
    for expected in ("NornaKit", "Windows", "你好，世界。", "粗体", "斜体", "原生富文本", "render(source)"):
        assert expected in extracted, (expected, extracted)
    fonts = page["/Resources"]["/Font"]
    assert len(fonts) >= 3
    for reference in fonts.values():
        font = reference.get_object()
        assert "/ToUnicode" in font
        assert "/FontFile2" in font["/DescendantFonts"][0]["/FontDescriptor"]
    assert b"/ActualText" in page.get_contents().get_data()
print(f"Verified {result['architecture']} native export formats and searchable bilingual PDF text.")
