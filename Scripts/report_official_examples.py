#!/usr/bin/env python3
"""Build an offline, per-source report from the native tests and website snapshots."""
import collections
import datetime
from zoneinfo import ZoneInfo
import html
import json
import pathlib
import xml.etree.ElementTree as XML

ROOT = pathlib.Path(__file__).resolve().parents[1]
BASE = ROOT / "Baselines"


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def main():
    snapshot = read(ROOT / "Sources/NornaKit/Resources/official-examples.json")
    display_time = datetime.datetime.fromisoformat(snapshot["retrievedAt"]).astimezone(ZoneInfo("Asia/Shanghai")).strftime("%Y 年 %m 月 %d 日 %H:%M")
    results = {item["id"]: item for item in read(BASE / "official-results.json")}
    before = read(BASE / "official-before.json")
    references = read(BASE / "official-reference.json")
    layouts = {(item["result"]["id"], item["requestedWidth"]): item["result"] for item in read(BASE / "official-layout-results.json")}
    by_id = collections.defaultdict(list)
    for reference in references: by_id[reference["id"]].append(reference)
    passing = sum(item["status"] == "rendered" for item in results.values())
    old_passing = sum(item["status"] == "rendered" for item in before)
    groups = collections.defaultdict(list)
    for example in snapshot["examples"]: groups[example["kind"]].append(example)
    summary = []
    details = []
    markdown = ["# 官网示例验证报告", "", f"快照时间：{display_time}（北京时间）。", "",
        f"覆盖总览与 32 个详情页，共 659 次示例展示，去重后为 600 份原始源码。官网静态页面中的 659 次展示均有 SVG。", "",
        f"首轮可生成 {old_passing} 份，本轮可生成 {passing} 份，剩余 {len(results) - passing} 份记录为待支持。", "",
        "这里的可生成表示完成原生解析与布局、SVG XML 有效及场景边界检查通过，不代表文字语义完整或与 Pele 像素一致。", "",
        "每份源码都在自然宽度以及 320、480、640 点宽度下尝试渲染。部分图形仍保留自然宽度，画布可以缩放和平移。", "",
        "[打开逐例图像对照](report.html)", "", "| 图形 | 可生成 | 待支持 | 总数 |", "| --- | ---: | ---: | ---: |"]
    summary_markdown, detailed_markdown = [], []
    for kind, examples in sorted(groups.items()):
        passed = sum(results[e["id"]]["status"] == "rendered" for e in examples)
        summary_markdown.append(f"| {kind} | {passed} | {len(examples) - passed} | {len(examples)} |")
        summary.append(f'<tr><td><a href="#{kind}">{kind}</a></td><td>{passed}</td><td>{len(examples) - passed}</td><td>{len(examples)}</td></tr>')
        rows = []
        detailed_markdown += ["", f"## {kind}", "", "| 示例 | 状态 | 原始位置 | 结果或原因 |", "| --- | --- | --- | --- |"]
        for index, example in enumerate(examples, 1):
            item = results[example["id"]]
            okay = item["status"] == "rendered"
            status = "可生成，视觉待核对" if okay else "待支持"
            origin = example["origins"][0]
            message = f"{item['width']:g} × {item['height']:g}" if okay else f"{item.get('code', '')}：{item.get('message', '')}"
            if not okay and item.get("line"): message += f" 第 {item['line']} 行。"
            detailed_markdown.append(f"| [{example['id']}](report.html#{example['id']}) | {status} | [第 {origin['ordinal']} 例]({origin['url']}) | {message.replace('|', '／').replace(chr(10), ' ')} |")
            reference = by_id[example["id"]][0]
            panels = []
            metrics = []
            for width in [640, 320]:
                variants = reference["variants"]
                variant = variants.get(str(width)) or variants.get("480") or variants["640"]
                ref_path = "OfficialReference/" + variant["file"]
                native = layouts[(example["id"], width)]
                root = XML.parse(BASE / ref_path).getroot()
                metrics.append(f"{width} 点：官网 SVG {root.get('width')} × {root.get('height')}；Swift " + (f"{native['width']:g} × {native['height']:g}" if native["status"] == "rendered" else "待支持"))
                native_panel = f'<img loading="lazy" src="NativeOutput/{example["id"]}-{width}.svg" alt="Swift 原生绘制"/>' if native["status"] == "rendered" else f'<pre>{html.escape(native.get("message", ""))}</pre>'
                panels.append(f'<h4>{width} 点容器</h4><div class="comparison"><div><p>官网参考</p><img loading="lazy" src="{ref_path}" alt="官网 SVG"/></div><div><p>Swift 原生输出</p>{native_panel}</div></div>')
            rows.append(f'''<details id="{example['id']}"><summary><span class="{'pass' if okay else 'pending'}">{status}</span> {index:02d} · {example['id']}</summary>
<p><a href="{origin['url']}">官网原页</a> · 第 {origin['ordinal']} 例 · <code>SHA-256: {example['sha256']}</code></p>
<p>{html.escape(message)}</p><p>{'<br>'.join(html.escape(metric) for metric in metrics)}</p>
{''.join(panels)}<details><summary>原始源码</summary><pre>{html.escape(example['source'])}</pre></details></details>''')
        details.append(f'<section id="{kind}"><h2>{kind} · {passed}/{len(examples)}</h2>{"".join(rows)}</section>')
    (BASE / "REPORT.md").write_text("\n".join(markdown + summary_markdown + detailed_markdown) + "\n", encoding="utf-8")
    document = f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>NornaKit 参考示例基准</title>
