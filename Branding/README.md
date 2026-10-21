# Norna 图标使用规范

同一品牌保留曲线 N 和四个端点，根据场景调整材质、细节、底板和留白。

| 使用位置 | 方案 | 实际使用资源 |
| --- | --- | --- |
| macOS APP、Dock 和 Finder | 用户选定的立体版，保留曲线、厚度与光泽，适配系统外观 | `Sources/NornaStudio/Resources/NornaSculpted.icon` |
| 网站导航、页脚和文档 | 无底板的矢量版，通过 CSS 跟随站点主题色；与系统字体的 Norna 文字组合 | `symbol-mono.svg` |
| 独立品牌标识、印刷和演示 | 纯色 SVG；浅底用靛蓝，深底用浅紫，单色环境使用蒙版版 | `symbol.svg`、生成的 `symbol-dark.svg` 和 `symbol-mono.svg` |
| 浏览器标签页与 ICO | 独立绘制的微型版，减少内凹细节，加粗线条，使用高对比度底板 | `favicon.svg`、16 至 256 像素 PNG 和多尺寸 `favicon.ico` |
| Safari 固定标签页 | 单色轮廓，由浏览器施加颜色 | `safari-pinned-tab.svg` |
| 收藏和添加到主屏幕 | 不透明的平面版，保留系统裁切空间，区分网站与原生 APP | `apple-touch-icon.png`、`web-icon-192.png`、`web-icon-512.png` |
| 可裁切的主屏幕图标 | 额外增加留白，核心形状放在中心安全圆内 | `web-icon-maskable-512.png` |
| 站点分享预览 | 横向封面，包含品牌、说明和矢量标识 | `social-cover.png` |
| 网站中介绍 Norna Studio | 使用真实 APP 图标的浅深色截图，不代替站点导航标识 | `app-icon-light.png`、`app-icon-dark.png` |

`symbol.svg` 和 `symbol-mono.svg` 共用同一曲线几何。`favicon.svg` 针对 16 像素网格单独设计，不能用缩小立体 APP 图标代替。SVG favicon 跟随浏览器的系统外观；站点导航标识跟随站点自身的浅深色选择。传统 ICO 固定使用靛蓝底和白色标识。

主屏幕 PNG 不预先裁切圆角，交给系统处理。可裁切版本的核心图形位于半径为边长 40％ 的中心圆内。网站 manifest 提供图标元数据，不声明离线能力。

生成资源：

```sh
swift Scripts/build_brand_assets.swift
python3 website/scripts/sync-brand.py
python3 website/scripts/verify-brand.py
```

完整资源、尺寸对照图和本地使用指南位于 `build/Branding/IconSystem/`。原生 APP 图标继续由 `Scripts/render_app_icon.swift` 生成，本站资源生成过程不会修改原生 APP 图标。

小尺寸下避免阴影、反光和文字；不要把立体 APP 图标用于 favicon，不要把微型底板图标用于站点的大面积品牌展示，不要拉伸或旋转标识。

技术参考：[MDN 图标说明](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/How_to/Define_app_icons)、[Web App Manifest 可裁切图标规范](https://w3c.github.io/manifest/#icon-masks)。
