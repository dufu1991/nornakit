import { workbenchDownloadURL } from './download-config.js';
import { inlineTranslations, updateInlineContent } from './inline-content.js';
import { createPicker, icon } from './components.js';
import { createNativeImage, setNativeImage } from './native-images.js';
const translations = {
  en: {
    skip: 'Skip to content', navigation: 'Main navigation', examples: 'Examples', getStarted: 'Get started', docs: 'Docs', language: 'Language', auto: 'Auto', eyebrow: 'BUILT WITH SWIFT. NATIVE BY DESIGN.', headline: 'Give your ideas<br><span class="hero-accent">a clearer shape.</span>', description: 'Mermaid diagrams, rendered natively in Swift.\nFrom a few lines of text to a picture that makes sense.', explore: 'Explore the examples', useSwift: 'Use it in Swift', pureSwift: 'Pure Swift', noWebView: 'No WebView', nativePreview: 'Native rendering preview', nativeOutput: 'Native output', screenshotNote: 'An actual Swift render. Presented here as a screenshot.', features: 'Features', feature1Title: 'Native, all the way.', feature1: 'Parsing, text measurement, layout, and drawing happen in Swift. No browser runtime in your app.', feature2Title: 'One scene. More possibilities.', feature2: 'The native canvas and SVG share the same geometry. Preview your diagram, then take it with you.', feature3Title: 'A focused native editor.', feature3: 'System typography, light and dark appearances, and a focused editor for your Mermaid files.', collection: 'THE NATIVE COLLECTION', examplesTitle: 'A little syntax. A lot of clarity.', families: '33 diagram families · 36 examples', examplesDescription: 'Explore native output across 33 diagram families, plus three built-in SF Symbols examples. Select an example to see its screenshot and source.', diagramExamples: 'Diagram examples', allExamples: 'All examples', source: 'Source', copy: 'Copy', copied: 'Copied to clipboard', copyFailed: 'Could not copy. Select the code to copy it manually.', downloadSource: 'Download .mmd', enlarge: 'Enlarge screenshot', viewScreenshot: 'View screenshot', compatibility: 'Each family includes a working example. Syntax support varies by diagram type.', supportLink: 'See support notes ↗', browseAll: 'Browse all 36 examples', builtFor: 'NATIVE DIAGRAMS FOR YOUR APP', startTitle: 'A native canvas.<br>A familiar language.', startDescription: 'Use the rendering library in your app, or open Norna Studio to write, preview, and export diagrams on your Mac.', readDocs: 'Read the documentation', studioSubtitle: 'The companion Mac editor', moduleNote: 'Add the Norna package and import NornaKit to render diagrams.', closing: 'Less between your idea and the diagram.', takeLook: 'Take a closer look', footerSubtitle: 'Native diagrams, clearly.', support: 'Support', credits: 'Credits', attribution: 'Built with Swift. Native by design.', close: 'Close', downloadScreenshot: 'Download screenshot', appearance: 'Appearance', autoTheme: 'System', light: 'Light', dark: 'Dark', screenshotAlt: 'Native Swift render of a {name} diagram', title: 'Norna — Native diagrams, clearly.', metaDescription: 'Norna turns Mermaid source into native diagrams with Swift. Explore 33 diagram families, native screenshots, and a focused Mac editor.', heroAlt: 'An idea becomes Mermaid source, then a native diagram and an SVG export', loadError: 'Examples could not load. Refresh the page to try again.', docsTitle: 'Small library. Native foundations.', docsLead: 'Norna is a pure Swift diagram engine. Integrate NornaKit in your app, or use the companion Norna Studio editor on your Mac.', requirementsTitle: 'Requirements', requirements: 'NornaKit and Norna Studio currently support macOS 14 or later. Build the app with Xcode 26 or later; the package requires Swift 6. The package declares no external package dependencies.', integrateTitle: 'Render a diagram', integrate: 'Add the Norna package from https://github.com/dufu1991/norna to your Xcode project and link the NornaKit library product. Rendering produces a scene for native drawing and SVG for export.', setupNotice: 'Source is available at github.com/dufu1991/norna. Packaged app downloads become available after the first successful Studio release.', studioTitle: 'Run Norna Studio', studio: 'From the project directory, open the Xcode project and select the NornaStudio scheme, or run the Swift package command below.', supportTitle: 'Support and current limits', supportIntro: 'The engine has 33 diagram families, with basic parsing, dedicated layouts, and working examples. This does not mean full Mermaid syntax compatibility.', support1: 'Flowcharts, sequence diagrams, class diagrams, state diagrams, entity relationships, and C4 architecture.', support2: 'Pie, XY, radar, Sankey, treemap, Gantt, timelines, and more.', support3: 'Layout adapts for supported families. Dense data or long labels may still cause crossings or crowding.', support4: 'Arbitrary HTML, CSS, scripts, and full Markdown styling are not interpreted.', originalSupport: 'Download the detailed support matrix in Chinese', screenshotsTitle: 'About the examples', screenshots: 'Every diagram on this site is a PNG produced by the Swift native drawing pipeline. The browser displays screenshots and source text; it does not execute the diagram engine. Example sources and screenshot labels follow the selected language. Both languages include light and dark screenshots.', attributionTitle: 'Acknowledgments', attributionDocs: 'Some measurement and layout formulas are adapted from Pele. Upstream license notices are included with the project. Norna is an independent project.', notices: 'Read third-party notices', originalReadme: 'Download the project README', docsPageTitle: 'Documentation — Norna', back: 'Back to Norna'
  },
  zh: {
    skip: '跳转到正文', navigation: '主导航', examples: '示例', getStarted: '开始使用', docs: '文档', language: '语言', auto: '自动', eyebrow: '以 Swift 构建，让图表原生呈现', headline: '让思路，<br><span class="hero-accent">清晰成形。</span>', description: '用 Swift 原生渲染 Mermaid 图表。\n几行文字，把想法变成看得懂的结构。', explore: '浏览图表示例', useSwift: '在 Swift 中使用', pureSwift: '纯 Swift', noWebView: '无 WebView', nativePreview: '原生渲染预览', nativeOutput: '原生绘制结果', screenshotNote: '由 Swift 原生绘制，本站以截图呈现。', features: '功能特点', feature1Title: '从头到尾，原生完成。', feature1: '解析、文本测量、布局与绘制，全部由 Swift 完成。应用无须嵌入浏览器运行时。', feature2Title: '同一场景，多种可能。', feature2: '原生画布与 SVG 共用几何数据。从预览到导出，让图表自然融入你的工作流。', feature3Title: '原生编辑，专注表达。', feature3: '系统字体、浅深色外观，以及专注于 Mermaid 文件的原生编辑器。', collection: '原生图表示例集', examplesTitle: '几行语法，理清复杂。', families: '33 类图形 · 36 个示例', examplesDescription: '查看 33 类图形和 3 个 SF Symbols 内置示例的原生输出。选择示例，对照浅深色预览与对应源码。', diagramExamples: '图表示例', allExamples: '全部示例', source: '源码', copy: '复制', copied: '已复制到剪贴板', copyFailed: '复制未成功，请选中代码手动复制。', downloadSource: '下载 .mmd 源码', enlarge: '放大截图', viewScreenshot: '查看截图', compatibility: '每类图形均有可运行示例，具体语法支持范围因类型而异。', supportLink: '查看支持说明 ↗', browseAll: '浏览全部 36 个示例', builtFor: '为应用集成原生图表', startTitle: '原生的画布，<br>熟悉的表达。', startDescription: '在应用中集成渲染库，或打开 Norna Studio，在 Mac 上编写、预览并导出图表。', readDocs: '阅读接入文档', studioSubtitle: '配套的 Mac 图表编辑器', moduleNote: '添加 Norna 包，导入 NornaKit 即可渲染图表。', closing: '从想法到图表，少一点距离。', takeLook: '再看看示例', footerSubtitle: '让思路，清晰成形。', support: '支持范围', credits: '致谢', attribution: '以 Swift 构建，原生呈现。', close: '关闭', downloadScreenshot: '下载截图', appearance: '外观', autoTheme: '跟随系统', light: '浅色', dark: '深色', screenshotAlt: '由 Swift 原生绘制的 {name} 截图', title: 'Norna — 让思路，清晰成形。', metaDescription: 'Norna 使用 Swift 原生渲染 Mermaid 图表，提供 33 类图形、原生示例截图与专注的 Mac 图表编辑器。', heroAlt: '从输入想法、编写 Mermaid，到原生引擎生成图表与导出 SVG 的流程图', loadError: '示例加载失败，请刷新页面重试。', docsTitle: '轻量的库，原生的基础。', docsLead: 'Norna 是纯 Swift 图表引擎。通过 NornaKit 集成到应用，或使用配套的 Norna Studio 编辑器。', requirementsTitle: '运行要求', requirements: '当前 NornaKit 与 Norna Studio 支持 macOS 14 或更高版本，完整应用要求 Xcode 26 或更高版本，Swift Package 要求 Swift 6。当前包没有外部包依赖。', integrateTitle: '渲染一张图表', integrate: '在 Xcode 项目中添加 https://github.com/dufu1991/norna 上的 Norna 包，并链接 NornaKit 库产品。渲染后可获取用于原生绘制的场景，以及用于导出的 SVG。', setupNotice: '源码仓库位于 github.com/dufu1991/norna。首次工作台发布成功后，即可下载安装包。', studioTitle: '运行 Norna Studio', studio: '在项目目录中打开 Xcode 工程，选择 NornaStudio scheme，或使用下方的 Swift Package 命令运行。', supportTitle: '支持范围与当前限制', supportIntro: '引擎覆盖 33 类图形，提供基础解析、专用布局与可运行示例。这不代表完整兼容 Mermaid 的全部语法。', support1: '流程图、时序图、类图、状态图、实体关系图，以及 C4 架构图等。', support2: '饼图、XY 坐标图、雷达图、桑基图、矩形树图、甘特图与时间线等。', support3: '部分图形支持自适应布局，密集数据或过长标签仍可能产生交叉与拥挤。', support4: '不解释任意 HTML、CSS、脚本或完整的 Markdown 富文本样式。', originalSupport: '下载完整中文支持矩阵', screenshotsTitle: '关于本站示例', screenshots: '本站所有图表均为 Swift 原生绘制流程生成的 PNG。浏览器只展示截图和源码，不执行图表引擎。示例源码和截图标签随语言切换，中英文均提供浅色与深色版本。', attributionTitle: '致谢', attributionDocs: '部分测量与布局公式参考并移植自 Pele，项目包含相应的上游许可声明。Norna 是独立项目。', notices: '阅读第三方许可声明', originalReadme: '下载项目中文 README', docsPageTitle: '文档 — Norna', back: '返回 Norna'
  }
};
Object.assign(translations.en, { browserLanguage: 'Follow browser', searchExamples: 'Search examples…', noResults: 'No examples found', pickerLabel: 'Example' });
Object.assign(translations.zh, { browserLanguage: '跟随浏览器', searchExamples: '搜索示例名称…', noResults: '没有找到匹配的示例', pickerLabel: '示例' });
Object.assign(translations.en, { workbench: 'Studio', workbenchDownload: 'Download Norna Studio for Mac', workbenchComingSoon: 'The Mac app download is coming soon.' });
Object.assign(translations.zh, { workbench: '工作台', workbenchDownload: '下载 Mac 版 Norna Studio', workbenchComingSoon: 'Mac 版工作台下载即将开放。' });
Object.assign(translations.en, { previousImage: 'Previous image', nextImage: 'Next image', browseScreenshots: 'Browse screenshots', navigationHint: 'Use ← → to browse', previewPosition: '{name}, image {current} of {total}.' });
Object.assign(translations.zh, { previousImage: '上一张', nextImage: '下一张', browseScreenshots: '浏览截图', navigationHint: '使用左右方向键切换', previewPosition: '{name}，第 {current} 张，共 {total} 张。' });
Object.assign(translations.en, { currentPlatform: 'Currently macOS 14+' });
Object.assign(translations.zh, { currentPlatform: '当前支持 macOS 14+' });
Object.assign(translations.en, {
  symbolsTitle: 'SF Symbols inside text',
  symbolsLead: 'Write :sf:name: anywhere in a displayed label, for example Upload :sf:icloud.and.arrow.up: file. Use the exact system symbol name from the SF Symbols app. Multiple symbols can appear in one label.',
  symbolsLayout: 'Monochrome symbols follow the surrounding text size, weight, and color. They align to the text baseline and count toward label width. Automatic wrapping keeps each complete symbol token together; explicit line breaks still work. Leading, center, and trailing alignment apply to the whole line.',
  symbolsAvailability: 'Available symbols depend on the macOS version rendering the diagram. Unknown names and incomplete tokens remain visible as source text. Use quoted labels when the diagram syntax requires them; this notation belongs in label text, not node identifiers or numeric fields.',
  symbolsExport: 'PNG, JPEG, TIFF, and PDF include the symbols through native drawing. SVG embeds each symbol as a transparent PNG at 4× resolution; text and diagram paths remain vector elements. Exported files need no SF Symbols installation or external icon files. The symbol images embedded in SVG have finite resolution.',
  symbolsExtension: 'This is a Norna extension to label syntax. Other Mermaid renderers may display the token as text. It does not change the built-in architecture diagram icon syntax.',
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
  symbolsExtension: '这是 Norna 的标签语法扩展，其他 Mermaid 渲染器可能将标记显示为文字。此功能不改变架构图已有的内置图标语法。',
  symbolsCaption: '原生引擎实际输出，展示子图标题、节点和连线标签中的图标。源码和预览跟随站点语言与外观切换。',
  symbolsAlt: '在标签中嵌入 SF Symbols 的原生图表',
  symbolsDownload: '下载 SF Symbols 示例源码'
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
const examplePicker = $('#example-picker') ? createPicker({ host: $('#example-picker'), id: 'all-examples', searchable: true, onChange: (value) => {
  selected = value; updateExample();
} }) : null;
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
  examplePicker.setValue(selected);
  $('#example-panel').setAttribute('aria-label', nameOf(example));
  $('#download-source').href = `assets/${imageStem(example)}.mmd`;
  $('#download-source').download = `${imageStem(example)}.mmd`;
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
  $('#download-image').download = `norna-${imageStem(example)}-${theme}.png`;
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
const renderExamplePicker = () => {
  if (!examplePicker || !examples.length) return;
  const example = examples.find((item) => item.id === selected);
  examplePicker.update({ label: t('pickerLabel'), display: nameOf(example), value: selected, icon: 'grid', searchPlaceholder: t('searchExamples'), emptyText: t('noResults'), options: examples.map((item) => ({ value: item.id, label: nameOf(item), searchText: `${item.zh} ${item.en} ${item.id}` })) });
};
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
  const readmeLink = document.querySelector('[data-i18n="originalReadme"]');
  if (readmeLink) readmeLink.href = `assets/README.${language}.md`;
  document.title = t(document.body.dataset.page === 'docs' ? 'docsPageTitle' : 'title');
  document.querySelector('meta[name="description"]').content = t('metaDescription');
  if ($('#hero-image')) {
    setNativeImage($('#hero-image'), { stem: `hero-${language}`, alt: t('heroAlt'), loading: 'eager' });
  }
  updateSymbolsExample();
  updateInlineContent(language);
  updatePreferencePickers(); renderExamplePicker(); updateExample(); renderGallery();
  if ($('#screenshot-dialog')?.open) showImage(imageURL);
};
const syncAppearance = () => {
  theme = nornaSettings.resolveTheme(themePreference);
  nornaSettings.apply(language, theme);
  updatePreferencePickers();
  if ($('#screenshot-dialog')?.open) {
    $('#download-image').href = screenshot(imageURL);
    $('#download-image').download = `norna-${imageStem(imageURL)}-${theme}.png`;
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
$('#copy-swift')?.addEventListener('click', async () => { await copy($('#swift-code').textContent); });
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
localize();
const loadExamples = async () => {
  const response = await fetch('examples.json');
  if (!response.ok) throw new Error(`Examples request failed: ${response.status}`);
  examples = await response.json(); renderExamplePicker(); updateExample(); renderGallery(); updateSymbolsExample();
};
if (examplePicker || $('#symbols-preview')) loadExamples().catch(() => {
  const source = $('#example-source') || $('#symbols-source');
  source.textContent = t('loadError');
});
