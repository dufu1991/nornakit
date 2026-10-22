# Windows 原生接入与开发

NornaKit.Windows 是可独立集成的 Windows 原生渲染库。Norna Studio 是调用公开 Kit 接口的 WinUI 3 演示与调试工作台，集成库无须安装工作台。当前源码提供全部 33 类图形，语法范围沿用 [支持矩阵](SUPPORT.md)，不宣称完整兼容 Mermaid。

## 工程与要求

| 工程 | 内容 |
| --- | --- |
| `Windows/src/NornaKit.Core` | 纯 .NET 10 模型、解析、布局、诊断、富文本语法、场景几何、SVG 与共享示例 |
| `Windows/src/NornaKit.Windows` | DirectWrite 文本布局、Win2D 绘制、主题与图标、WinUI 预览控件、五种格式导出 |
| `Windows/src/NornaStudio` | C# 与 WinUI 3 原生工作台 |
| `Windows/tests` | 固定文本测量回归、工作台并发状态、真实 Windows 原生绘制与导出检查 |

最低系统为 Windows 11 初始版本，即内部版本 22000。支持 x64 与 ARM64，不支持 Windows 10 和 x86。构建需要 Windows SDK 26100、.NET SDK 10.0.402 和 Windows 应用开发工具。打开 `Windows/NornaKit.slnx`，选择对应架构。

依赖通过 `Directory.Packages.props` 与各工程的 `packages.lock.json` 固定。Windows App SDK 为 2.5.1，Win2D 为 1.4.0，PDFsharp 为 6.2.3；显式使用 System.Security.Cryptography.Pkcs 10.0.13，替换 PDFsharp 的旧版传递依赖。恢复时使用 `--locked-mode`。WinUI 自包含宿主应保留模板中的 `EnableMsixTooling=true`，以生成并发布应用的 PRI 资源索引；工作台仍采用 `WindowsPackageType=None`，不会生成 MSIX。打包脚本检查 `resources.pri`，避免遗漏原生控件样式。

## 集成 Kit

两个库分别支持 NuGet 打包，Windows 库引用 Core 库。正式 NuGet 包发布前，使用本仓库的项目引用：

```xml
<ProjectReference Include="path/to/nornakit/Windows/src/NornaKit.Windows/NornaKit.Windows.csproj" />
```

宿主使用 `net10.0-windows10.0.26100.0`，最低平台版本设置为 `10.0.22000.0`。WinUI 宿主照常初始化应用；不创建窗口的控制台宿主可参考 `NornaKit.Windows.SmokeTests` 的自包含工程与 WinRT 初始化方式。

```csharp
using Microsoft.Graphics.Canvas;
using NornaKit;
using NornaKit.Windows;

var renderer = WindowsDiagramRenderer.Create();
var artifact = await renderer.RenderAsync(
    "flowchart LR\n A[本地源码] --> B[原生图形]",
    new DiagramLayoutOptions(MaxWidth: 640), cancellationToken);

var palette = WindowsPalette.Resolve(CanvasAppearance.System);
var svg = SvgExporter.Export(artifact.Scene, palette);
var exporter = new DiagramExporter(CanvasDevice.GetSharedDevice());
var pdf = await exporter.ExportAsync(artifact.Scene, palette,
    new DiagramExportOptions(Format: DiagramExportFormat.Pdf), cancellationToken);
await File.WriteAllBytesAsync("diagram.pdf", pdf, cancellationToken);
```

`IDiagramRenderer.RenderAsync` 返回 `DiagramArtifact`，其中包含类型、尺寸和不可变场景。Core 的坐标与路径使用 `double`，单位是设备无关单位，不依赖窗口或 XAML。可通过 `ITextLayoutProvider` 注入文本布局服务；默认 Windows 工厂使用 DirectWrite，取得系统实际选择的字体与定位字形。场景中的文本布局由预览和导出共同使用。

`DiagramRenderException` 提供 `Code`、`Line` 与 `Column`。预期语法与布局错误使用该诊断；取消使用标准 `OperationCanceledException`。底层不吞掉失败。

## 原生预览

```csharp
var preview = new DiagramPreview
{
    Scene = artifact.Scene,
    Palette = palette,
    ShowGrid = true
};
hostGrid.Children.Add(preview.Element);
preview.Fit();
```

`DiagramPreview.Element` 是宿主添加到布局中的原生 UserControl，无须从库加载 XAML 资源。预览的创建、属性更新和释放在宿主的 UI 线程进行。控件支持拖动平移、滚轮缩放、方向键、加减键，以及按 `0` 适应窗口。宿主永久移除控件时调用 `Dispose()`，释放 Win2D 画布。控件的缩放、平移与网格只影响预览，不写入场景，不参与导出。预览使用 Win2D CanvasImageSource，根据 XamlRoot 的 DPI 和画布尺寸重建表面，在设备丢失后重新创建绘图资源。图形本身保留设备无关的场景路径。CI 使用 WARP 软件绘制并等待场景实际完成首帧，普通运行默认使用硬件绘制。

## 导出与平台差异

