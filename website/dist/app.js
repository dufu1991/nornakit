import { workbenchDownloadURL, windowsStudioDownloads } from './download-config.js';
import { inlineTranslations, updateInlineContent } from './inline-content.js';
import { createPicker, icon } from './components.js';
import { createNativeImage, setNativeImage } from './native-images.js';
const translations = {
  en: {
    skip: 'Skip to content', navigation: 'Main navigation', examples: 'Examples', getStarted: 'Get started', docs: 'Docs', language: 'Language', auto: 'Auto', nativeOutput: 'Native output', diagramExamples: 'Diagram examples', source: 'Source', copy: 'Copy', copied: 'Copied to clipboard', copyFailed: 'Could not copy. Select the code to copy it manually.', downloadSource: 'Download .mmd', enlarge: 'Enlarge screenshot', viewScreenshot: 'View screenshot', support: 'Support', credits: 'Credits', close: 'Close', downloadScreenshot: 'Download screenshot', appearance: 'Appearance', autoTheme: 'System', light: 'Light', dark: 'Dark', screenshotAlt: 'Native Swift render of a {name} diagram', heroAlt: 'An idea becomes Mermaid source, then a native diagram and an SVG export', loadError: 'Examples could not load. Refresh the page to try again.', docsTitle: 'Small library. Native foundations.', docsLead: 'NornaKit provides native Swift and C# libraries for parsing, layout, drawing and export. Norna Studio demonstrates the libraries and helps debug rendering issues.', requirementsTitle: 'Requirements', requirements: 'NornaKit and Norna Studio currently support macOS 14 or later. Norna Studio requires an Apple Silicon Mac. Build the app with Xcode 27.1 or later; the package requires Swift 6. The package declares no external package dependencies.', integrateTitle: 'Render a diagram', integrate: 'Add the NornaKit package from https://github.com/dufu1991/nornakit to your Xcode project and link the NornaKit library product. Rendering produces a scene for native drawing and SVG for export.', setupNotice: 'Add NornaKit from github.com/dufu1991/nornakit as a Swift Package dependency. The companion app is optional.', studioTitle: 'Optional demo and debugging tool', studio: 'From the project directory, open the Xcode project and select the NornaStudio scheme, or run the Swift package command below.', supportTitle: 'Support and current limits', supportIntro: 'The engine has 33 diagram families, with basic parsing, dedicated layouts, and working examples. This does not mean full Mermaid syntax compatibility.', support1: 'Flowcharts, sequence diagrams, class diagrams, state diagrams, entity relationships, and C4 architecture.', support2: 'Pie, XY, radar, Sankey, treemap, Gantt, timelines, and more.', support3: 'Layout adapts for supported families. Dense data or long labels may still cause crossings or crowding.', support4: 'Arbitrary HTML, CSS, scripts, and full Markdown styling are not interpreted.', originalSupport: 'Download the detailed support matrix in Chinese', screenshotsTitle: 'About the examples', screenshots: 'Every diagram on this site is a PNG produced by the Swift native drawing pipeline. The browser displays screenshots and source text; it does not execute the diagram engine. Example sources and screenshot labels follow the selected language. Both languages include light and dark screenshots.', attributionTitle: 'Acknowledgments', attributionDocs: 'Some measurement and layout formulas are adapted from Pele. Upstream license notices are included with the project. NornaKit is an independent project.', notices: 'Read third-party notices', docsPageTitle: 'Documentation — NornaKit', back: 'Back to NornaKit'
  },
  zh: {
    skip: '跳转到正文', navigation: '主导航', examples: '示例', getStarted: '开始使用', docs: '文档', language: '语言', auto: '自动', nativeOutput: '原生绘制结果', diagramExamples: '图表示例', source: '源码', copy: '复制', copied: '已复制到剪贴板', copyFailed: '复制未成功，请选中代码手动复制。', downloadSource: '下载 .mmd 源码', enlarge: '放大截图', viewScreenshot: '查看截图', support: '支持范围', credits: '致谢', close: '关闭', downloadScreenshot: '下载截图', appearance: '外观', autoTheme: '跟随系统', light: '浅色', dark: '深色', screenshotAlt: '由 Swift 原生绘制的 {name} 截图', heroAlt: '从输入想法、编写 Mermaid，到原生引擎生成图表与导出 SVG 的流程图', loadError: '示例加载失败，请刷新页面重试。', docsTitle: '轻量的库，原生的基础。', docsLead: 'NornaKit 提供可集成到 macOS 与 Windows 应用的解析、布局、原生绘制与导出能力。Norna Studio 用于展示库效果和调试渲染问题。', requirementsTitle: '运行要求', requirements: '当前 NornaKit 与 Norna Studio 支持 macOS 14 或更高版本。Norna Studio 仅支持 Apple Silicon Mac。完整应用要求 Xcode 27.1 或更高版本，Swift Package 要求 Swift 6。当前包没有外部包依赖。', integrateTitle: '渲染一张图表', integrate: '在 Xcode 项目中添加 https://github.com/dufu1991/nornakit 上的 NornaKit 包，并链接 NornaKit 库产品。渲染后可获取用于原生绘制的场景，以及用于导出的 SVG。', setupNotice: '从 github.com/dufu1991/nornakit 添加 NornaKit 作为 Swift Package 依赖，即可接入渲染能力。配套工作台按需使用。', studioTitle: '按需运行演示与调试工具', studio: '在项目目录中打开 Xcode 工程，选择 NornaStudio scheme，或使用下方的 Swift Package 命令运行。', supportTitle: '支持范围与当前限制', supportIntro: '引擎覆盖 33 类图形，提供基础解析、专用布局与可运行示例。这不代表完整兼容 Mermaid 的全部语法。', support1: '流程图、时序图、类图、状态图、实体关系图，以及 C4 架构图等。', support2: '饼图、XY 坐标图、雷达图、桑基图、矩形树图、甘特图与时间线等。', support3: '部分图形支持自适应布局，密集数据或过长标签仍可能产生交叉与拥挤。', support4: '不解释任意 HTML、CSS、脚本或完整的 Markdown 富文本样式。', originalSupport: '下载完整中文支持矩阵', screenshotsTitle: '关于本站示例', screenshots: '本站所有图表均为 Swift 原生绘制流程生成的 PNG。浏览器只展示截图和源码，不执行图表引擎。示例源码和截图标签随语言切换，中英文均提供浅色与深色版本。', attributionTitle: '致谢', attributionDocs: '部分测量与布局公式参考并移植自 Pele，项目包含相应的上游许可声明。NornaKit 是独立项目。', notices: '阅读第三方许可声明', docsPageTitle: '文档 — NornaKit', back: '返回 NornaKit'
  }
};
Object.assign(translations.en, { browserLanguage: 'Follow browser' });
Object.assign(translations.zh, { browserLanguage: '跟随浏览器' });
Object.assign(translations.en, { githubRepository: 'View the NornaKit repository on GitHub', workbench: 'Studio', workbenchDownload: 'Download the Norna Studio demo and debugging tool for Mac', workbenchComingSoon: 'The Mac app download is coming soon.' });
Object.assign(translations.zh, { githubRepository: '在 GitHub 查看 NornaKit 源码仓库', workbench: '工作台', workbenchDownload: '下载 Mac 版 Norna Studio 演示与调试工具', workbenchComingSoon: 'Mac 版工作台下载即将开放。' });
Object.assign(translations.en, {
  studioLaunchTitle: 'Blocked when opening Norna Studio?',
  studioLaunchNotice: 'Norna Studio currently has no Developer ID signature or Apple notarization. macOS may report that the developer cannot be verified or the app cannot be opened.',
  studioLaunchSteps: 'After downloading from this project’s GitHub Releases and verifying that you trust the app, move Norna Studio to Applications. Open Terminal and run:',
  studioLaunchAfter: 'Then open Norna Studio again. This command removes the download quarantine attribute from this app. If you installed it elsewhere, replace the path with its actual location. It does not repair an incomplete or damaged download.',
  studioLaunchGuide: 'Installation and first-launch help',
  studioLaunchApple: 'Apple’s guidance on opening downloaded apps'
});
Object.assign(translations.zh, {
  studioLaunchTitle: '首次打开 Norna Studio 被拦截？',
  studioLaunchNotice: 'Norna Studio 当前尚无 Developer ID 签名与 Apple 公证，macOS 可能提示“无法验证开发者”或无法打开应用。',
  studioLaunchSteps: '请先确认应用来自本项目的 GitHub Releases，且你信任该应用。将 Norna Studio 拖入“应用程序”文件夹后，打开“终端”并执行：',
  studioLaunchAfter: '执行后重新打开 Norna Studio。此命令会移除该应用的下载隔离属性；若安装在其他位置，请替换为实际路径。该命令不能修复下载不完整或文件实际损坏的问题。',
  studioLaunchGuide: '查看安装与首次打开说明',
  studioLaunchApple: 'Apple 关于打开下载应用的说明'
});
Object.assign(translations.en, { previousImage: 'Previous image', nextImage: 'Next image', browseScreenshots: 'Browse screenshots', navigationHint: 'Use ← → to browse', previewPosition: '{name}, image {current} of {total}.' });
Object.assign(translations.zh, { previousImage: '上一张', nextImage: '下一张', browseScreenshots: '浏览截图', navigationHint: '使用左右方向键切换', previewPosition: '{name}，第 {current} 张，共 {total} 张。' });
Object.assign(translations.en, {
  symbolsTitle: 'SF Symbols inside text',
  symbolsLead: 'Write :sf:name: anywhere in a displayed label, for example Upload :sf:icloud.and.arrow.up: file. Use the exact system symbol name from the SF Symbols app. Multiple symbols can appear in one label.',
  symbolsLayout: 'Monochrome symbols follow the surrounding text size, weight, and color. They align to the text baseline and count toward label width. Automatic wrapping keeps each complete symbol token together; explicit line breaks still work. Leading, center, and trailing alignment apply to the whole line.',
  symbolsAvailability: 'Available symbols depend on the macOS version rendering the diagram. Unknown names and incomplete tokens remain visible as source text. Use quoted labels when the diagram syntax requires them; this notation belongs in label text, not node identifiers or numeric fields.',
  symbolsExport: 'PNG, JPEG, TIFF, and PDF include the symbols through native drawing. SVG embeds each symbol as a transparent PNG at 4× resolution; text and diagram paths remain vector elements. Exported files need no SF Symbols installation or external icon files. The symbol images embedded in SVG have finite resolution.',
  symbolsExtension: 'This is a NornaKit extension to label syntax. Other Mermaid renderers may display the token as text. It does not change the built-in architecture diagram icon syntax.',
  symbolsCaption: 'Actual native output, with symbols in a group title, nodes, and a connection label. The source and preview follow the site language and appearance.',
  symbolsAlt: 'Native diagram with inline SF Symbols in labels',
  symbolsDownload: 'Download the SF Symbols example'
});
Object.assign(translations.zh, {
  symbolsTitle: '在文本中嵌入 SF Symbols',
  symbolsLead: '在可显示的标签任意位置写入 :sf:名称:，例如「上传 :sf:icloud.and.arrow.up: 文件」。名称使用 SF Symbols 应用中的准确系统名称，同一标签可以包含多个图标。',
  symbolsLayout: '单色图标跟随文字的字号、字重和颜色，按文字基线对齐，并参与标签宽度计算。自动换行时，完整图标标记不会被拆开；显式换行仍然有效。左对齐、居中和右对齐均作用于包含图标的整行内容。',
  symbolsAvailability: '可用图标取决于渲染图表的 macOS 版本。未知名称和不完整标记保留为源码文字。图表语法要求引号时，请使用带引号的标签；此写法用于标签文本，不用于节点标识符或数值字段。',
  symbolsExport: 'PNG、JPEG、TIFF 和 PDF 通过原生绘制包含图标。SVG 将图标以 4 倍分辨率的透明 PNG 内嵌，文字和图形路径仍为矢量元素。导出文件无须安装 SF Symbols，也无须外部图标文件。SVG 内嵌的图标图片具有有限分辨率。',
  symbolsExtension: '这是 NornaKit 的标签语法扩展，其他 Mermaid 渲染器可能将标记显示为文字。此功能不改变架构图已有的内置图标语法。',
  symbolsCaption: '原生引擎实际输出，展示子图标题、节点和连线标签中的图标。源码和预览跟随站点语言与外观切换。',
  symbolsAlt: '在标签中嵌入 SF Symbols 的原生图表',
  symbolsDownload: '下载 SF Symbols 示例源码'
});
Object.assign(translations.en, {
  windowsKit: 'Windows Kit', windowsPageTitle: 'Windows Kit — NornaKit', windowsTitle: 'Native diagrams for Windows.',
  windowsLead: 'Independent C# libraries on .NET 10. DirectWrite text, Win2D drawing and local export across all 33 diagram families. The optional workbench uses WinUI 3.',
  windowsRequirements: 'Windows 11 build 22000 or later, x64 and ARM64. Build with .NET SDK 10.0.402 and Windows SDK 26100. Use project references until NuGet packages are published.',
  windowsIntegration: 'NornaKit.Core contains parsing, layout and geometry. NornaKit.Windows adds native text, drawing, icons, export and an optional WinUI preview control. The Kit does not need a running workbench or visible window.',
  windowsExports: 'Export PNG, JPEG, TIFF, SVG and PDF from the same immutable scene. PDF embeds the actual selected TrueType fonts and keeps ordinary text selectable and searchable. Icons use self contained paths in SVG.',
  windowsIcons: 'Use :win:document: or other supported Segoe Fluent Icons names. Built in SF tokens have explicit semantic mappings; unknown names remain literal. Windows icons are monochrome and use the first configured color.',
  windowsSource: 'Read the Windows integration guide', windowsDownloads: 'Windows workbench downloads',
  windowsPending: 'No Windows release has been published yet. Downloads remain disabled until verified release assets exist. Source builds and CI packages are available from the repository.',
  windowsX64: 'Windows x64 installer', windowsArm64: 'Windows ARM64 installer', windowsDocLink: 'Use the native Windows libraries →'
});
Object.assign(translations.zh, {
  windowsKit: 'Windows Kit', windowsPageTitle: 'Windows 接入 — NornaKit', windowsTitle: '为 Windows 原生绘制图表。',
  windowsLead: '独立的 C# 库，运行于 .NET 10。通过 DirectWrite 排版、Win2D 绘制并在本地导出全部 33 类图形。配套工作台使用 WinUI 3。',
  windowsRequirements: '支持 Windows 11 初始版本及以上的 x64 与 ARM64。构建使用 .NET SDK 10.0.402 与 Windows SDK 26100。NuGet 包发布前通过项目引用接入。',
  windowsIntegration: 'NornaKit.Core 提供解析、布局与几何。NornaKit.Windows 提供原生文本、绘制、图标、导出和可选的 WinUI 预览控件。集成库无须启动工作台或创建可见窗口。',
  windowsExports: '同一份不可变场景可导出 PNG、JPEG、TIFF、SVG 与 PDF。PDF 嵌入实际选用的 TrueType 字体，普通文字可选择、可搜索。SVG 图标使用自包含路径。',
  windowsIcons: '使用 :win:document: 等 Segoe Fluent Icons 标记。内置示例的 SF 标记通过显式语义映射转换，未知名称保留原文。Windows 图标统一单色，采用首个配置颜色。',
  windowsSource: '阅读 Windows 接入指南', windowsDownloads: 'Windows 工作台下载',
  windowsPending: 'Windows 正式版本尚未发布，下载入口将在产物发布并验证后启用。当前可从源码构建，或查看仓库中的 CI 构建产物。',
  windowsX64: 'Windows x64 安装程序', windowsArm64: 'Windows ARM64 安装程序', windowsDocLink: '接入 Windows 原生库 →'
});
Object.assign(translations.en, {
  sponsor: 'Sponsor', sponsorEyebrow: 'OPEN SOURCE · COMMUNITY SUPPORTED', sponsorTitle: 'Support NornaKit',
  sponsorDescription: 'If NornaKit helps you build native diagrams, consider supporting its development, documentation, and ongoing maintenance. Thank you for helping the project grow.',
  sponsorInternational: 'Recommended outside China', sponsorChina: 'Recommended in China',
  sponsorWechat: 'WeChat', sponsorAlipay: 'Alipay', sponsorWechatScan: 'Scan with WeChat', sponsorAlipayScan: 'Scan with Alipay',
  sponsorWechatAlt: 'WeChat sponsorship QR code', sponsorAlipayAlt: 'Alipay sponsorship QR code',
  sponsorThanks: 'Every contribution helps keep native diagrams moving forward.'
});
Object.assign(translations.zh, {
  sponsor: '赞助', sponsorEyebrow: '开放源码 · 社区支持', sponsorTitle: '支持 NornaKit',
  sponsorDescription: '如果 NornaKit 帮助你实现了原生图表，欢迎通过赞助支持渲染库的开发、文档建设与长期维护。感谢你的支持，让项目持续成长。',
  sponsorInternational: '推荐中国以外地区使用', sponsorChina: '推荐中国地区使用',
  sponsorWechat: '微信赞赏', sponsorAlipay: '支付宝', sponsorWechatScan: '微信扫一扫', sponsorAlipayScan: '支付宝扫一扫',
  sponsorWechatAlt: '微信赞赏二维码', sponsorAlipayAlt: '支付宝赞助二维码',
  sponsorThanks: '每一份支持，都在帮助原生图表持续成长。'
});
Object.assign(translations.en, {
  title: 'NornaKit — Native Mermaid diagrams for Swift and C#',
  metaDescription: 'NornaKit renders Mermaid diagrams natively in Swift on macOS and in C# on Windows. 33 diagram families, native text and drawing, PNG, SVG and PDF export.',
  windowsNav: 'Windows', footerNavigation: 'Footer', installLabel: 'Install', codeLanguage: 'Language',
  heroTitle: 'Native Mermaid diagrams for Swift and C#.',
  heroLead: 'NornaKit parses Mermaid text, measures it with the platform’s own text engine, lays it out and draws it with CoreGraphics or Win2D. No WebView, no JavaScript runtime, no network service.',
  readDocs: 'Read the docs', installSwift: 'Add the package in Package.swift or Xcode, then link the NornaKit product.', installWindows: 'Reference the project directly until NuGet packages are published.',
  heroCaption: 'Actual native output from NornaKit, shown here as a screenshot.',
  startTitle: 'Quick start', startLead: 'Three steps from Mermaid text to a diagram inside your app.',
  step1Title: 'Add the library', step1: 'Swift Package Manager on macOS. Project references to NornaKit.Core and NornaKit.Windows on Windows.',
  step2Title: 'Render the source', step2: 'The renderer parses Mermaid, measures text natively and lays the diagram out into an immutable scene.',
  step3Title: 'Draw or export', step3: 'Draw the scene in your own view, or export PNG, JPEG, TIFF, SVG and PDF from the same geometry.',
  platformsTitle: 'Platforms', platformsLead: 'Two independent native implementations that share the same diagram families and layout model.',
  rowLanguage: 'Language', rowSystem: 'System', rowText: 'Text', rowDrawing: 'Drawing', rowExport: 'Export', rowIcons: 'Inline icons', rowInstall: 'Integration', rowStudio: 'Companion app', rowGuide: 'Guide',
  windowsSystem: 'Windows 11 (build 22000+), x64 and ARM64', windowsInstall: 'Project references (NuGet coming later)',
  macStudio: 'Norna Studio, Apple Silicon', windowsStudio: 'WinUI 3 workbench, not yet released', macGuide: 'macOS documentation →', windowsGuide: 'Windows documentation →',
  featuresTitle: 'What’s included', featuresLead: 'Everything runs locally, inside your app’s process.',
  featureParseTitle: 'Parsing with source locations', featureParse: 'Mermaid parsing for 33 diagram families, with error locations that point back to the source text.',
  featureTextTitle: 'Native text measurement', featureText: 'Labels are measured by CoreText or DirectWrite, so layout matches what the system actually draws.',
  featureLayoutTitle: 'Adaptive layout', featureLayout: 'Dedicated layouts per family that adapt to width limits and label length.',
  featureSceneTitle: 'One scene, every output', featureScene: 'On-screen drawing and every export format share the same immutable scene geometry.',
  featureThemeTitle: 'System appearances', featureTheme: 'Light, dark and increased contrast, with configurable diagram colors.',
  featureInlineTitle: 'Inline icons and rich text', featureInline: 'SF Symbols or Segoe Fluent Icons inside labels, plus native rich text extensions.',
  compatibility: 'Syntax support varies by diagram family. NornaKit does not claim complete Mermaid compatibility.', supportLink: 'See the support notes →',
  examplesTitle: 'Examples', examplesLead: '33 diagram families and 3 SF Symbols examples. Every image is real native output; select one to see its source.',
  browseAll: 'Browse all 36 screenshots',
  studioTitle: 'Norna Studio', studioLead: 'An optional Mac app for demos, rendering checks, debugging and occasional exports. You do not need it to use the library.',
  studioRequirements: 'macOS 14+ · Apple Silicon', studioDownload: 'Download for Mac',
  resourcesTitle: 'Resources', resDocs: 'Documentation', resDocsText: 'Requirements, integration, inline content and Studio.',
  resWindows: 'Windows guide', resWindowsText: 'C# libraries, Win2D drawing, export and packaging.',
  resSupport: 'Support notes', resSupportText: 'Supported constructs and current limits per family.',
  resGithubText: 'Source code, issues and releases.', resChangelog: 'Changelog', resChangelogText: 'What changed in each library release.',
  resCreditsText: 'Third-party notices and acknowledgments.',
  footerTagline: 'Native diagrams, clearly.', footerLegal: 'MIT License · © 2026 dufu1991'
});
Object.assign(translations.zh, {
  title: 'NornaKit — Swift 与 C# 原生 Mermaid 图表渲染库',
  metaDescription: 'NornaKit 在 macOS 上用 Swift、在 Windows 上用 C# 原生渲染 Mermaid 图表，支持 33 类图形、原生排版与绘制，以及 PNG、SVG、PDF 导出。',
  windowsNav: 'Windows', footerNavigation: '页脚导航', installLabel: '安装方式', codeLanguage: '语言',
  heroTitle: '用 Swift 与 C# 原生渲染 Mermaid 图表。',
  heroLead: 'NornaKit 解析 Mermaid 文本，使用系统自带的文字引擎测量排版，再通过 CoreGraphics 或 Win2D 绘制。不依赖 WebView、JavaScript 运行时或网络服务。',
  readDocs: '阅读文档', installSwift: '在 Package.swift 或 Xcode 中添加依赖，并链接 NornaKit 库产品。', installWindows: 'NuGet 包发布前，直接以项目引用的方式接入。',
  heroCaption: 'NornaKit 原生引擎的实际输出，本站以截图呈现。',
  startTitle: '快速上手', startLead: '三步把 Mermaid 文本变成应用里的图表。',
  step1Title: '添加依赖', step1: 'macOS 使用 Swift Package Manager；Windows 引用 NornaKit.Core 与 NornaKit.Windows 项目。',
  step2Title: '渲染源码', step2: '渲染器解析 Mermaid，原生测量文字，并将图表布局为不可变的场景。',
  step3Title: '绘制或导出', step3: '在自己的视图中绘制场景，或基于同一份几何导出 PNG、JPEG、TIFF、SVG 与 PDF。',
  platformsTitle: '平台对照', platformsLead: '两套独立的原生实现，共享相同的图形类型与布局模型。',
  rowLanguage: '语言', rowSystem: '系统', rowText: '文字排版', rowDrawing: '绘制', rowExport: '导出', rowIcons: '行内图标', rowInstall: '接入方式', rowStudio: '配套工具', rowGuide: '接入指南',
  windowsSystem: 'Windows 11（22000 及以上），x64 与 ARM64', windowsInstall: '项目引用（NuGet 包后续发布）',
  macStudio: 'Norna Studio，Apple Silicon', windowsStudio: 'WinUI 3 工作台，尚未发布', macGuide: 'macOS 文档 →', windowsGuide: 'Windows 文档 →',
  featuresTitle: '包含的能力', featuresLead: '全部在本地、在你的应用进程内完成。',
  featureParseTitle: '解析与源码定位', featureParse: '解析 33 类 Mermaid 图形，错误信息可定位回源码位置。',
  featureTextTitle: '原生文字测量', featureText: '由 CoreText 或 DirectWrite 测量标签，布局与系统实际绘制保持一致。',
  featureLayoutTitle: '自适应布局', featureLayout: '每类图形使用专用布局，适应宽度限制与标签长度。',
  featureSceneTitle: '一份场景，多种输出', featureScene: '屏幕绘制与各种导出格式共用同一份不可变的场景几何。',
  featureThemeTitle: '系统外观', featureTheme: '支持浅色、深色与增强对比度，图表颜色可配置。',
  featureInlineTitle: '行内图标与富文本', featureInline: '在标签中嵌入 SF Symbols 或 Segoe Fluent Icons，并支持原生富文本扩展。',
  compatibility: '具体语法支持范围因图形类型而异，NornaKit 不宣称完整兼容 Mermaid。', supportLink: '查看支持说明 →',
  examplesTitle: '示例', examplesLead: '33 类图形与 3 个 SF Symbols 示例，全部为原生引擎的真实输出。选择一个示例查看源码。',
  browseAll: '浏览全部 36 张截图',
  studioTitle: 'Norna Studio', studioLead: '可选的 Mac 应用，用于演示、渲染验证、调试和临时导出。使用渲染库无须安装它。',
  studioRequirements: 'macOS 14+ · Apple Silicon', studioDownload: '下载 Mac 版',
  resourcesTitle: '资源', resDocs: '文档', resDocsText: '运行要求、接入方式、行内内容与工作台。',
  resWindows: 'Windows 接入指南', resWindowsText: 'C# 库、Win2D 绘制、导出与打包。',
  resSupport: '支持说明', resSupportText: '各类图形已支持的语法与当前限制。',
  resGithubText: '源码、问题反馈与版本发布。', resChangelog: '更新日志', resChangelogText: '渲染库每个版本的变更。',
  resCreditsText: '第三方许可声明与致谢。',
  footerTagline: '让思路，清晰成形。', footerLegal: 'MIT 许可证 · © 2026 dufu1991'
});
let languagePreference = nornaSettings.languagePreference;
let themePreference = nornaSettings.themePreference;
let language = nornaSettings.resolveLanguage(languagePreference);
let theme = nornaSettings.resolveTheme(themePreference);
let examples = [];
let selected = 'flowchart';
let imageURL;
let toastTimer;
const $ = (selector) => document.querySelector(selector);
const languagePicker = createPicker({ host: $('#language-picker'), id: 'language', compact: true, onChange: (value) => {
  languagePreference = value; localStorage.setItem('norna-language', value); localize();
} });
const themePicker = createPicker({ host: $('#theme-picker'), id: 'theme', compact: true, onChange: (value) => {
  themePreference = value; localStorage.setItem('norna-theme', value); syncAppearance();
} });
document.querySelectorAll('.quiet-button[data-i18n="copy"]').forEach((button) => {
  button.removeAttribute('data-i18n'); button.innerHTML = `${icon('copy')}<span data-i18n="copy"></span>`;
});
const t = (key) => translations[language][key];
const nameOf = (example) => example[language];
const imageStem = (example) => `${example.id}-${language}`;
const sourceOf = (example) => example.sources[language];
const screenshot = (example) => `assets/${imageStem(example)}-${theme}.png`;
const screenshotAlt = (example) => t('screenshotAlt').replace('{name}', nameOf(example));
const notify = (message) => {
  $('#toast').textContent = message;
  $('#toast').classList.add('visible');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => $('#toast').classList.remove('visible'), 2300);
};
if (windowsStudioDownloads.version && windowsStudioDownloads.x64 && windowsStudioDownloads.arm64) document.querySelectorAll('[data-windows-pending]').forEach((notice) => { notice.hidden = true; });
document.querySelectorAll('[data-windows-download]').forEach((link) => {
  const url = windowsStudioDownloads[link.dataset.windowsDownload];
  if (!windowsStudioDownloads.version || !url) return;
  link.href = url; link.removeAttribute('aria-disabled'); link.removeAttribute('role');
});
document.querySelectorAll('[data-workbench-download]').forEach((link) => {
  if (workbenchDownloadURL) {
    link.href = workbenchDownloadURL;
    link.setAttribute('download', '');
    link.removeAttribute('role');
    link.removeAttribute('tabindex');
    return;
  }
  link.addEventListener('click', (event) => {
    event.preventDefault();
    notify(t('workbenchComingSoon'));
  });
  link.addEventListener('keydown', (event) => {
    if (event.key !== 'Enter') return;
    event.preventDefault();
    link.click();
  });
});
// Keep the displayed Kit version in step with the latest GitHub release; the built-in version stays when the request fails.
if (document.querySelector('[data-kit-version]')) fetch('https://api.github.com/repos/dufu1991/nornakit/releases/latest', { headers: { Accept: 'application/vnd.github+json' } })
  .then((response) => response.ok ? response.json() : null)
  .then((release) => {
    const version = /^v(\d+\.\d+\.\d+)$/.exec(release?.tag_name ?? '')?.[1];
    if (!version) return;
    document.querySelectorAll('[data-kit-version]').forEach((element) => { element.textContent = version; });
    document.querySelectorAll('[data-latest-release]').forEach((link) => { link.href = release.html_url; });
  })
  .catch(() => {});
