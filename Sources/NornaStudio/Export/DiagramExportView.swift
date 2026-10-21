import AppKit
import NornaKit
import SwiftUI

struct DiagramExportSession: Identifiable, Sendable {
    let id = UUID()
    let artifact: DiagramArtifact
    let theme: DiagramTheme
    let colorStyle: DiagramColorStyle
    let customAccent: DiagramAccentColor
}

struct PreparedDiagramExport: Sendable {
    let options: DiagramExportOptions
    let data: Data

    static func generate(session: DiagramExportSession, options: DiagramExportOptions) async throws -> Self {
        try Task.checkCancellation()
        let worker = Task.detached(priority: .utility) {
            try DiagramExporter.data(for: session.artifact.scene, theme: session.theme,
                colorStyle: session.colorStyle, customAccent: session.customAccent, options: options)
        }
        let data = try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
        try Task.checkCancellation()
        return Self(options: options, data: data)
    }
}

struct DiagramExportView: View {
    @ObservedObject var model: StudioModel
    let session: DiagramExportSession
    @Environment(\.dismiss) private var dismiss
    @State private var options = DiagramExportOptions()
    @State private var preview: NSImage?
    @State private var previewError: String?
    @State private var fileError: String?
    @State private var saving = false
    @State private var preparedExport: PreparedDiagramExport?
    @State private var preparationError: String?

    private var outputSize: CGSize? { try? DiagramExporter.outputSize(for: session.artifact.scene, options: options) }
    private var dimensions: String {
        guard let size = outputSize else { return "尺寸过大，请降低倍率或留白。".studioLocalized }
        let unit = options.format.isVector ? "点".studioLocalized : "像素".studioLocalized
        return "\(Int(ceil(size.width))) × \(Int(ceil(size.height))) \(unit)"
    }

    private var currentExport: PreparedDiagramExport? {
        guard let preparedExport, preparedExport.options == options else { return nil }
        return preparedExport
    }

