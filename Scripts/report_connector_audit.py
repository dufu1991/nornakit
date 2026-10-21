#!/usr/bin/env python3
"""Present native connector audit fixtures without third-party rendering."""

from collections import defaultdict
from html import escape
import json
from pathlib import Path
import sys


def main():
    directory = Path(sys.argv[1] if len(sys.argv) > 1 else 'build/ConnectorAudit')
    entries = json.loads((directory / 'geometry.json').read_text(encoding='utf-8'))
    examples = defaultdict(list)
    for entry in entries:
        examples[entry['id']].append(entry)
        for extension in ['png', 'svg', 'mmd']:
            path = directory / str(entry['width']) / (entry['id'] + '.' + extension)
            if not path.is_file():
                raise SystemExit(f'缺少原生预览：{path}')
    issues = [{'id': e['id'], 'width': e['width'], 'issues': e['issues']} for e in entries if e['issues']]
    summary = {
        'examples': len(examples), 'kinds': len({e['kind'] for e in entries}),
        'cases': len(entries), 'widths': sorted({e['width'] for e in entries}),
        'connectionCases': sum(e['connections'] > 0 for e in entries),
        'connections': sum(e['connections'] for e in entries), 'issues': issues,
    }
    (directory / 'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    cards = []
    for example_id, variants in examples.items():
        if {e['width'] for e in variants} != {320, 640, 1200}:
            raise SystemExit(f'缺少尺寸变体：{example_id}')
        entry = next(e for e in variants if e['width'] == 640)
        status = '几何检查通过' if entry['connections'] else '图形结构预览'
        if any(e['issues'] for e in variants):
            status = '存在待修复问题'
        label = escape(example_id)
        cards.append(f'''<article data-id="{label}" data-search="{escape(entry['title'] + ' ' + entry['kind'] + ' ' + example_id)}">
<h2>{escape(entry['title'])}</h2><p>{escape(entry['kind'])} · {entry['connections']} 条关系连线 · {status}</p>
<a class="preview" href="640/{label}.svg"><img loading="lazy" src="640/{label}.png" alt="{escape(entry['title'])}"></a>
<footer><a class="vector" href="640/{label}.svg">查看矢量图</a><a class="source" href="640/{label}.mmd">查看源码</a><code>{label}</code></footer></article>''')
    html = '''<!doctype html>
<html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>全部示例连线检查</title><style>
:root { color-scheme: light dark; font: 15px/1.6 -apple-system, BlinkMacSystemFont, sans-serif; }
* { box-sizing: border-box; } body { max-width: 1680px; margin: auto; padding: 32px; background: Canvas; color: CanvasText; }
h1 { font-size: 28px; margin: 0; } h2 { font-size: 17px; margin: 0; } p { color: GrayText; margin: 6px 0 16px; }
.controls { position: sticky; top: 0; display: flex; gap: 16px; align-items: center; flex-wrap: wrap; padding: 16px 0; background: Canvas; z-index: 1; }
input, select { font: inherit; padding: 6px 10px; border: 1px solid GrayText; border-radius: 8px; background: Canvas; color: CanvasText; }
input { min-width: 240px; } main { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 28px; }
article { min-width: 0; padding-top: 20px; border-top: 1px solid color-mix(in srgb, CanvasText 12%, transparent); }
article[hidden] { display: none; } article p, footer { font-size: 12px; } a { color: LinkText; text-underline-offset: 3px; }
.preview { display: flex; height: 520px; border: 1px solid color-mix(in srgb, CanvasText 12%, transparent); border-radius: 12px; overflow: hidden; background: white; }
img { width: 100%; height: 100%; object-fit: contain; } footer { display: flex; gap: 16px; padding: 10px 0; flex-wrap: wrap; } code { color: GrayText; }
@media (max-width: 820px) { body { padding: 20px; } main { grid-template-columns: 1fr; } .preview { height: 440px; } }
</style><h1>全部示例连线检查</h1>'''
    html += f"<p>{summary['kinds']} 类图形，{summary['examples']} 个内置示例，{summary['cases']} 个尺寸场景。" \
        f"关系图共检查 {summary['connections']} 条连线，发现 {len(issues)} 个异常场景。</p>"
    html += '''<p>几何检查包括可省略的同轴绕行、共线段重叠、节点遮挡，以及线内标签归属。分支与绕行保留圆角；目录主干、铁路汇合、桑基流带和数据坐标轴保留各自语义。点击图片可放大查看原生矢量输出。</p>
<div class="controls"><label>布局宽度 <select id="width"><option>320</option><option selected>640</option><option>1200</option></select></label>
<input id="search" type="search" placeholder="搜索图形、示例名称"><span id="count"></span></div><main>'''
    html += ''.join(cards)
    html += '''</main><script>
const cards = [...document.querySelectorAll('article')];
const update = () => {
  const width = document.querySelector('#width').value;
  const search = document.querySelector('#search').value.trim().toLocaleLowerCase();
  cards.forEach((card) => {
    card.hidden = !card.dataset.search.toLocaleLowerCase().includes(search);
    const stem = `${width}/${card.dataset.id}`;
    card.querySelector('img').src = `${stem}.png`;
    card.querySelector('.preview').href = `${stem}.svg`;
    card.querySelector('.vector').href = `${stem}.svg`;
    card.querySelector('.source').href = `${stem}.mmd`;
  });
  document.querySelector('#count').textContent = `${cards.filter((card) => !card.hidden).length} 个示例`;
};
document.querySelector('#width').addEventListener('change', update);
document.querySelector('#search').addEventListener('input', update);
update();
</script></html>'''
    (directory / 'index.html').write_text(html, encoding='utf-8')
    print(json.dumps(summary, ensure_ascii=False))
    if issues:
        raise SystemExit('连线检查尚有未解决的问题。')


if __name__ == '__main__':
    main()
