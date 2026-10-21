#!/usr/bin/env python3
"""Build an offline gallery from Swift-generated system appearance fixtures."""

from html import escape
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET


def comparison_gallery(directory, entries):
    appearances = ["appleLight", "appleDark", "appleLightHighContrast", "appleDarkHighContrast"]
    styles = ["", "-themed"] if any(directory.glob("*-themed-appleLight.png")) else [""]
    sections = []
    for entry in entries:
        kind, title = entry["kind"], entry["title"]
        paired = entry["mode"] == "comparison"
        samples = [(kind, "简单示例" if paired else "示例", "simple")]
        if paired:
            samples.append((kind + "-complex", "复杂示例", "complex"))
        cards = []
        for stem, label, source_kind in samples:
            for appearance in appearances:
                for style in styles:
                    for extension in ["png", "svg"]:
                        if not (directory / f"{stem}{style}-{appearance}.{extension}").is_file():
                            raise SystemExit(f"缺少原生预览：{stem}{style}-{appearance}.{extension}")
            source = f"{kind}-{source_kind}.mmd"
            if not (directory / source).is_file():
                raise SystemExit(f"缺少示例源码：{source}")
            cards.append(f'''<article><h3>{label}</h3>
<a class="preview" data-stem="{escape(stem)}" href="{escape(stem)}-appleLight.svg"><img loading="lazy" src="{escape(stem)}-appleLight.png" alt="{escape(title)}，{label}"></a>
<div class="links"><a class="svg" data-stem="{escape(stem)}" href="{escape(stem)}-appleLight.svg">查看矢量图</a><a href="{escape(source)}">查看源码</a></div></article>''')
        sections.append(f'''<section id="{escape(kind)}"><h2>{escape(title)}</h2><p>{escape(entry["note"])}</p><div class="samples {"paired" if paired else "single"}">{"".join(cards)}</div></section>''')
    pair_count = sum(entry["mode"] == "comparison" for entry in entries)
    navigation = "".join(f'<a href="#{escape(entry["kind"])}">{escape(entry["title"])}</a>' for entry in entries)
    html = '''<!doctype html>
<html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>原生图形示例对照</title><style>
:root { color-scheme: light dark; font: 16px/1.6 -apple-system, BlinkMacSystemFont, sans-serif; }
* { box-sizing: border-box; } body { margin: 0 auto; padding: 32px; max-width: 1600px; background: Canvas; color: CanvasText; }
h1 { margin: 0; font-size: 28px; letter-spacing: -.02em; } p { color: GrayText; margin: 8px 0 20px; }
.controls { position: sticky; top: 0; z-index: 1; padding: 16px 0; background: Canvas; display: flex; align-items: center; gap: 12px; }
select { font: inherit; color: CanvasText; background: Canvas; border: 1px solid GrayText; border-radius: 8px; padding: 6px 10px; }
nav { display: flex; flex-wrap: wrap; gap: 8px 20px; margin: 16px 0 32px; } a { color: LinkText; text-underline-offset: 3px; }
nav a { font-size: 14px; } section { padding: 24px 0; border-top: 1px solid color-mix(in srgb, CanvasText 12%, transparent); scroll-margin-top: 80px; }
h2 { margin: 0; font-size: 20px; } h3 { margin: 0 0 12px; font-size: 15px; font-weight: 600; }
.samples { display: grid; gap: 24px; } .paired { grid-template-columns: repeat(2, minmax(0, 1fr)); } .single { max-width: 760px; }
article { min-width: 0; } .preview { display: flex; height: 460px; align-items: center; justify-content: center; border: 1px solid color-mix(in srgb, CanvasText 12%, transparent); border-radius: 12px; overflow: hidden; }
img { display: block; width: 100%; height: 100%; object-fit: contain; } .links { display: flex; gap: 20px; margin-top: 10px; font-size: 13px; }
@media (max-width: 760px) { body { padding: 20px; } .paired { grid-template-columns: 1fr; } .preview { height: 360px; } }
</style><h1>原生图形示例对照</h1>'''
    html += f'<p>{len(entries)} 类图形，{pair_count} 类提供简单与复杂对照，{len(entries) - pair_count} 类保留单例。示例展示数据规模带来的布局差异，图像和矢量图均由 Swift 原生绘制器生成。</p>'
    html += '''<div class="controls"><label for="appearance">系统外观</label><select id="appearance">
<option value="appleLight">浅色</option><option value="appleDark">深色</option><option value="appleLightHighContrast">浅色高对比度</option><option value="appleDarkHighContrast">深色高对比度</option>
</select></div>'''
    if len(styles) > 1:
        html = html.replace('</select></div>', '''</select><label for="color-style">图表风格</label><select id="color-style">
<option value="">无主题色</option><option value="-themed" selected>主题色</option></select></div>''', 1)
    html += f'<nav aria-label="图形类型">{navigation}</nav>' + "".join(sections)
    html += '''<script>
const updatePreviews = () => {
  const appearance = document.querySelector('#appearance').value;
  const style = document.querySelector('#color-style')?.value ?? '';
  document.querySelectorAll('[data-stem]').forEach((link) => {
    const base = `${link.dataset.stem}${style}-${appearance}`;
    link.href = `${base}.svg`;
    const image = link.querySelector('img');
    if (image) image.src = `${base}.png`;
  });
};
document.querySelector('#appearance').addEventListener('change', updatePreviews);
document.querySelector('#color-style')?.addEventListener('change', updatePreviews);
updatePreviews();
</script></html>'''
    target = directory / "index.html"
    target.write_text(html, encoding="utf-8")
    print(f"已生成 {len(entries)} 类图形的预览，其中 {pair_count} 类提供双示例：{target}")


