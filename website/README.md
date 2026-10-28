# NornaKit 介绍站

简洁的静态站点，沿用 NornaKit 的标志与靛蓝配色，以 Swift 与 C# 原生渲染库 NornaKit 的能力、示例和接入方式为主要内容。Norna Studio 作为配套的演示、渲染、调试与导出工具介绍。

- 中英文默认使用浏览器首选语言，其他语言使用英文。可以手动切换并记住选择。
- 浅深色默认跟随系统，也可以手动循环切换为浅色、深色与自动。
- 示例集覆盖 33 类图形与 3 个 SF Symbols 内置示例，共 36 个示例，均使用原生绘制的浅深色 PNG，提供源码复制、下载和截图放大。
- 工作台内置示例提供中英文源码。站点的首页、36 个示例及图标文档预览均提供中英文原生截图，源码、图片和下载随站点语言一起切换。
- 文档使用当前真实的 NornaKit 包名与 NornaKit 模块名。
- 源码仓库为 `https://github.com/dufu1991/nornakit`。首页与文档页顶部提供 GitHub 图标及仓库链接，在新标签页打开。文档页不提供 README 下载入口。顶部“工作台”入口使用 GitHub Releases 中最新工作台版本的 DMG 地址，首次发布成功后可下载。

## 首页结构

首页采用技术文档首页的排版：左对齐阅读流、吸顶导航，每个区块以标题加一句说明开头并带锚点。区块依次为：

1. 首屏：版本与平台标签、一句话定位、Swift Package 与 Windows 项目引用两个安装标签页，以及完整比例的原生 hero 截图。
2. `#start` 快速上手：三个步骤，配 Swift / C# 代码标签页。
3. `#platforms` 平台对照：macOS 与 Windows 在语言、系统、排版、绘制、导出、行内图标、接入方式和配套工具上的对照表。
4. `#features` 能力列表，后附支持范围说明。
5. `#examples` 示例：由 `examples.json` 生成的图表类型索引、源码与截图面板、全部截图画廊。
6. `#studio` Norna Studio：下载、Homebrew 命令与首次打开说明。
7. `#resources` 资源链接与页脚。

首页专属样式位于 `dist/home.css`，并以 `body.home` 限定范围；`style.css` 只保留文档页、Windows 页与首页共用的基础样式、截图外观、对话框与赞助弹窗。标签页共用一个复制按钮，复制当前可见面板中的代码。

本地预览：

```sh
python3 -m http.server 4173 --directory website/dist
```

刷新全站中英文源码及浅深色原生截图：

```sh
python3 website/scripts/prepare-assets.py
```

脚本先构建 NornaKit，再运行 `render-examples.swift` 和 `render-showcase.swift`。示例集直接读取 `DiagramExample` 的中英文源码，生成 36 个示例、每个示例各两种语言与两种外观的 PNG，以及对应的 `.mmd` 文件。`dist/examples.json` 中的 `sources.zh` 和 `sources.en` 与工作台使用同一份内容。最后自动校验源码、语言与截图资源是否齐全。

部署目录是 `dist`，不依赖前端构建工具或浏览器版 Mermaid。

## 页面控件

首页右上角与页脚的「赞助」入口打开原生弹窗，提供 Buy Me a Coffee、PayPal、微信赞赏与支付宝赞助。中英文文案随站点语言切换，二维码保留白色背景以便在浅深色外观下扫描。弹窗支持 Esc、关闭按钮和点击遮罩关闭，微信与支付宝二维码按需展开。

