"""Keep native Windows documentation reachable and unpublished downloads disabled."""
from html.parser import HTMLParser
from pathlib import Path
import re

site = Path(__file__).resolve().parents[1] / "dist"
config = (site / "download-config.js").read_text(encoding="utf-8")
match = re.search(r"windowsStudioDownloads\s*=\s*Object\.freeze\(\{\s*version:\s*(null|'[^']+'),\s*x64:\s*(null|'[^']+'),\s*arm64:\s*(null|'[^']+')\s*\}\)", config)
assert match, "Missing explicit Windows release configuration."
version, x64, arm64 = (None if value == "null" else value[1:-1] for value in match.groups())
if version is None:
    assert x64 is None and arm64 is None
else:
    assert re.fullmatch(r"\d+\.\d+\.\d+", version)
    for architecture, url in [("x64", x64), ("arm64", arm64)]:
        assert url == f"https://github.com/dufu1991/nornakit/releases/download/studio-windows-v{version}/NornaStudio-windows-{architecture}-{version}-setup.exe"


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []

    def handle_starttag(self, tag, attributes):
        if tag == "a":
            self.links.append(dict(attributes))


page = Links()
page.feed((site / "windows.html").read_text(encoding="utf-8"))
downloads = [link for link in page.links if "data-windows-download" in link]
assert {link["data-windows-download"] for link in downloads} == {"x64", "arm64"}
assert all("href" not in link and link.get("aria-disabled") == "true" for link in downloads)
for name in ["index.html", "docs.html"]:
    links = Links()
    links.feed((site / name).read_text(encoding="utf-8"))
    assert any(link.get("href") == "windows.html" for link in links.links), name
print("Verified Windows Kit links and explicit release-gated downloads.")
