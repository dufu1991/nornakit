import { setNativeImage } from './native-images.js';

export const inlineTranslations = {
  "en": {
    "inlineTitle": "Native content inside labels",
    "inlineLead": "Mix SF Symbols and native rich text in the same label. These are NornaKit label extensions. Quote labels when required by the diagram syntax.",
    "inlineColorTitle": "SF Symbols rendering modes",
    "inlineColorBody": "Keep :sf:name: for monochrome symbols, or use @monochrome, @hierarchical, @multicolor, or @palette(#2563eb,#f59e0b). Palette mode accepts one to three six-digit hex colors without spaces. Multicolor uses the symbol’s native colors; hierarchical uses the current text color. Available symbols and color layers depend on the rendering macOS version and the symbol. A symbol without native multicolor layers uses monochrome rendering.",
    "inlineRichTitle": "Native rich text",
    "inlineRichBody": "Use paired [b], [i], [code], [u], [s], and [color=#2563eb] tags for bold, italic, monospace, underline, strikethrough, and color. Close them with [/b], [/i], [/code], [/u], [/s], and [/color]. Tags can nest and span line breaks. Unclosed, mismatched, and unsupported tags remain literal text.",
    "inlineLayoutTitle": "Wrapping, alignment, and export",
    "inlineLayoutBody": "Both content types share native measurement and line layout. Automatic wrapping keeps each complete symbol token together and retains rich text styles on every line. Explicit line breaks work as usual. Leading, center, and trailing alignment position the whole mixed line. PNG, JPEG, TIFF, and PDF use the same native drawing pipeline. SVG keeps text and diagram paths as vector elements and embeds symbols as transparent PNG data at 4× the label’s logical resolution. Those embedded symbols have finite resolution; exported files require no external icon resources.",
    "inlineCaption": "Exact built-in example source, rendered natively in Swift. Use the appearance control above to switch between light and dark previews.",
    "inlineDownload": "Download this .mmd example",
    "inlineAlt": "Native preview of {name}",
    "inlineLoadError": "Native inline examples could not load. Refresh the page to try again."
  },
  "zh": {
    "inlineTitle": "标签中的原生内容",
    "inlineLead": "同一标签可以混合 SF Symbols 与原生富文本。这些写法属于 NornaKit 标签扩展；图表语法要求引号时，请使用带引号的标签。",
    "inlineColorTitle": "SF Symbols 渲染模式",
    "inlineColorBody": "保留 :sf:名称: 作为单色写法，也可指定 @monochrome、@hierarchical、@multicolor 或 @palette(#2563eb,#f59e0b)。调色板接受 1 至 3 个六位十六进制颜色，颜色之间不留空格。多色模式使用图标原生颜色，层级模式使用当前文字颜色。图标可用性和颜色层级取决于渲染时的 macOS 版本及图标本身；没有原生多色层级的图标按单色绘制。",
    "inlineRichTitle": "原生富文本",
    "inlineRichBody": "使用成对的 [b]、[i]、[code]、[u]、[s] 和 [color=#2563eb] 标签，分别表示粗体、斜体、等宽、下划线、删除线和文字颜色。对应结束标签为 [/b]、[/i]、[/code]、[/u]、[/s] 和 [/color]。标签可以嵌套并跨行使用。未闭合、嵌套不匹配及不支持的标签保留为原文。",
    "inlineLayoutTitle": "换行、对齐与导出",
    "inlineLayoutBody": "两种内容共用原生测量和行布局。自动换行保留完整的图标标记，富文本在换行后继续保留样式，显式换行仍然有效。左对齐、居中和右对齐作用于整行混合内容。PNG、JPEG、TIFF 和 PDF 共用原生绘制流程。SVG 保留文字和图形路径的矢量形式，将图标按标签逻辑尺寸的 4 倍分辨率内嵌为透明 PNG。内嵌图标具有有限分辨率，导出文件不依赖外部图标资源。",
    "inlineCaption": "使用工作台内置示例的相同源码，由 Swift 原生渲染。通过页面顶部的外观选项切换浅色和深色预览。",
    "inlineDownload": "下载此示例的 .mmd 源码",
    "inlineAlt": "{name}的原生预览",
    "inlineLoadError": "原生内联示例加载失败，请刷新页面重试。"
  }
};
let examplesPromise;
let activeLanguage;

export const updateInlineContent = (language) => {
  const sections = [...document.querySelectorAll('[data-inline-example]')];
  if (!sections.length) return;
  activeLanguage = language;
  if (!examplesPromise) {
    examplesPromise = fetch('assets/inline-examples.json').then(async (response) => {
      if (!response.ok) throw new Error(`Inline examples: ${response.status}`);
      return await response.json();
    });
  }
  examplesPromise.then((examples) => {
    if (activeLanguage !== language) return;
    for (const section of sections) {
      const example = examples.find((item) => item.id === section.dataset.inlineExample);
      section.querySelector('[data-inline-source]').textContent = example.sources[language];
      const stem = `inline-${example.id}-${language}`;
      setNativeImage(section.querySelector('[data-inline-preview]'), {
        stem,
        alt: inlineTranslations[language].inlineAlt.replace('{name}', section.querySelector('h3').textContent),
      });
      const download = section.querySelector('[data-inline-download]');
      download.href = `assets/${stem}.mmd`;
      download.download = `${stem}.mmd`;
    }
  }, () => {
    if (activeLanguage !== language) return;
    for (const section of sections) {
      section.querySelector('[data-inline-source]').textContent = inlineTranslations[language].inlineLoadError;
    }
  });
};