const copy = async (text) => {
  if (!navigator.clipboard) { notify(t('copyFailed')); return; }
  await navigator.clipboard.writeText(text).then(() => notify(t('copied')), () => notify(t('copyFailed')));
};
const updatePreferencePickers = () => {
  const mode = themePreference === 'auto' ? 'autoTheme' : themePreference;
  languagePicker.update({ label: t('language'), display: languagePreference === 'auto' ? t('auto') : languagePreference === 'zh' ? '中文' : 'English', value: languagePreference, icon: 'globe', options: [
    { value: 'auto', label: t('browserLanguage'), icon: 'system' },
    { value: 'zh', label: '中文', icon: 'globe' }, { value: 'en', label: 'English', icon: 'globe' }
  ] });
  themePicker.update({ label: t('appearance'), display: t(mode), value: themePreference, icon: themePreference === 'auto' ? 'system' : themePreference, iconOnly: true, options: [
    { value: 'auto', label: t('autoTheme'), icon: 'system' },
    { value: 'light', label: t('light'), icon: 'light' },
    { value: 'dark', label: t('dark'), icon: 'dark' }
  ] });
};
const updateExample = () => {
  if (!$('#example-source') || !examples.length) return;
  const example = examples.find((item) => item.id === selected);
  $('#example-source').textContent = sourceOf(example);
  setNativeImage($('#example-image'), { stem: imageStem(example), alt: screenshotAlt(example) });
  $('#example-name').textContent = nameOf(example);
  $('#example-panel').setAttribute('aria-label', nameOf(example));
  $('#download-source').href = `assets/${imageStem(example)}.mmd`;
  $('#download-source').download = `${imageStem(example)}.mmd`;
  document.querySelectorAll('#family-index button').forEach((button) => button.setAttribute('aria-pressed', String(button.dataset.example === selected)));
};
const showImage = (example) => {
  imageURL = example;
  const index = examples.findIndex((item) => item.id === example.id);
  $('#dialog-counter').textContent = `${index + 1} / ${examples.length}`;
  $('#dialog-status').textContent = t('previewPosition').replace('{name}', nameOf(example)).replace('{current}', String(index + 1)).replace('{total}', String(examples.length));
  $('#previous-image').disabled = examples.length < 2;
  $('#next-image').disabled = examples.length < 2;
  $('#dialog-title').textContent = nameOf(example);
  setNativeImage($('#dialog-image'), { stem: imageStem(example), alt: screenshotAlt(example), loading: 'eager' });
  $('#download-image').href = screenshot(example);
  $('#download-image').download = `nornakit-${imageStem(example)}-${theme}.png`;
  if (!$('#screenshot-dialog').open) $('#screenshot-dialog').showModal();
};
const navigateImage = (direction) => {
  if (!$('#screenshot-dialog').open || examples.length < 2) return;
  const index = examples.findIndex((item) => item.id === imageURL.id);
  const next = examples[(index + direction + examples.length) % examples.length];
  selected = next.id;
  updateExample();
  showImage(next);
};
const renderGallery = () => {
  if (!$('#gallery') || !examples.length) return;
  $('#gallery').replaceChildren(...examples.map((example) => {
    const button = document.createElement('button');
    const image = createNativeImage({ stem: imageStem(example), alt: screenshotAlt(example) });
    const label = document.createElement('span'); label.textContent = nameOf(example);
    button.append(image, label);
    button.setAttribute('aria-label', `${nameOf(example)} — ${t('viewScreenshot')}`);
    button.addEventListener('click', () => { selected = example.id; updateExample(); showImage(example); });
    return button;
  }));
};
const renderFamilyIndex = () => {
  if (!$('#family-index') || !examples.length) return;
  $('#family-index').replaceChildren(...examples.map((example) => {
    const button = document.createElement('button');
    button.type = 'button'; button.dataset.example = example.id; button.textContent = nameOf(example);
    button.setAttribute('aria-pressed', String(example.id === selected));
    button.addEventListener('click', () => { selected = example.id; updateExample(); });
    return button;
  }));
};
// Tab groups share one copy button that copies the visible panel.
document.querySelectorAll('[data-tabs]').forEach((group) => {
  const tabs = [...group.querySelectorAll('[role=tab]')];
  const select = (tab) => tabs.forEach((item) => {
    const active = item === tab;
    item.setAttribute('aria-selected', String(active)); item.tabIndex = active ? 0 : -1;
    document.getElementById(item.getAttribute('aria-controls')).hidden = !active;
  });
  tabs.forEach((tab, index) => {
    tab.addEventListener('click', () => select(tab));
    tab.addEventListener('keydown', (event) => {
      const offset = { ArrowLeft: -1, ArrowRight: 1 }[event.key];
      if (!offset) return;
      event.preventDefault();
      const next = tabs[(index + offset + tabs.length) % tabs.length];
      select(next); next.focus();
    });
  });
});
document.querySelectorAll('[data-copy]').forEach((button) => {
  button.addEventListener('click', async () => {
    const code = button.closest('.tab-group').querySelector('.tab-panel:not([hidden]) code');
    await copy(code.textContent);
  });
});
const updateSymbolsExample = () => {
  if (!$('#symbols-preview') || !examples.length) return;
  const example = examples.find((item) => item.builtinID === 'sf-symbols');
  $('#symbols-source').textContent = sourceOf(example);
  setNativeImage($('#symbols-preview'), { stem: imageStem(example), alt: t('symbolsAlt') });
  $('#download-symbols').href = `assets/${imageStem(example)}.mmd`;
  $('#download-symbols').download = `${imageStem(example)}.mmd`;
};
for (const language of ['en', 'zh']) Object.assign(translations[language], inlineTranslations[language]);
const localize = () => {
  language = nornaSettings.resolveLanguage(languagePreference);
  theme = nornaSettings.resolveTheme(themePreference);
  nornaSettings.apply(language, theme);
  document.querySelectorAll('[data-i18n]').forEach((element) => { element.textContent = t(element.dataset.i18n); });
  document.querySelectorAll('[data-i18n-html]').forEach((element) => { element.innerHTML = t(element.dataset.i18nHtml); });
  document.querySelectorAll('[data-i18n-aria]').forEach((element) => { element.setAttribute('aria-label', t(element.dataset.i18nAria)); });
  document.querySelectorAll('[data-i18n-alt]').forEach((element) => { element.alt = t(element.dataset.i18nAlt); });
  document.title = t(document.body.dataset.page === 'windows' ? 'windowsPageTitle' : document.body.dataset.page === 'docs' ? 'docsPageTitle' : 'title');
  document.querySelector('meta[name="description"]').content = t('metaDescription');
  if ($('#hero-image')) {
    setNativeImage($('#hero-image'), { stem: `hero-${language}`, alt: t('heroAlt'), loading: 'eager' });
  }
  updateSymbolsExample();
  updateInlineContent(language);
  updatePreferencePickers(); renderFamilyIndex(); updateExample(); renderGallery();
  if ($('#screenshot-dialog')?.open) showImage(imageURL);
};
const syncAppearance = () => {
  theme = nornaSettings.resolveTheme(themePreference);
  nornaSettings.apply(language, theme);
  updatePreferencePickers();
  if ($('#screenshot-dialog')?.open) {
    $('#download-image').href = screenshot(imageURL);
    $('#download-image').download = `nornakit-${imageStem(imageURL)}-${theme}.png`;
  }
};
window.addEventListener('storage', (event) => {
  if (event.key === 'norna-language' || event.key === null) {
    languagePreference = localStorage.getItem('norna-language') || 'auto';
    localize();
  }
  if (event.key === 'norna-theme' || event.key === null) {
    themePreference = localStorage.getItem('norna-theme') || 'auto';
    syncAppearance();
  }
});
window.addEventListener('pageshow', () => {
  languagePreference = localStorage.getItem('norna-language') || 'auto';
  localize();
  themePreference = localStorage.getItem('norna-theme') || 'auto';
  syncAppearance();
});
window.addEventListener('languagechange', () => { if (languagePreference === 'auto') localize(); });
matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => { if (themePreference === 'auto') syncAppearance(); });
$('#copy-example')?.addEventListener('click', async () => { await copy($('#example-source').textContent); });
$('#enlarge-example')?.addEventListener('click', () => showImage(examples.find((item) => item.id === selected)));
$('#previous-image')?.addEventListener('click', () => navigateImage(-1));
$('#next-image')?.addEventListener('click', () => navigateImage(1));
$('#screenshot-dialog')?.addEventListener('keydown', (event) => {
  if (event.altKey || event.ctrlKey || event.metaKey || event.shiftKey || event.isComposing) return;
  if (event.target.closest('input, textarea, [contenteditable="true"]')) return;
  if (!['ArrowLeft', 'ArrowRight'].includes(event.key)) return;
  event.preventDefault();
  navigateImage(event.key === 'ArrowLeft' ? -1 : 1);
});
$('#close-dialog')?.addEventListener('click', () => $('#screenshot-dialog').close());
$('#screenshot-dialog')?.addEventListener('click', (event) => {
  if (event.target !== $('#screenshot-dialog')) return;
  const box = $('#screenshot-dialog').getBoundingClientRect();
  if (event.clientX < box.left || event.clientX > box.right || event.clientY < box.top || event.clientY > box.bottom) $('#screenshot-dialog').close();
});
const sponsorDialog = $('#sponsor-dialog');
document.querySelectorAll('[data-open-sponsor]').forEach((button) => {
  button.addEventListener('click', () => sponsorDialog.showModal());
});
$('#close-sponsor')?.addEventListener('click', () => sponsorDialog.close());
sponsorDialog?.addEventListener('click', (event) => {
  if (event.target !== sponsorDialog) return;
  const box = sponsorDialog.getBoundingClientRect();
  if (event.clientX < box.left || event.clientX > box.right || event.clientY < box.top || event.clientY > box.bottom) sponsorDialog.close();
});
localize();
const loadExamples = async () => {
  const response = await fetch('examples.json');
  if (!response.ok) throw new Error(`Examples request failed: ${response.status}`);
  examples = await response.json(); renderFamilyIndex(); updateExample(); renderGallery(); updateSymbolsExample();
};
if ($('#example-source') || $('#symbols-preview')) loadExamples().catch(() => {
  const source = $('#example-source') || $('#symbols-source');
  source.textContent = t('loadError');
});