赞助链接与二维码沿用 [Any TDF 官网](https://any-tdf.dev/) 的支持入口，收款账号为 `dufu1991`。原始二维码保存在 `dist/assets/sponsorship/`，分别来自 `https://any-tdf.dev/assets/fund/wp_code.png` 与 `https://any-tdf.dev/assets/fund/ap_code.png`，中英文 README 与首页共用本地资源。更换收款方式时，同步更新两份 README、`dist/index.html` 与二维码文件，再执行站点构建同步文档。

`dist/components.js` 与 `dist/components.css` 提供无框架依赖的轻量控件，包括语言选择与外观选择，选择器也支持可搜索模式。菜单支持方向键、首尾导航、回车确认、Esc 关闭、点击外部关闭、输入法组合输入，以及手机可视区域内的定位。按钮、折叠区与截图弹窗共享圆角、描边和靛蓝焦点样式。

已评估 Base UI 与 Web Awesome。前者面向 React，后者可用于静态站；本次站点只有少量简单控件，采用本地组件实现，避免引入框架和外部运行时资源。

## 截图外观

首页、示例预览、全部示例缩略图和截图弹窗均使用中英文、浅深色四套原生 PNG，由页面语言与主题统一决定可见版本。默认跟随系统的浅深色外观，手动选择时跟随站点外观。系统外观变化时不重建示例列表，也不打断当前源码选择和弹窗滚动。截图下载链接同步使用当前版本，标签页间的外观选择也会同步。图片画布底色与原生截图一致。

校验首页与全部示例的浅深色资源对：

```sh
python3 website/scripts/verify-screenshots.py
```

示例区顶部的图表类型索引列出全部 36 个示例，点击即切换下方的源码与截图；源码面板标题显示当前示例名称。手机宽度下索引改为单行横向滚动。

截图预览弹窗支持上一张、下一张与键盘左右方向键，按示例集顺序循环浏览全部 36 个示例，并显示当前位置。切换后同步更新标题、下载链接和主预览区，继续使用当前外观对应的原生截图。

## 项目主题色

站点的强调色从应用的 `AccentColor.colorset` 生成，分别对应浅色、深色和两种高对比度外观，应用于主按钮、重点标题、链接、标志、选中状态和焦点。修改项目主题色后执行以下命令同步：

```sh
python3 website/scripts/sync-theme.py
```

截图弹窗按视口分配标题栏、预览区和操作栏。预览图保持原始比例，完整缩放到可用区域，不裁切内容，也不依赖内部滚动查看。

## 按场景使用图标

- 导航、页脚和文档标识使用 `assets/brand/symbol-mono.svg`，通过 CSS 蒙版跟随站点主题色。
- Norna Studio 介绍区使用真实立体 APP 图标的浅深色版本，跟随站点外观。
- 浏览器标签页优先使用自适应的根目录 `favicon.svg`，并提供包含 16、32、48、64、128 和 256 像素帧的 `favicon.ico` 及 PNG 兼容资源。
- 收藏与主屏幕使用不透明的 `apple-touch-icon.png` 和 manifest 图标；可裁切版本额外保留安全边距。manifest 不声明离线能力。
- 社交分享使用 1200 × 630 像素的横向品牌封面。

项目根目录的 `Branding/` 保存矢量源文件与使用规范。执行 `swift Scripts/build_brand_assets.swift` 后，生成资源位于 `build/Branding/IconSystem/`。再执行 `python3 website/scripts/sync-brand.py` 同步资源，执行 `python3 website/scripts/verify-brand.py` 校验图标文件、ICO 尺寸、页面元数据和安全边距。`prepare-assets.py` 也会调用同步脚本，避免重新准备截图时恢复旧图标。

## 内联 SF Symbols 文档

`dist/docs.html#sf-symbols` 提供中英文语法、换行与对齐、系统版本兼容性和导出说明。文档预览与示例集共用工作台的 `sf-symbols` 内置示例，源码、原生截图与源码下载均跟随站点语言切换，截图外观跟随站点主题。

图标、换行和时序消息三个示例与其他图形一起由 `prepare-assets.py` 生成，资源使用 `example-` 前缀。清单保留 `builtinID`，用于追溯工作台示例。更新内置示例或英文源码后，重新执行资源生成及校验命令即可。


Native inline-content documentation uses the two built-in examples `sf-symbols-color` and `rich-text`. Their localized sources and light/dark previews live in `dist/assets/inline-*`. Run `scripts/render-inline-content.swift` against the current NornaKit build to generate `build/InlineContent`, then run `python3 website/scripts/sync-inline-content.py` from the native project. Validate the website with `python3 scripts/verify-inline-content.py` from this directory. The documentation follows the page language and appearance controls.


Mac 软件包地址统一配置在 `dist/download-config.js` 的 `workbenchDownloadURL`，指向 `https://github.com/dufu1991/nornakit/releases/latest/download/Norna-Studio-macOS-arm64.dmg`，首页的 Studio 区块和文档页共用该地址。GitHub 会把它重定向到最新正式发布中的同名 DMG，因此每个被标记为 Latest 的发布都必须附带该文件；Windows 工作台发布使用 `--latest=false`，不会占用 Latest。

首页的版本标签和 Swift Package 安装代码中的版本号，加载时会读取 GitHub API 的 `releases/latest`。只有标签符合 `vX.Y.Z` 的 Kit 发布才会更新显示，版本标签同时链接到该发布页。请求失败或超出限额时，保留页面内置的版本号，发版时仍应与 `Configuration/Kit-Version.json` 同步更新。中英文导航与提示随站点语言切换。

## 工作台首次打开说明

首页的工作台介绍区与文档页均提供中英文首次打开说明。当前工作台尚无 Developer ID 签名与 Apple 公证；确认应用来自本项目的 GitHub Releases 且信任该应用后，将其安装到“应用程序”文件夹。若 macOS 拦截首次打开，可在终端执行：

```sh
xattr -dr com.apple.quarantine "/Applications/Norna Studio.app"
```

命令仅移除该应用的下载隔离属性。安装位置不同时，应替换为实际路径；下载不完整或文件实际损坏时，应重新下载并核对校验和。网站不自动执行该命令。

## Cloudflare Pages 发布

正式网站为 [nornakit.com](https://nornakit.com)，通过 Cloudflare Pages 的 GitHub 集成发布 `dufu1991/nornakit` 仓库。

- 生产分支为 `main`，框架选择 None，根目录为仓库根目录。
- 构建命令为 `python3 website/scripts/build-site.py`，输出目录为 `website/dist`。
- 构建仅同步文档并校验已提交的静态资源，不在 Linux 构建环境中运行 Swift 或重新生成原生截图。
- Build watch paths 的包含路径为 `website/*`、`README.md`、`README.zh-CN.md`、`Docs/SUPPORT.md` 和 `THIRD_PARTY_NOTICES.md`，排除路径留空。Cloudflare 的 `*` 路径规则包含子目录。
- 域名绑定 `nornakit.com` 和 `www.nornakit.com`，由 Pages 创建对应 DNS 记录。站点规范链接统一使用主域名 `nornakit.com`。
- 单独修改库源码、测试、工作台版本或打包脚本不会触发网站部署；更新原生图表截图后，应将 `website/dist` 中的产物一并提交。

预览构建与上线前校验使用同一命令：

```sh
python3 website/scripts/build-site.py
```

## Windows 平台入口

`dist/windows.html` 提供 Windows 原生 Kit 接入文档与工作台下载位置。Windows 使用独立的 C# 库、.NET 10、DirectWrite 与 Win2D；工作台使用 WinUI 3。首页与文档页继续以库为主，并链接 Windows 接入页。

`dist/download-config.js` 的 `windowsStudioDownloads` 默认全部为空，页面保持禁用状态。只有在独立的 `studio-windows-vX.Y.Z` Release 真实发布并完成产物验证后，才能写入版本和对应架构的 EXE 地址。不得使用 macOS 的 `latest` 地址推导 Windows 下载。
