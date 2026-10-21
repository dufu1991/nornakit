import Foundation

struct MermaidDocument {
    let body: String
    let title: String?

    static func prepare(_ source: String) throws -> MermaidDocument {
        var lines = source.components(separatedBy: .newlines)
        var title: String?
        if let first = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
           lines[first].trimmingCharacters(in: .whitespaces) == "---" {
            guard let end = lines.indices.dropFirst(first + 1).first(where: { lines[$0].trimmingCharacters(in: .whitespaces) == "---" }) else {
                throw DiagramRenderError(message: "Front matter 缺少结束分隔符。", code: "syntax", line: first + 1)
            }
            var section = "", inConfig = false
            for index in (first + 1)..<end {
                let raw = lines[index], value = raw.trimmingCharacters(in: .whitespaces)
                if value.isEmpty || value.hasPrefix("#") { continue }
                let line = SourceLine(text: value, raw: raw, number: index + 1)
                guard let field = DiagramSyntax.match(#"^([\w]+)\s*:\s*(.*)$"#, value) else { throw line.error("暂不支持这条 Front matter 语法。") }
                let key = field[1], argument = DiagramSyntax.label(field[2]).trimmingCharacters(in: CharacterSet(charactersIn: "'"))
                if line.indent == 0 {
                    if key == "title" { title = argument; inConfig = false }
                    else if key == "config", argument.isEmpty { inConfig = true; section = "" }
                    else { throw line.error("暂不支持 Front matter 字段 \(key)。", code: "unsupported-configuration") }
                } else if inConfig {
                    if line.indent == 2 {
                        if ["theme", "look"].contains(key), !argument.isEmpty { continue }
                        if key == "layout", argument == "dagre" { continue }
                        if ["class", "sequence", "flowchart"].contains(key), argument.isEmpty { section = key; continue }
                    } else if line.indent == 4 {
                        if section == "class", key == "hierarchicalNamespaces", argument == "false" { continue }
                        if section == "sequence", key == "wrap", argument == "true" { continue }
                        if section == "flowchart", key == "htmlLabels", argument == "false" { continue }
                    }
                    throw line.error("配置项 \(section.isEmpty ? key : section + "." + key) 尚未支持。", code: "unsupported-configuration")
                } else { throw line.error("Front matter 缩进无效。", code: "syntax") }
            }
            for index in first...end { lines[index] = "" }
        }
        for (index, raw) in lines.enumerated() where raw.trimmingCharacters(in: .whitespaces).hasPrefix("%%{") {
            throw DiagramRenderError(message: "init 配置指令尚未支持。", code: "unsupported-configuration", line: index + 1)
        }
        return MermaidDocument(body: lines.joined(separator: "\n"), title: title)
    }
}

extension DiagramScene {
    func addingTitle(_ title: String?) -> DiagramScene {
        guard let title, !title.isEmpty else { return self }
        let width = max(240, size.width), lines = TextMeasurement.lines(title, maxWidth: width - 32)
        let dy = CGFloat(lines.count) * 28 + 20, dx = (width - size.width) / 2
        let primitives = primitives.map { primitive in
            let copy = primitive
            return ScenePrimitive(geometry: copy.geometry.offsetBy(dx: dx, dy: dy), style: copy.style, id: copy.id, label: copy.label)
        } + [ScenePrimitive(geometry: .text(SceneText(text: lines.joined(separator: "\n"), frame: CGRect(x: 16, y: 8, width: width - 32, height: dy - 16), size: 20, bold: true)))]
        return DiagramScene(size: CGSize(width: width, height: size.height + dy), nodes: nodes.map { var node = $0; node.frame = node.frame.offsetBy(dx: dx, dy: dy); return node },
            edges: edges.map { var edge = $0; edge.points = edge.points.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }; edge.labelFrame = edge.labelFrame.offsetBy(dx: dx, dy: dy); return edge },
            groups: groups.map { var group = $0; group.frame = group.frame.offsetBy(dx: dx, dy: dy); group.titleFrame = group.titleFrame.offsetBy(dx: dx, dy: dy); return group }, primitives: primitives, kind: kind)
    }
}

extension VectorGeometry {
    func offsetBy(dx: CGFloat, dy: CGFloat) -> VectorGeometry {
        let shift: (CGPoint) -> CGPoint = { CGPoint(x: $0.x + dx, y: $0.y + dy) }
        switch self {
        case .rectangle(let r, let radius): return .rectangle(r.offsetBy(dx: dx, dy: dy), radius)
        case .ellipse(let r): return .ellipse(r.offsetBy(dx: dx, dy: dy))
        case .text(let text): return .text(SceneText(text: text.text, frame: text.frame.offsetBy(dx: dx, dy: dy), size: text.size, color: text.color, alignment: text.alignment, bold: text.bold, mono: text.mono))
        case .path(let commands): return .path(commands.map { command in
            switch command {
            case .move(let p): return .move(shift(p))
            case .line(let p): return .line(shift(p))
            case .quad(let a, let z): return .quad(shift(a), shift(z))
            case .cubic(let a, let b, let z): return .cubic(shift(a), shift(b), shift(z))
            case .close: return .close
            }
        })
        }
    }
}