<style>body{{font:15px/1.7 system-ui,sans-serif;color:#202124;background:#f6f7f9;margin:0}}main{{max-width:1160px;margin:auto;padding:40px 24px}}h1,h2{{letter-spacing:-.03em}}h2{{margin-top:48px}}table{{border-collapse:collapse;width:100%;background:white}}td,th{{border-bottom:1px solid #e3e6eb;padding:8px 16px;text-align:left}}details{{background:white;border:1px solid #e0e3e8;border-radius:8px;margin:10px 0;padding:12px 16px}}summary{{cursor:pointer}}p{{overflow-wrap:anywhere}}a{{color:#315fba}}pre{{white-space:pre-wrap;overflow-wrap:anywhere;padding:16px;background:#f4f5f7;font:13px/1.7 ui-monospace,monospace}}.pass{{color:#267348}}.pending{{color:#9c5a13}}.comparison{{display:grid;grid-template-columns:1fr 1fr;gap:20px}}.comparison>div{{min-width:0;border:1px solid #eceef1;padding:12px}}img{{display:block;max-width:100%;max-height:640px;margin:auto}}code{{font-size:12px}}@media(max-width:720px){{.comparison{{grid-template-columns:1fr}}}}</style>
<main><h1>官网示例原始基准</h1><p>{display_time}（北京时间） · 33 个页面 · 600 份去重源码 · 659 次官网展示。</p>
<p>首轮 {old_passing} 份可生成，本轮 {passing} 份可生成，{len(results) - passing} 份待支持。所有源码均尝试自然宽度与 320、480、640 点布局。</p>
<p>可生成仅表示通过原生渲染和结构检查，视觉与完整语义仍需核对。下方提供官网静态 SVG 和纯 Swift 导出的 SVG；宽度以各自实际布局为准，不保证像素一致。官网未提供独立窄版时，显示其页面实际使用的较宽版本。报告及 SVG 存于本地，不执行脚本。部分官网 SVG 包含外部图片引用，本项目未下载这些图片。</p>
<table><thead><tr><th>图形</th><th>可生成</th><th>待支持</th><th>总数</th></tr></thead><tbody>{''.join(summary)}</tbody></table>
{''.join(details)}</main></html>'''
    (BASE / "report.html").write_text(document, encoding="utf-8")
    print(f"Report: {passing}/600 sources rendered; all 600 have explicit results")


if __name__ == "__main__": main()
