# Norna

[English](README.md) · [简体中文](README.zh-CN.md)

[![CI](https://github.com/dufu1991/norna/actions/workflows/ci.yml/badge.svg)](https://github.com/dufu1991/norna/actions/workflows/ci.yml)

**让思路，清晰成形。**

Norna 是纯 Swift 图表引擎与原生 Mac 工作台。解析、文本测量、布局、绘制和导出均在原生侧完成，无须浏览器、JavaScript 运行时或网络服务。

- **NornaKit** 是用于集成到 macOS 应用的渲染库。
- **Norna Studio** 是配套的 Mermaid 源码编辑、预览与导出工作台。

![Norna 原生绘制的图表](website/dist/assets/hero-zh-light.png)

## 功能

- 支持 33 类图形，覆盖流程图、时序图、类图、状态图、实体关系图、甘特图、思维导图与数据图表。
- 实时预览、自适应布局、画布平移缩放与源码错误定位。
- 英文和简体中文界面与示例。
- 系统浅色、深色与高对比度外观，以及可配置的图表配色。
- 内联 SF Symbols 与原生富文本扩展。
- PNG、JPEG、TIFF、SVG 和 PDF 导出。

各类图形的语法支持程度不同，具体范围与限制见[支持矩阵](Docs/SUPPORT.md)。项目不宣称完整兼容 Mermaid 的全部语法。

## 下载 Norna Studio

要求 **macOS 14 或更高版本**。通用应用同时支持 **Apple Silicon 与 Intel Mac**。

[下载 DMG](https://github.com/dufu1991/norna/releases/latest/download/Norna-Studio-macOS-universal.dmg) · [下载 ZIP](https://github.com/dufu1991/norna/releases/latest/download/Norna-Studio-macOS-universal.zip) · [全部版本](https://github.com/dufu1991/norna/releases)

首次工作台发布流程成功后，下载链接才会生效。打开 DMG，将 **Norna Studio** 拖入 **Applications**，或解压 ZIP 后移动应用。每个版本均附带 SHA-256 校验和与 `release.json` 清单。

发布说明会标明签名状态。在仓库配置 Apple 凭据前，软件包使用**临时签名，未经 Apple 公证**，可能被 macOS Gatekeeper 拦截。可在仓库设置中启用 Developer ID 签名与公证，步骤见[发布指南](Docs/RELEASING.md)。

## 从源码构建

完整应用要求 **Xcode 27.1 或更高版本**，Swift Package 要求 **Swift 6**。项目没有外部包依赖。

```sh
git clone https://github.com/dufu1991/norna.git
cd norna
open Norna.xcodeproj
```

选择 `NornaStudio` scheme 并运行，或启动 Swift Package 可执行程序：

```sh
swift run NornaStudio
```

Xcode 应用使用原生分层图标，Swift Package 可执行程序使用随包分发的静态图标。

运行测试：

```sh
swift test
python3 -m unittest discover -s Tests/ReleaseTests -p 'test_*.py'
```

本地构建通用版 DMG 和 ZIP：

```sh
bash Scripts/Release/package.sh
```

产物位于 `build/release/`。该命令执行构建和打包，不启动工作台，也不发布到 GitHub。

## 集成 NornaKit

将本仓库添加为 Swift Package 依赖，链接 **NornaKit** 产品。在渲染库版本标签发布前，使用 `main` 分支或固定到具体提交：

```swift
.package(url: "https://github.com/dufu1991/norna.git", branch: "main")
```

```swift
import NornaKit

let diagram = try await NativeDiagramRenderer().render(
    "flowchart LR\n A[源码] --> B[原生图表]",
    options: DiagramLayoutOptions(maxWidth: 640)
)
let svg = diagram.themedSVG(.appleLight)
```

`diagram.scene` 包含原生几何。`CoreGraphicsDiagramPainter` 可将场景绘制到 AppKit 图形上下文，`DiagramExporter` 负责图像与 PDF 导出。详细用法与扩展语法见[使用指南](Docs/GUIDE.md)。

## CI 与版本发布

| 时机 | 自动执行 |
| --- | --- |
| 推送到 `main`，或向 `main` 提交 PR | 测试、通用版 Release 构建与网站资源校验 |
| `main` 中的 `Configuration/Studio-Version.xcconfig` 发生变化 | 检查通过后打包，发布 `studio-vX.Y.Z` |
| 在 `main` 手动运行工作流，并开启 `release` | 发布当前工作台版本，或恢复失败的发布草稿 |
| 推送渲染库的 `vX.Y.Z` 标签 | 不发布工作台应用 |

**工作台与 NornaKit 独立维护版本。** 发布工作台时，修改版本文件中的 `MARKETING_VERSION`，并递增 `CURRENT_PROJECT_VERSION`。包含该文件的首次推送也会触发发布。普通提交不创建新 Release，已发布的工作台版本不会被覆盖。配置和重试方式见[发布指南](Docs/RELEASING.md)。

## 目录结构

```text
Sources/NornaKit/       模型、解析、布局、绘制、导出与示例
Sources/NornaStudio/    原生应用、编辑器、画布、导出界面与本地化
Tests/                 Swift 测试与发布自动化测试
Baselines/             版本化参考源码、SVG 与回归快照
Configuration/         应用元数据、权限与工作台版本
Scripts/               开发工具与发布打包脚本
Branding/              品牌源文件与规范
Docs/                  使用、支持、开发与发布文档
website/               静态网站、发布资源与生成工具
.github/workflows/     CI 与工作台自动发布
```

`Package.swift` 定义 Swift Package，`project.yml` 定义 XcodeGen 工程。生成的 `Norna.xcodeproj` 一并提交，便于直接使用。修改工程定义或增删、移动源码后，执行 `xcodegen generate`。单独修改工作台版本文件不需要重新生成工程。

构建产物和本地设计归档已从 Git 排除。应用与网站共用本仓库。另见[开发指南](Docs/DEVELOPMENT.md)、[网站说明](website/README.md)和[品牌规范](Branding/README.md)。

## 致谢

部分测量公式、绘制约定与参考示例改编自 Pele。来源和许可见[第三方声明](THIRD_PARTY_NOTICES.md)及库资源中的许可文件。项目原创代码采用 [MIT 许可](LICENSE)。