- PNG、JPEG、TIFF 使用 Win2D 原生编码。位图倍率为 0.25 到 8，最长边不超过 16384 像素，总像素不超过 3200 万。JPEG 不支持透明背景。
- SVG 使用场景路径与文字，图标使用自包含矢量路径，不引用外部图标图片或字体资源。普通文字保留系统字体名称。SVG 最大为 4 MB。
- PDF 使用 PDFsharp Core，嵌入 DirectWrite 实际选用的 TrueType 字体及字体集合中的具体字面，保存字形位置、Unicode 映射和 `ActualText`。普通文字可选择、复制和搜索，图形保持矢量。
- PDF 当前支持 TrueType 轮廓，并遵守字体的嵌入权限。字体不允许嵌入或轮廓格式不受支持时返回 `export-font`，不会悄悄把普通文字替换成截图或轮廓。
- 两端使用系统字体，允许字宽、换行和最终尺寸存在差异。Swift 与 C# 使用同一套固定字宽规则和 24 组共享几何基线，对照节点、分组、连线路径、标记及尺寸。真实字体快照按平台单独检查。

Windows 图标采用 Segoe Fluent Icons。可用名称包括 `document`、`upload`、`check-circle`、`drive`、`check`、`sparkles`、`person`、`arrow-right`、`align-center`、`return`、`weather`、`folder`、`cloud`、`settings`、`code`、`warning`、`app` 与 `photo`。

```text
输入 :win:document: → 原生处理 :win:check:
```

内置示例中的 14 个 SF 标记使用 `WindowsIcons` 中的显式语义映射。未知名称保留原文，不分发 Apple 字体或 SF Symbols 图像。Windows 图标统一单色；指定 palette 或渐变等颜色配置时，仅使用首个颜色。Windows 的浅色、深色、系统高对比度与自定义强调色通过 `WindowsPalette` 配置。

## 工作台

工作台提供分类、全部 79 个双语示例、源码编辑、实时预览、错误定位、主题与配色、网格、打开保存、复制 SVG 和五种格式导出。编辑后延迟 250 毫秒渲染，取消过期任务，只有最新请求更新预览。源码与场景不一致时禁用导出。

打开导出面板时固定场景、源码与主题快照，随后编辑或切换外观不会改变该次导出。源码草稿、路径、语言、外观、强调色和网格设置保存在 `%LOCALAPPDATA%\NornaKit\NornaStudio\settings.json`。

快捷键为 `Ctrl+O` 打开、`Ctrl+S` 保存、`Ctrl+Shift+S` 另存为、`Ctrl+Shift+C` 复制 SVG、`Ctrl+E` 导出。打开与保存使用 Windows 原生文件对话框。

## 构建与验收

在 `Windows` 目录执行：

```powershell
dotnet restore NornaKit.slnx -p:Platform=x64 --locked-mode
dotnet run --project tests/NornaKit.Core.Tests -c Release --no-restore
dotnet publish tests/NornaKit.Windows.SmokeTests -c Release --no-restore -p:Platform=x64 -o artifacts/smoke
./artifacts/smoke/NornaKit.Windows.SmokeTests.exe artifacts/native-smoke
python -m pip install Pillow==11.3.0 pypdf==6.1.1
python scripts/verify-native-smoke.py artifacts/native-smoke
dotnet publish src/NornaStudio -c Release --no-restore -p:Platform=x64 -o artifacts/studio
```

ARM64 将平台参数替换为 `-p:Platform=ARM64`。GitHub Actions 分别使用 x64 与原生 ARM64 运行器，校验全部 600 个官方示例的状态、诊断代码与行位置，检查双语示例原生绘制，并导出全部 33 类图形的快照。独立 Python 检查图片尺寸、背景、SVG 资源及 PDF 嵌入字体和文字提取。

工作台状态测试检查延迟渲染、过期结果、取消、诊断与导出快照。Windows 流程还构建和启动工作台，生成安装版与 ZIP，并检查当前用户安装、卸载及便携版启动。

正式发布前仍需在未预装开发工具与运行时的 Windows 11 环境验收，并人工检查最低系统版本、DPI 切换、键盘操作、高对比度与设备丢失后的恢复。CI 运行器包含开发工具，不能替代这一环境验收。未发布之前，网站的 Windows 下载入口保持禁用。

## 分发与独立发布

`scripts/package-studio.ps1` 生成每个架构独立的 EXE 安装程序和 ZIP 便携版。两者都携带 .NET 与 Windows App SDK 运行时。Inno Setup 安装程序按当前用户安装到 `%LOCALAPPDATA%\Programs\Norna Studio`，提供卸载入口，不要求管理员权限。构建工具固定为 Inno Setup 6.7.3，并校验官方下载的 SHA-256。

Windows 工作台版本单独保存在 `Windows/StudioVersion.props`。手动运行 `Release Windows Studio`，输入与该文件一致的版本，验证通过后使用 `studio-windows-vX.Y.Z` 标签发布，显式设置 `latest=false`，不会取代 macOS 的最新发布。

NuGet 使用独立的 `Publish Windows NuGet libraries` 手动流程。配置 `nuget` 环境的 `NUGET_API_KEY` 后发布两个库，工作台不作为库依赖。安装程序、ZIP、SHA-256 与构建信息中记录版本、架构和源码提交。当前流程不提供代码签名、商店上架、WinGet 或自动更新。