def main():
    directory = Path(sys.argv[1] if len(sys.argv) > 1 else "build/ApplePreviews")
    manifest = directory / "examples-manifest.json"
    if manifest.is_file():
        comparison_gallery(directory, json.loads(manifest.read_text(encoding="utf-8")))
        return
    appearances = {
        "appleLight": "浅色",
        "appleDark": "深色",
        "appleLightHighContrast": "浅色高对比度",
        "appleDarkHighContrast": "深色高对比度",
    }
    sources = sorted(source for source in directory.glob("*-appleLight.svg") if not source.name.endswith("-themed-appleLight.svg"))
    if not sources:
        raise SystemExit("请先设置 NORNA_APPLE_FIXTURE_DIR 并运行 Swift 测试，生成原生预览。")
    sections = []
    for source in sources:
        kind = source.name.removesuffix("-appleLight.svg")
        title = ET.parse(source).getroot().find("{http://www.w3.org/2000/svg}title").text
        figures = []
        for appearance, label in appearances.items():
            stem = f"{kind}-{appearance}"
            for suffix in [".png", ".svg"]:
                if not (directory / (stem + suffix)).is_file():
                    raise SystemExit(f"缺少预览：{stem}{suffix}")
            figures.append(f'<figure><a href="{escape(stem)}.svg"><img loading="lazy" src="{escape(stem)}.png" alt="{escape(title)}，{label}"></a><figcaption>{label}</figcaption></figure>')
        sections.append(f'<section id="{escape(kind)}"><h2>{escape(title)}</h2><div class="variants">{"".join(figures)}</div></section>')
    html = """<!doctype html>
<html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>原生图形预览</title><style>
:root { color-scheme: light dark; font: 16px/1.6 -apple-system, BlinkMacSystemFont, sans-serif; }
body { margin: 0 auto; padding: 32px; max-width: 1600px; background: Canvas; color: CanvasText; }
h1 { margin: 0; font-size: 28px; letter-spacing: -.02em; } p { color: GrayText; }
section { padding: 24px 0; border-top: 1px solid color-mix(in srgb, CanvasText 12%, transparent); }
h2 { margin: 0 0 16px; font-size: 20px; } .variants { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 16px; }
figure { margin: 0; min-width: 0; } a { display: flex; height: 300px; align-items: center; justify-content: center; border: 1px solid color-mix(in srgb, CanvasText 12%, transparent); border-radius: 8px; overflow: hidden; }
img { display: block; width: 100%; height: 100%; object-fit: contain; } figcaption { margin-top: 8px; font-size: 13px; color: GrayText; }
@media (max-width: 1000px) { .variants { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
@media (max-width: 560px) { body { padding: 20px; } .variants { grid-template-columns: 1fr; } }
</style><h1>原生图形预览</h1>
"""
    html += f"<p>{len(sources)} 类图形，四种系统外观。图像由 Swift 原生绘制器生成，点击可查看同一场景导出的 SVG。这里展示各类型的基础能力，完整语法范围见项目支持矩阵。</p>"
    html += "".join(sections) + "</html>"
    target = directory / "index.html"
    target.write_text(html, encoding="utf-8")
    print(f"已生成 {len(sources)} 类图形的预览：{target}")


if __name__ == "__main__":
    main()
