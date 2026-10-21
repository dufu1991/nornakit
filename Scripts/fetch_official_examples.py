#!/usr/bin/env python3
"""Snapshot the public Pele example pages without rewriting their Mermaid source."""
import concurrent.futures
import datetime
import hashlib
import json
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
BASE = "https://pele.run"
FENCE = re.compile(r"^```mermaid[^\n]*\n(.*?)^```[ \t]*$", re.M | re.S)


def fetch(path):
    return subprocess.run(["curl", "--fail", "--silent", "--show-error", "--location", "--retry", "2", "--max-time", "40", BASE + path], check=True, capture_output=True).stdout.decode("utf-8")


def main():
    index = fetch("/examples.md")
    paths = list(dict.fromkeys(re.findall(r"\[All examples\]\((/examples/[^)]+)\)", index)))
    if len(paths) != 32:
        raise ValueError(f"Expected 32 example pages, received {len(paths)}; inspect the upstream index")
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        documents = [index, *pool.map(fetch, [path + ".md" for path in paths])]
    paths = ["/examples", *paths]
    directory = ROOT / "Baselines" / "OfficialSources"
    directory.mkdir(parents=True, exist_ok=True)
    entries = {}
    aliases = {"git": "gitGraph", "quadrant": "quadrantChart", "treeview": "treeView"}
    titles = {"Entity relationship": "er", "Git graph": "git", "Quadrant chart": "quadrant", "User journey": "journey", "XY chart": "xychart", "Tree view": "treeview", "Use case": "usecase", "Wardley map": "wardley", "Event modeling": "eventmodeling"}
    pages = []
    for path, markdown in zip(paths, documents):
        file = path.removeprefix("/").replace("/", "-") + ".md"
        (directory / file).write_text(markdown, encoding="utf-8")
        matches = list(FENCE.finditer(markdown))
        pages.append({"url": BASE + path, "file": file, "sha256": hashlib.sha256(markdown.encode()).hexdigest(), "exampleCount": len(matches)})
        for index, match in enumerate(matches):
            source = match[1]
            digest = hashlib.sha256(source.encode()).hexdigest()
            headings = re.findall(r"^## (.+)$", markdown[:match.start()], re.M)
            group = headings[-1] if headings else path.rsplit("/", 1)[-1]
            slug = titles.get(group, group.lower().replace(" ", "")) if path == "/examples" else path.rsplit("/", 1)[-1]
            kind = aliases.get(slug, slug)
            origin = {"url": BASE + path, "ordinal": index + 1, "section": group}
            if digest in entries:
                entries[digest]["origins"].append(origin)
            else:
                entries[digest] = {"id": "official-" + digest[:16], "kind": kind, "sha256": digest, "source": source, "origins": [origin]}
    result = {"schemaVersion": 1, "retrievedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(), "pages": pages, "examples": list(entries.values())}
    output = ROOT / "Sources" / "NornaKit" / "Resources" / "official-examples.json"
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"pages": len(pages), "occurrences": sum(page["exampleCount"] for page in pages), "uniqueExamples": len(entries)}, indent=2))


if __name__ == "__main__":
    main()
