"""Create the portable usage guide and a reusable icon package."""
import base64
import json
import mimetypes
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
folder = root / 'build/Branding/IconSystem'

def uri(name):
    mime = mimetypes.guess_type(name)[0] or 'application/octet-stream'
    return f'data:{mime};base64,' + base64.b64encode((folder / name).read_bytes()).decode()

matrix = [
    {'context': 'macOS APP', 'style': '立体 N 与系统材质', 'asset': 'Sources/NornaStudio/Resources/NornaSculpted.icon', 'rule': '用于 Dock、Finder 和应用介绍，保留六种系统外观。'},
    {'context': '站点标识', 'style': '无底板的曲线矢量', 'asset': 'symbol-mono.svg', 'rule': '用于导航、页脚与文档，颜色跟随站点主题，与 NornaKit 文字组合。'},
    {'context': '浏览器标签页', 'style': '独立微型版', 'asset': 'favicon.svg / favicon.ico', 'rule': '保留曲线 N 和四个端点，去除反光与阴影，优先保证 16 像素可辨识。'},
    {'context': 'Safari 固定标签', 'style': '单色轮廓', 'asset': 'safari-pinned-tab.svg', 'rule': '不包含底板，浏览器负责施色。'},
    {'context': '收藏与主屏幕', 'style': '平面底板版', 'asset': 'apple-touch-icon.png / web-icon-*.png', 'rule': 'PNG 背景不透明，系统负责裁切；可裁切版本增加安全留白。'},
    {'context': '站点分享', 'style': '横向品牌封面', 'asset': 'social-cover.png', 'rule': '1200 × 630 像素，表达站点身份，不使用微型 favicon 放大代替。'}
]
(folder / 'usage.json').write_text(json.dumps({'brand': 'NornaKit', 'applications': matrix}, ensure_ascii=False, indent=2) + '\n')
rows = ''.join(f'<tr><td>{item["context"]}</td><td>{item["style"]}</td><td><code>{item["asset"]}</code><p>{item["rule"]}</p></td></tr>' for item in matrix)
micro = ''.join(f'<div><img src="{uri(f"favicon-{size}.png")}" width="{size}" height="{size}" alt="{size} 像素 favicon"><span>{size} px</span></div>' for size in [16, 32, 48, 64])
downloads = ''.join(f'<a download="{name}" href="{uri(name)}">{name}</a>' for name in ['symbol.svg', 'symbol-dark.svg', 'symbol-mono.svg', 'favicon.svg', 'favicon.ico', 'apple-touch-icon.png', 'safari-pinned-tab.svg'])
html = '''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>NornaKit · 图标使用方案</title><style>
:root{color-scheme:light dark;--bg:#fafaf9;--surface:#fff;--ink:#202026;--muted:#696975;--line:#e6e6ed;--accent:#5148d8}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.7 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}main{max-width:1160px;margin:auto;padding:58px 28px 70px}header{display:flex;justify-content:space-between;align-items:start;gap:24px}.eyebrow{font-size:12px;color:var(--accent);letter-spacing:.12em}h1{font-size:42px;line-height:1.2;margin:12px 0 20px;letter-spacing:-1.5px}h2{margin:0 0 20px;font-size:25px}p{color:var(--muted);margin:12px 0}button,.pill{border:1px solid var(--line);border-radius:24px;padding:9px 16px;background:var(--surface);color:var(--ink);font:inherit;white-space:nowrap}button{cursor:pointer}a{color:var(--accent);text-decoration:none}a:hover{text-decoration:underline}section{margin-top:44px}.cards{display:grid;grid-template-columns:repeat(3,1fr);gap:20px}.card{background:var(--surface);border:1px solid var(--line);border-radius:22px;padding:24px}.art{height:210px;display:grid;place-items:center}.art img{width:156px;height:156px;object-fit:contain}.card h2{font-size:19px;margin:16px 0 6px}.card p{font-size:14px}.vector{width:156px;height:156px;background:var(--accent);mask:center/contain no-repeat url(MONO);-webkit-mask:center/contain no-repeat url(MONO)}.on-dark{background:#202026;border-radius:18px;display:flex;justify-content:center;align-items:center;height:140px;gap:16px;color:#fff}.on-dark .vector{width:70px;height:70px;background:#aaa4ff}.wordmark{font-size:30px;font-weight:650;letter-spacing:-1px}.samples{display:flex;gap:42px;align-items:end;min-height:120px}.samples div{display:flex;flex-direction:column;gap:12px;align-items:center}.samples span{font-size:13px;color:var(--muted)}table{width:100%;border-collapse:collapse}th,td{border-bottom:1px solid var(--line);padding:18px 12px;text-align:left;vertical-align:top}th{font-size:13px;color:var(--muted)}td p{font-size:13px;margin:6px 0 0}code{font:12px ui-monospace,monospace;overflow-wrap:anywhere}.downloads{display:flex;flex-wrap:wrap;gap:12px}.downloads a{border:1px solid var(--line);border-radius:9px;padding:8px 12px;font-size:13px}.cover{width:100%;max-width:720px;border:1px solid var(--line);border-radius:16px}footer{margin-top:50px;padding-top:24px;border-top:1px solid var(--line);color:var(--muted);font-size:13px}.reference{font-size:13px}.light-icon{display:block}.dark-icon{display:none}:root[data-theme=dark]{--bg:#171719;--surface:#222226;--ink:#ededf3;--muted:#b0b0be;--line:#393942;--accent:#aaa4ff}:root[data-theme=dark] .light-icon{display:none}:root[data-theme=dark] .dark-icon{display:block}@media(max-width:760px){main{padding:36px 20px}h1{font-size:32px}.cards{grid-template-columns:1fr}header{flex-wrap:wrap}.samples{gap:22px}table{font-size:13px}th,td{padding:12px 4px}.art{height:180px}}
</style></head><body><main><header><div><span class="eyebrow">NORNA · ICON SYSTEM</span><h1>同一个 N，适配不同场景。</h1><p>立体用于 APP，矢量用于站点，微型版用于标签页。<br>共同保留曲线与四个端点，按显示尺寸调整细节。</p></div><button id="appearance">切换浅深色</button></header>
<section class="cards"><article class="card"><div class="art"><img class="light-icon" src="APP_LIGHT" alt="Norna Studio 立体 APP 图标"><img class="dark-icon" src="APP_DARK" alt="Norna Studio 暗色立体 APP 图标"></div><h2>01 · APP 图标</h2><p>保留选定原稿的曲线、厚度和光泽。继续使用原生 Icon Composer 六种外观，不因站点简化而改变。</p></article><article class="card"><div class="art"><span class="vector"></span></div><h2>02 · 站点矢量标识</h2><p>去掉底板、阴影与高光，适合导航和文档。颜色跟随站点主题，SVG 在高分辨率屏幕保持清晰。</p></article><article class="card"><div class="art"><img src="FAVICON" alt="NornaKit 微型标签页图标"></div><h2>03 · 微型 favicon</h2><p>在 16 像素网格重新安排线宽和端点，使用高对比度底板，提供 SVG、PNG 和真实多尺寸 ICO。</p></article></section>
<section><h2>站点组合与实际小尺寸</h2><div class="on-dark"><span class="vector"></span><span class="wordmark">NornaKit</span></div><div class="samples">MICRO</div></section>
<section><h2>使用位置与对应文件</h2><table><thead><tr><th>位置</th><th>方案</th><th>文件与规则</th></tr></thead><tbody>ROWS</tbody></table></section>
<section><h2>分享预览</h2><img class="cover" src="COVER" alt="NornaKit 站点分享封面"><p class="reference">主屏幕图标保留系统裁切空间；可裁切版本的核心内容位于中心安全圆内。<a href="https://w3c.github.io/manifest/#icon-masks">Web App Manifest 规范</a>。<a href="https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/How_to/Define_app_icons">图标格式参考</a>。</p></section>
<section><h2>下载与复用</h2><div class="downloads">DOWNLOADS</div><p><a href="../nornakit-icon-pack.zip" download>下载完整图标包，含原生 APP 图标源文件</a></p></section>
<footer>本站导航、页脚和文档使用矢量版；APP 介绍区使用立体版；标签页与主屏幕使用各自的图标。请勿将单一图片等比例缩小后用于所有位置。</footer></main><script>document.querySelector('#appearance').addEventListener('click',()=>{document.documentElement.dataset.theme=document.documentElement.dataset.theme==='dark'?'light':'dark'});</script></body></html>'''
for key, value in {'MONO': uri('symbol-mono.svg'), 'APP_LIGHT': uri('app-icon-light.png'), 'APP_DARK': uri('app-icon-dark.png'), 'FAVICON': uri('favicon-256.png'), 'COVER': uri('social-cover.png'), 'MICRO': micro, 'ROWS': rows, 'DOWNLOADS': downloads}.items():
    html = html.replace(key, value)
(folder / 'index.html').write_text(html)
archive = folder.parent / 'nornakit-icon-pack.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as bundle:
    for path in sorted(folder.glob('*')):
        if path.is_file(): bundle.write(path, 'Web/' + path.name)
    document = root / 'Sources/NornaStudio/Resources/NornaSculpted.icon'
    for path in sorted(document.rglob('*')):
        if path.is_file(): bundle.write(path, 'App/NornaSculpted.icon/' + str(path.relative_to(document)))
    bundle.write(root / 'Sources/NornaStudio/Resources/NornaKit.icns', 'App/NornaKit.icns')
    for path in sorted((root / 'build/Branding/AppIcon').glob('norna-icon-*.png')):
        bundle.write(path, 'App/Previews/' + path.name)
print(f'Wrote {folder / "index.html"} and {archive}.')