    private var exportSummary: String {
        guard outputSize != nil else { return dimensions }
        let size: String
        if let currentExport {
            let bytes = Int64(currentExport.data.count).formatted(.byteCount(style: .file).locale(model.language.locale))
            size = StudioLocalization.format("约 %@", bytes)
        } else if preparationError != nil {
            size = "无法计算大小".studioLocalized
        } else {
            size = "计算大小…".studioLocalized
        }
        return dimensions + " · " + size
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("导出图表".studioLocalized, systemImage: "square.and.arrow.up").font(.title3.weight(.semibold))
                Spacer()
                Text(session.artifact.scene.kind.title.studioLocalized).foregroundStyle(.secondary)
            }.padding(20)
            Divider()
            HStack(spacing: 0) {
                proof.padding(20).frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                controls.frame(width: 300)
            }
            Divider()
            HStack {
                if saving {
                    ProgressView().controlSize(.small)
                    Text("正在保存…".studioLocalized).font(.caption).foregroundStyle(.secondary)
                } else if let preparationError {
                    Text(preparationError).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                Button("取消".studioLocalized) { dismiss() }.keyboardShortcut(.cancelAction).disabled(saving)
                Button("导出…".studioLocalized) {
                    guard let prepared = currentExport else { return }
                    Task {
                        saving = true
                        defer { saving = false }
                        do {
                            if try await model.saveExport(session, prepared: prepared) { dismiss() }
                        } catch { fileError = StudioLocalization.errorDescription(error) }
                    }
                }
                .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                .disabled(saving || currentExport == nil)
            }.padding(20)
        }
        .frame(width: 820, height: 600)
        .onChange(of: options.format) { _, format in
            if !format.supportsTransparency { options.background = .theme }
        }
        .task(id: options) {
            let snapshot = options
            preparedExport = nil
            preparationError = nil
            do {
                try await Task.sleep(for: .milliseconds(250))
                let prepared = try await PreparedDiagramExport.generate(session: session, options: snapshot)
                try Task.checkCancellation()
                preparedExport = prepared
            } catch is CancellationError {
                // A newer option selection owns the preparation state.
            } catch {
                guard !Task.isCancelled else { return }
                preparationError = StudioLocalization.errorDescription(error)
            }
        }
        .task(id: options) {
            let snapshot = options
            previewError = nil
            do {
                let data = try await Task.detached(priority: .userInitiated) {
                    try DiagramExporter.preview(for: session.artifact.scene, theme: session.theme,
                        colorStyle: session.colorStyle, customAccent: session.customAccent, options: snapshot)
                }.value
                guard !Task.isCancelled else { return }
                preview = NSImage(data: data)
            } catch {
                guard !Task.isCancelled else { return }
                preview = nil
                previewError = StudioLocalization.errorDescription(error)
            }
        }
        .alert("导出失败".studioLocalized, isPresented: Binding(get: { fileError != nil }, set: { if !$0 { fileError = nil } })) {
            Button("好".studioLocalized) { fileError = nil }
        } message: { Text(fileError ?? "") }
    }

    private var proof: some View {
        ZStack {
            if options.background == .transparent { TransparencyGrid() }
            else { Color(nsColor: CoreGraphicsDiagramPainter.color(session.theme.background)) }
            if let preview {
                Image(nsImage: preview).resizable().scaledToFit().padding(12)
            } else if let previewError {
                Text(previewError).font(.callout).foregroundStyle(.secondary).padding(24)
            } else { ProgressView() }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator, lineWidth: 1))
    }

    private var controls: some View {
        let language = model.resolvedLanguage
        return Form {
            Section("文件格式".studioLocalized) {
                Picker("格式".studioLocalized, selection: $options.format) {
                    ForEach(DiagramExportFormat.allCases) { format in Text(format.title).tag(format) }
                }
                Text(formatDescription).font(.caption).foregroundStyle(.secondary)
            }
            Section("画布".studioLocalized) {
                Picker("背景".studioLocalized, selection: $options.background) {
                    ForEach(DiagramExportBackground.allCases) { background in
                        Text(StudioLocalization.text(background.title, language: language)).tag(background)
                            .disabled(background == .transparent && !options.format.supportsTransparency)
                    }
                }
                Picker("四周留白".studioLocalized, selection: $options.padding) {
                    ForEach([0.0, 8, 16, 24, 32], id: \.self) { value in Text(String(format: StudioLocalization.text("%ld 点", language: language), Int(value))).tag(value) }
                }
                if options.background == .transparent {
                    Text("仅移除画布底色，节点填充和线内文字底衬保留。".studioLocalized)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section(options.format.isVector ? "输出尺寸".studioLocalized : "图片尺寸".studioLocalized) {
                if !options.format.isVector {
                    Picker("倍率".studioLocalized, selection: $options.scale) {
                        ForEach([1.0, 2, 3, 4], id: \.self) { value in Text("\(Int(value))×").tag(value) }
                    }
                    .pickerStyle(.segmented).labelsHidden()
                }
                Text(exportSummary).font(.caption).foregroundStyle(.secondary)
                if options.format == .jpeg {
                    LabeledContent("质量".studioLocalized, value: "\(Int((options.quality * 100).rounded()))％")
                    Slider(value: $options.quality, in: 0.1...1, step: 0.01)
                        .accessibilityLabel("JPEG 压缩质量".studioLocalized)
                }
            }
        }
        .formStyle(.grouped)
        .disabled(saving)
    }

    private var formatDescription: String {
        switch options.format {
        case .png: "无损图片，支持透明背景，适合文档与演示。".studioLocalized
        case .jpeg: "体积较小的有损图片，可调整质量，不支持透明背景。".studioLocalized
        case .tiff: "无损图片，支持透明背景，适合后续图片处理。".studioLocalized
        case .svg: "可缩放矢量图，支持透明背景，放大仍保持清晰。".studioLocalized
        case .pdf: "单页矢量文档，适合打印与报告，不受图片倍率影响。".studioLocalized
        }
    }
}

private struct TransparencyGrid: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            for row in 0...Int(size.height / 12) {
                for column in 0...Int(size.width / 12) where (row + column).isMultiple(of: 2) {
                    context.fill(Path(CGRect(x: column * 12, y: row * 12, width: 12, height: 12)), with: .color(.gray.opacity(0.16)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
