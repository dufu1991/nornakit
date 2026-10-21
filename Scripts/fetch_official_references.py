#!/usr/bin/env python3
"""Extract the website's already-rendered SVG; never execute JavaScript."""
import concurrent.futures
import hashlib
import html.parser
import json
import pathlib
import subprocess
import urllib.parse

ROOT = pathlib.Path(__file__).resolve().parents[1]


class Cards(html.parser.HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=False)
        self.cards = []
        self.card = None
        self.svg = None
        self.depth = 0
        self.variant = 640
        self.error = False

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        classes = values.get("class", "").split()
        if self.svg is not None:
            self.svg.append(self.get_starttag_text())
            if tag == "svg": self.depth += 1
            return
        if tag == "figure" and "example-card" in classes:
            self.card = {"svgs": {}, "error": "", "source": None}
            self.variant = 640
        if self.card is None: return
        if tag == "a" and "playground-link" in classes:
            self.card["source"] = urllib.parse.parse_qs(urllib.parse.urlsplit(values["href"]).fragment).get("source", [None])[0]
        if tag == "div":
            if "example-wide" in classes: self.variant = 640
            elif "example-medium" in classes: self.variant = 480
            elif "example-narrow" in classes: self.variant = 320
        if tag == "pre" and "example-error" in classes: self.error = True
        if tag == "svg" and "pele" in classes:
            self.svg = [self.get_starttag_text()]
            self.depth = 1

    def handle_endtag(self, tag):
        if self.svg is not None:
            self.svg.append("</" + tag + ">")
            if tag == "svg":
                self.depth -= 1
                if self.depth == 0:
                    self.card["svgs"][str(self.variant)] = "".join(self.svg)
                    self.svg = None
            return
        if tag == "pre": self.error = False
        if tag == "figure" and self.card is not None:
            self.cards.append(self.card)
            self.card = None

    def handle_startendtag(self, tag, attrs):
        if self.svg is not None: self.svg.append(self.get_starttag_text())

    def handle_data(self, data):
        if self.svg is not None: self.svg.append(data)
        elif self.error and self.card is not None: self.card["error"] += data

    def handle_entityref(self, name):
        self.handle_data("&" + name + ";")

    def handle_charref(self, name):
        self.handle_data("&#" + name + ";")


def main():
    snapshot = json.loads((ROOT / "Sources/NornaKit/Resources/official-examples.json").read_text())
    directory = ROOT / "Baselines/OfficialReference"
    directory.mkdir(parents=True, exist_ok=True)
    origins = {(origin["url"], origin["ordinal"]): item for item in snapshot["examples"] for origin in item["origins"]}

    def fetch(page):
        markup = subprocess.run(["curl", "--fail", "--silent", "--show-error", "--location", "--retry", "2", "--max-time", "60", page["url"]], check=True, capture_output=True).stdout.decode()
        parser = Cards(); parser.feed(markup)
        if len(parser.cards) != page["exampleCount"]:
            raise ValueError(f"Card count changed at {page['url']}: {len(parser.cards)}")
        results = []
        for ordinal, card in enumerate(parser.cards, 1):
            item = origins[(page["url"], ordinal)]
            if card["source"] is not None and card["source"].rstrip() != item["source"].rstrip():
                raise ValueError(f"Source mismatch at {page['url']} #{ordinal}")
            result = {"id": item["id"], "pageURL": page["url"], "ordinal": ordinal, "status": "rendered" if card["svgs"] else "rejected", "error": card["error"], "variants": {}}
            for width, svg in card["svgs"].items():
                data = svg.encode()
                digest = hashlib.sha256(data).hexdigest()
                file = f"{digest}.svg"
                (directory / file).write_bytes(data)
                result["variants"][width] = {"file": file, "sha256": digest}
            results.append(result)
        return results

    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
        results = [result for page in pool.map(fetch, snapshot["pages"]) for result in page]
    (ROOT / "Baselines/official-reference.json").write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"occurrences": len(results), "rendered": sum(r["status"] == "rendered" for r in results), "svgFiles": len(list(directory.glob('*.svg')))}, indent=2))


if __name__ == "__main__": main()
