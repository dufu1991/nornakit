# 开发指南

本项目以 NornaKit 渲染库为核心，Norna Studio 是用于展示、临时渲染、调试和导出的配套工具。所有命令均在项目根目录执行。

## 目录约定

`Sources/NornaKit` 是可独立使用的 Swift 图表库，按模型、语法、布局、绘制和导出分组。各图形专用的解析与布局集中在 `Diagrams/`，公共流程图布局和路由位于 `Layout/`。仅依赖 `NornaKit` 产品时，不编译或打包示例代码与资源。

`Sources/NornaExamples` 是供 Studio 和回归测试使用的内部示例模块，保存示例模型、目录、双语源码与官方示例快照，不作为公开库产品发布。固定布局夹具位于 `Tests/NornaKitTests/Resources`，仅进入测试包。

`Sources/NornaStudio` 是调用 NornaKit 的演示与调试工作台，按应用状态、编辑器、画布、导出和本地化分组。随应用分发的图标、强调色和字符串表保留在 `Resources/`。

`Tests/NornaKitTests` 与 `Tests/NornaStudioTests` 分别保存引擎和工作台测试。Swift Package 执行两组测试，Xcode 工程当前配置引擎测试。

`Configuration/` 保存应用构建配置，`project.yml` 是 XcodeGen 工程定义。`NornaKit.xcodeproj` 一并提交，便于直接打开项目。移动、新增或删除源码后执行：

```sh
xcodegen generate
```

`Docs/` 保存详细文档，根目录 `README.md` 作为项目入口。`Branding/` 只保存品牌源文件与规范。

`website/` 与原生应用共用一个主仓库。`website/dist/` 是直接发布的静态站点，包含页面、样式、脚本及原生生成的示例图片；`website/scripts/` 保存资源生成和校验工具。这里的 `dist/` 是网站发布内容，需要提交。网站预览与更新步骤见[网站说明](../website/README.md)。

## 构建与验证

Windows 工程独立位于 `Windows/`，包含 C# Core、Windows 原生库、WinUI 3 工作台和测试。两端使用 `Sources/NornaExamples/Resources/examples.json` 中的同一份双语示例，以及同一份官方语料与状态基线。Windows 构建、双架构验收和独立版本发布见 [Windows 指南](WINDOWS.md)。

工作台仅面向 Apple Silicon Mac。Xcode 工程与发布脚本均只构建 `arm64` 架构。

```sh
python3 Scripts/check_kit_package.py
swift test
xcodebuild build \
  -project NornaKit.xcodeproj \
  -scheme NornaStudio \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO
```

运行工作台前，先关闭所有旧实例，包括临时目录中的调试副本。每次只启动最新代码构建的一个实例。

CI 使用 Swift Package 的 `native` 构建方式。新版 Xcode 的默认构建方式可能不同；复现 CI 中的资源打包行为时，执行 `swift test --build-system native --scratch-path build/NativePackageTests`。本地化资源查找不依赖语言目录的大小写，兼容两种构建方式。

## 固定快照与临时报告

`Baselines/` 保存用于回归的官方示例原文、原始 SVG、结果快照及图像对照。它们属于版本化验证资料，应随源码提交。`OfficialReference/` 中的文件由测试校验 SHA-256，`.gitattributes` 明确保留其原始字节，不做换行转换。

`Sources/NornaExamples/Resources/` 保存应用实际使用的示例资源与第三方许可。这些资源也必须提交。更新快照的命令和数量同步要求见[使用指南](GUIDE.md#开发回归资料与自适应布局)。

日常生成的预览、连线审计和图标资源放在 `build/`：

```sh
NORNA_APPLE_FIXTURE_DIR=build/ApplePreviews swift test
python3 Scripts/report_native_previews.py
```

```sh
NORNA_CONNECTOR_AUDIT_DIR=build/ConnectorAudit swift test --filter ConnectorAuditTests
python3 Scripts/report_connector_audit.py
```

## 品牌资源

正式应用图标源文件位于 `Sources/NornaStudio/Resources/NornaSculpted.icon`，Swift Package 的静态兼容图标位于同目录的 `NornaKit.icns`。

```sh
swift Scripts/render_app_icon.swift
swift Scripts/build_brand_assets.swift
python3 Scripts/report_icon_system.py
```

上述命令使用 Xcode 自带的 Icon Composer 工具。应用图标预览放在 `build/Branding/AppIcon/`，站点图标与使用指南放在 `build/Branding/IconSystem/`，完整资源包位于 `build/Branding/nornakit-icon-pack.zip`。`render_app_icon.swift` 还会更新随包分发的 `NornaKit.icns`，更新后应检查并提交该文件。

`build_brand_assets.swift` 直接从正式分层图标生成浅深色图片，可单独运行，不依赖旧设计产物。

## Git 提交范围

提交源码、测试、固定快照、正式资源、脚本、文档、网站发布内容及工程配置。生成的 Xcode 工程应与 `project.yml` 保持同步。

以下内容由 `.gitignore` 排除：

- `.build/`、`.swiftpm/`、`build/` 和 `DerivedData/`：编译缓存、预览与打包产物。
- `.local/`：仅供本机保留的资料。原 `outputs/` 已完整移至 `.local/design-archive/`。
- `.DS_Store`、Xcode 用户状态、工具元数据、环境变量文件及签名证书。

主仓库已在项目根目录初始化，`origin` 指向 `https://github.com/dufu1991/nornakit.git`，网站与应用一并提交。`website/` 原有的嵌套 Git 元数据已移除，不保留历史备份。项目原创代码采用根目录 `LICENSE` 中的 MIT 许可，第三方许可保留在根目录声明与库资源中。

## 工作台发布

工作台版本独立保存在 `Configuration/Studio-Version.xcconfig`。普通提交与 PR 自动测试并构建，`main` 上的版本文件变化会在检查通过后自动发布工作台 DMG 和 ZIP。首次包含版本文件的推送也会发布。工作台使用 `studio-vX.Y.Z` 标签，渲染库使用独立的 `vX.Y.Z` 标签。流程、签名凭据和失败重试见[发布指南](RELEASING.md)。默认项目入口为英文 [README](../README.md)，另有[中文版](../README.zh-CN.md)。
