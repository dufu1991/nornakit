import AppKit
import NornaKit
import NornaExamples
import SwiftUI

struct StudioView: View {
    @ObservedObject var model: StudioModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var zoomRequest = 0
    @State private var fitRequest = 0
    @State private var search = ""
    @StateObject private var systemColorPicker = SystemColorPicker()

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 280)
        } detail: {
            VStack(spacing: 0) {
                exampleSwitcher
                HSplitView {
                    editor.frame(minWidth: 280, idealWidth: 380, maxWidth: 480)
                    preview.frame(minWidth: 300)
                }
                statusBar
            }
            .navigationTitle("Norna Studio")
            .toolbar { toolbar }
        }
        .environment(\.locale, model.language.locale)
        .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in
            if model.language == .system { model.refreshExampleLanguage() }
            model.objectWillChange.send()
        }
        .onDisappear { systemColorPicker.close() }
        .tint(brandAccent)
        .accentColor(brandAccent)
        .task(id: model.renderRequest) { await model.refresh() }
        .onChange(of: colorScheme, initial: true) { _, _ in updateAppearance() }
        .onChange(of: contrast) { _, _ in updateAppearance() }
        .onChange(of: model.appearance) { _, _ in updateAppearance() }
        .sheet(item: $model.exportSession) { session in
            DiagramExportView(model: model, session: session).tint(brandAccent)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSColor.systemColorsDidChangeNotification)) { _ in
            model.refreshSystemColors()
        }
        .alert("文件操作失败".studioLocalized, isPresented: Binding(
            get: { model.fileError != nil },
            set: { if !$0 { model.fileError = nil } }
        )) {
            Button("好".studioLocalized) { model.fileError = nil }
        } message: { Text(model.fileError ?? "") }
    }

    private var brandAccent: Color {
        let dark = colorScheme == .dark
        let theme: DiagramTheme = contrast == .increased
            ? (dark ? .appleDarkHighContrast : .appleLightHighContrast)
            : (dark ? .appleDark : .appleLight)
        return Color(nsColor: CoreGraphicsDiagramPainter.color(theme.colors(for: .themed).accent))
    }

    private var sidebar: some View {
        let language = model.resolvedLanguage
        return List(selection: Binding(get: { model.activeKind }, set: model.openDiagramType)) {
            ForEach(DiagramCategory.allCases) { category in
                let kinds = DiagramKind.allCases.filter {
                    $0.category == category && (search.isEmpty
                        || $0.title.localizedCaseInsensitiveContains(search)
                        || StudioLocalization.text($0.title, language: .english).localizedCaseInsensitiveContains(search)
                        || $0.rawValue.localizedCaseInsensitiveContains(search))
                }
                if !kinds.isEmpty {
                    Section(StudioLocalization.text(category.title, language: language)) {
                        ForEach(kinds) { kind in
                            Label {
                                Text(StudioLocalization.text(kind.title, language: language))
                            } icon: {
                                Image(systemName: kind.symbol)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 12, height: 12)
                            }
                                .tag(kind)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $search, placement: .sidebar, prompt: "搜索图形".studioLocalized)

    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        let currentLanguage = model.resolvedLanguage
        ToolbarItem {
            Button(action: model.saveSource) { Label("保存源码".studioLocalized, systemImage: "square.and.arrow.down") }
                .help("保存 Mermaid 源码".studioLocalized)
        }
        ToolbarItem {
            Menu {
                Picker("画布外观".studioLocalized, selection: $model.appearance) {
                    ForEach(CanvasAppearance.allCases) { appearance in Text(StudioLocalization.text(appearance.title, language: currentLanguage)).tag(appearance) }
                }
                Picker("语言".studioLocalized, selection: $model.language) {
                    ForEach(StudioLanguage.allCases) { language in Text(StudioLocalization.text(language.title, language: currentLanguage)).tag(language) }
                }
                Divider()
                Toggle("自适应布局".studioLocalized, isOn: $model.adaptiveLayout)
                Toggle("显示网格".studioLocalized, isOn: $model.showGrid)
            } label: { Label("显示".studioLocalized, systemImage: "slider.horizontal.3") }
            .help("画布外观与布局".studioLocalized)
        }
        ToolbarItemGroup {
            Button(action: model.copySVG) { Label("复制 SVG 源码".studioLocalized, systemImage: "doc.on.doc") }
                .help("将当前图表的 SVG 源码复制到剪贴板".studioLocalized)
                .disabled(!model.canExport)
            Button(action: model.presentExport) { Label("导出图表".studioLocalized, systemImage: "square.and.arrow.up") }
                .disabled(!model.canExport)
        }
    }

    private var editor: some View {
        VStack(spacing: 0) {
            HStack {
                Label("源码".studioLocalized, systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 16).frame(height: 44)
            Divider()
            SourceEditor(text: $model.source)
        }
        .background(.background)
    }

    @ViewBuilder
    private var exampleSwitcher: some View {
        let language = model.resolvedLanguage
        if !model.examplesForActiveKind.isEmpty {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        if let comparison = model.exampleComparison {
                            exampleButton("简单示例".studioLocalized, example: comparison.simple).id(comparison.simple.id)
                            exampleButton("复杂示例".studioLocalized, example: comparison.complex).id(comparison.complex.id)
                        }
                        ForEach(model.additionalExamplesForActiveKind) { example in
                            exampleButton(example.studioTitle(language: language), example: example).id(example.id)
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .controlSize(.small)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                }
                .scrollIndicators(.visible)
                .accessibilityLabel("图形示例".studioLocalized)
                .onChange(of: model.selectedExample, initial: true) { _, selected in
                    if let selected { proxy.scrollTo(selected, anchor: .center) }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(.bar)
            Divider()
        }
    }

    @ViewBuilder
    private func exampleButton(_ title: String, example: DiagramExample) -> some View {
        if model.source == example.source {
            Button(title) { model.loadExample(example.id) }
                .buttonStyle(.borderedProminent)
                .accessibilityAddTraits(.isSelected)
                .help(StudioLocalization.format("重新加载 %@", title))
        } else {
            Button(title) { model.loadExample(example.id) }
                .buttonStyle(.bordered)
                .help(StudioLocalization.format("用 %@ 替换当前源码", title))
        }
    }

    private var preview: some View {
        let language = model.resolvedLanguage
        return VStack(spacing: 0) {
            HStack {
                Text(model.activeKind?.title.studioLocalized ?? "预览".studioLocalized).font(.subheadline.weight(.semibold))
                Spacer()
                if model.isRendering { ProgressView().controlSize(.small).accessibilityLabel("正在绘制".studioLocalized) }
                Button { zoomRequest -= 1 } label: { Image(systemName: "minus.magnifyingglass") }
                    .help("缩小".studioLocalized)
                Button { fitRequest += 1 } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                    .help("适应画布".studioLocalized)
                Button { zoomRequest += 1 } label: { Image(systemName: "plus.magnifyingglass") }
                    .help("放大".studioLocalized)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 16).frame(height: 44)
            Divider()
            HStack {
                Picker("图表风格".studioLocalized, selection: $model.colorStyle) {
                    ForEach(DiagramColorStyle.allCases) { style in Text(StudioLocalization.text(style.title, language: language)).tag(style) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 240)
                .help("仅切换配色，保留当前布局与线内标签".studioLocalized)
                if model.colorStyle == .custom {
                    Button { systemColorPicker.show(color: $model.customAccent) } label: {
                        Circle().fill(Color(nsColor: CoreGraphicsDiagramPainter.color(model.customAccent.hex)))
                            .overlay(Circle().strokeBorder(.secondary, lineWidth: 1))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("自定义主题颜色".studioLocalized)
                    .help("自定义主题颜色".studioLocalized)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).frame(height: 40)
            .background(.bar)
            .onChange(of: model.colorStyle) { _, style in
                if style == .custom { systemColorPicker.show(color: $model.customAccent) }
                else { systemColorPicker.close() }
            }
            Divider()
            ZStack {
                NativeDiagramPreview(language: language, scene: model.artifact?.scene, theme: model.theme, colorStyle: model.colorStyle, customAccent: model.customAccent, paletteRevision: model.paletteRevision,
                    showGrid: model.showGrid, zoomRequest: zoomRequest, fitRequest: fitRequest, onWidthChange: model.updateAvailableWidth)
                if model.artifact == nil {
                    ContentUnavailableView("开始绘制图表".studioLocalized, systemImage: "point.3.connected.trianglepath.dotted",
                        description: Text("选择一种图形，或输入 Mermaid 源码。".studioLocalized))
                }
            }
            if let error = model.error {
                VStack(alignment: .leading, spacing: 6) {
                    Label("源码需要调整".studioLocalized, systemImage: "exclamationmark.triangle")
                        .font(.callout.weight(.medium))
                    Text(error).font(.caption).textSelection(.enabled).lineLimit(5)
                    if model.artifact != nil { Text("修正后自动更新，当前保留上一次预览。".studioLocalized).font(.caption) }
                }
                .foregroundStyle(.primary).padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary)
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Image(systemName: model.error != nil ? "exclamationmark.triangle" : model.isRendering ? "clock" : "checkmark.circle")
            Text(model.error != nil ? "源码需要调整".studioLocalized : model.isRendering ? "正在绘制".studioLocalized : model.artifact == nil ? "等待输入".studioLocalized : "已更新".studioLocalized)
            Spacer()
            Text(StudioLocalization.format("%ld 行", model.source.components(separatedBy: "\n").count))
            Text("·").foregroundStyle(.tertiary)
            Text(StudioLocalization.format("%ld 字符", model.source.count))
            if let artifact = model.artifact {
                Divider().frame(height: 10)
                Text("\(Int(artifact.width)) × \(Int(artifact.height))")
            }
        }
        .font(.caption).foregroundStyle(.secondary)
        .padding(.horizontal, 16).frame(height: 30)
        .background(.bar)
    }

    private func updateAppearance() {
        model.updateAppearance(systemIsDark: colorScheme == .dark, highContrast: contrast == .increased)
    }
}
