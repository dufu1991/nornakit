import Foundation

enum SpatialDataDiagrams {
    static func sankey(_ source: String) throws -> DiagramScene {
        struct Link { let from: Int; let to: Int; let value: Double }
        var names: [String] = [], links: [Link] = []
        for line in DiagramSyntax.lines(source).dropFirst() {
            let values = DiagramSyntax.split(line.text).map { DiagramSyntax.label($0).replacingOccurrences(of: "\"\"", with: "\"") }
            guard values.count == 3, !values[0].isEmpty, !values[1].isEmpty, values[0] != values[1] else { throw line.error("桑基图需要来源、目标和正数权重三列 CSV。", code: "syntax") }
            for value in values.prefix(2) where !names.contains(value) { names.append(value) }
            links.append(Link(from: names.firstIndex(of: values[0])!, to: names.firstIndex(of: values[1])!, value: try DiagramSyntax.number(values[2], line: line, positive: true)))
        }
        try DiagramSyntax.nonempty(links.count, kind: .sankey)
        guard names.count <= 100 else { throw DiagramRenderError(message: "桑基图最多支持 100 个节点。", code: "limit") }
        var degree = names.indices.map { index in links.filter { $0.to == index }.count }, ranks = Array(repeating: 0, count: names.count)
        var queue = names.indices.filter { degree[$0] == 0 }, cursor = 0
        while cursor < queue.count {
            let node = queue[cursor]; cursor += 1
            for link in links where link.from == node { ranks[link.to] = max(ranks[link.to], ranks[node] + 1); degree[link.to] -= 1; if degree[link.to] == 0 { queue.append(link.to) } }
        }
        guard queue.count == names.count else { throw DiagramRenderError(message: "桑基图当前不支持循环流量。", code: "unsupported-syntax") }
        let values = names.indices.map { node in max(links.filter { $0.from == node }.reduce(0) { $0 + $1.value }, links.filter { $0.to == node }.reduce(0) { $0 + $1.value }) }
        let layers = (0...ranks.max()!).map { rank in names.indices.filter { ranks[$0] == rank } }
        let height = max(380, CGFloat(layers.map(\.count).max()!) * 56), width = max(760, CGFloat(layers.count) * 220), b = SceneBuilder(.sankey)
        let scale = layers.map { layer in (height - 80 - CGFloat(layer.count - 1) * 20) / CGFloat(layer.reduce(0) { $0 + values[$1] }) }.min()!
        var rects = Array(repeating: CGRect.zero, count: names.count)
        for (rank, layer) in layers.enumerated() {
            let h = layer.reduce(CGFloat(0)) { $0 + CGFloat(values[$1]) * scale } + CGFloat(layer.count - 1) * 20
            var y = (height - h) / 2
            for node in layer { rects[node] = CGRect(x: 80 + CGFloat(rank) / CGFloat(max(1, layers.count - 1)) * (width - 160), y: y, width: 16, height: CGFloat(values[node]) * scale); y += rects[node].height + 20 }
        }
        var outgoing = Array(repeating: CGFloat(0), count: names.count), incoming = outgoing
        for link in links {
            let a = rects[link.from], z = rects[link.to], thickness = CGFloat(link.value) * scale
            let ay = a.minY + outgoing[link.from], zy = z.minY + incoming[link.to], middle = (a.maxX + z.minX) / 2
            b.path([.move(CGPoint(x: a.maxX, y: ay)), .cubic(CGPoint(x: middle, y: ay), CGPoint(x: middle, y: zy), CGPoint(x: z.minX, y: zy)),
                    .line(CGPoint(x: z.minX, y: zy + thickness)), .cubic(CGPoint(x: middle, y: zy + thickness), CGPoint(x: middle, y: ay + thickness), CGPoint(x: a.maxX, y: ay + thickness)), .close],
                   fill: .series(link.from), stroke: .none, opacity: 0.3)
            outgoing[link.from] += thickness; incoming[link.to] += thickness
        }
        for i in names.indices {
            b.rect(rects[i], fill: .series(i), stroke: .none, radius: 1, id: "sankey-\(i)", label: "\(names[i]): \(DataCharts.format(values[i]))")
            let right = ranks[i] < layers.count - 1
            b.text(names[i], CGRect(x: right ? rects[i].maxX + 6 : rects[i].minX - 156, y: rects[i].midY - 12, width: 150, height: 24), size: 13, align: right ? .leading : .trailing)
        }
        return b.scene(width: width + 20, height: height)
    }

    static func venn(_ source: String) throws -> DiagramScene {
        struct SetValue { let id: String; let label: String; let value: Double; let showValue: Bool }
        var sets: [SetValue] = [], intersections: [([String], Double, String)] = []
        var current: [String] = [], texts: [(String, [String], String)] = []
        let lines = DiagramSyntax.lines(source)
        for line in lines.dropFirst() {
            if line.text.hasPrefix("title ") { continue }
            if let m = DiagramSyntax.match(#"^set\s+(\w+)(?:\[([^\]]+)\])?(?:\s*:\s*([-+\d.eE]+))?$"#, line.text) {
                guard !sets.contains(where: { $0.id == m[1] }) else { throw line.error("集合标识符重复。", code: "semantic") }
                sets.append(SetValue(id: m[1], label: m[2].isEmpty ? m[1] : DiagramSyntax.label(m[2]), value: m[3].isEmpty ? 10 : try DiagramSyntax.number(m[3], line: line, positive: true), showValue: !m[3].isEmpty))
                current = [m[1]]
            } else if let m = DiagramSyntax.match(#"^union\s+([\w, ]+?)(?:\[([^\]]+)\])?(?:\s*:\s*([-+\d.eE]+))?$"#, line.text) {
                let ids = DiagramSyntax.split(m[1]), value = m[3].isEmpty ? 10 / pow(Double(DiagramSyntax.split(m[1]).count), 2) : try DiagramSyntax.number(m[3], line: line)
                guard ids.count >= 2, Set(ids).count == ids.count, value >= 0 else { throw line.error("交集需要至少两个不同集合及非负数值。", code: "semantic") }
                intersections.append((ids, value, m[2].isEmpty ? (m[3].isEmpty ? "" : DataCharts.format(value)) : DiagramSyntax.label(m[2])))
                current = ids
            } else if let m = DiagramSyntax.match(#"^text\s+(\w+)(?:\[([^\]]+)\])?$"#, line.text) {
                guard !current.isEmpty, !texts.contains(where: { $0.0 == m[1] }) else { throw line.error("区域文字需要前置集合或交集，并使用独立标识符。", code: "semantic") }
                texts.append((m[1], current, m[2].isEmpty ? m[1] : DiagramSyntax.label(m[2])))
            } else { throw line.error("韦恩图当前支持 set、union 和区域 text 声明。") }
        }
        guard (1...3).contains(sets.count) else { throw DiagramRenderError(message: "韦恩图当前支持 1 到 3 个集合。", code: "unsupported-syntax") }
        for (ids, value, _) in intersections {
            let values = ids.compactMap { id in sets.first { $0.id == id }?.value }
            guard values.count == ids.count, value <= values.min()! else { throw DiagramRenderError(message: "交集引用未知集合或大于集合本身。", code: "semantic") }
        }
        let scale = 150 / sqrt(sets.map(\.value).max()! / .pi), radii = sets.map { CGFloat(sqrt($0.value / .pi) * scale) }
        let desired: (Int, Int) -> CGFloat = { a, z in
            let fallback = intersections.contains { $0.0.count == 3 } ? min(sets[a].value, sets[z].value) * 0.3 : 0
            let value = intersections.first { Set($0.0) == Set([sets[a].id, sets[z].id]) }?.1 ?? fallback
            let target = CGFloat(value * scale * scale), r = radii[a], s = radii[z]
            var low = abs(r - s), high = r + s
            for _ in 0..<70 {
                let d = (low + high) / 2
                let aa = acos(min(1, max(-1, (d * d + r * r - s * s) / (2 * d * r))))
                let bb = acos(min(1, max(-1, (d * d + s * s - r * r) / (2 * d * s))))
                let area = r * r * aa + s * s * bb - 0.5 * sqrt(max(0, (-d + r + s) * (d + r - s) * (d - r + s) * (d + r + s)))
                if area > target { low = d } else { high = d }
            }
            return (low + high) / 2
        }
        var centers = [CGPoint.zero]
        if sets.count > 1 { centers.append(CGPoint(x: desired(0, 1), y: 0)) }
        if sets.count > 2 {
            let a = max(0.001, centers[1].x), z = desired(0, 2), c = desired(1, 2), x = (z * z + a * a - c * c) / (2 * a)
            guard abs(x) <= z + 0.1 else { throw DiagramRenderError(message: "这些交集权重无法表示为三个圆形集合。", code: "semantic") }
            centers.append(CGPoint(x: x, y: sqrt(max(0, z * z - x * x))))
        }
        var bounds = CGRect.null
        for i in sets.indices { bounds = bounds.union(CGRect(x: centers[i].x - radii[i], y: centers[i].y - radii[i], width: radii[i] * 2, height: radii[i] * 2)) }
        let width = max(460, bounds.width + 80), b = SceneBuilder(.venn), top = b.title(DiagramSyntax.title(lines), width: width)
        centers = centers.map { CGPoint(x: $0.x - bounds.minX + (width - bounds.width) / 2, y: $0.y - bounds.minY + top + 28) }
        let centroid = CGPoint(x: centers.reduce(0) { $0 + $1.x } / CGFloat(centers.count), y: centers.reduce(0) { $0 + $1.y } / CGFloat(centers.count))
        for i in sets.indices {
            let r = CGRect(x: centers[i].x - radii[i], y: centers[i].y - radii[i], width: radii[i] * 2, height: radii[i] * 2)
            b.ellipse(r, fill: .series(i), stroke: .series(i), opacity: 0.3, id: sets[i].id, label: sets[i].label)
            var labelFrame = CGRect(x: r.minX, y: r.minY + 12, width: r.width, height: 48)
            if sets.count == 3 {
                let dx = centers[i].x - centroid.x, dy = centers[i].y - centroid.y, length = hypot(dx, dy)
                if length > 0.001 {
                    let labelCenter = CGPoint(x: centers[i].x + dx / length * radii[i] * 0.55, y: centers[i].y + dy / length * radii[i] * 0.55)
                    let labelWidth = min(160, max(1, r.width - 16))
                    labelFrame = CGRect(x: labelCenter.x - labelWidth / 2, y: labelCenter.y - 24, width: labelWidth, height: 48)
                }
            }
            b.text(sets[i].label + (sets[i].showValue ? "\n" + DataCharts.format(sets[i].value) : ""), labelFrame, size: 14, bold: true)
        }
        for (ids, _, label) in intersections {
            let positions = ids.map { id in centers[sets.firstIndex { $0.id == id }!] }
            let x = positions.reduce(0) { $0 + $1.x } / CGFloat(positions.count), y = positions.reduce(0) { $0 + $1.y } / CGFloat(positions.count)
            b.text(label, CGRect(x: x - 80, y: y - 12, width: 160, height: 24), size: 14)
        }
        var rows: [String: Int] = [:]
        for (id, ids, label) in texts {
            let key = ids.sorted().joined(separator: ","), row = rows[key, default: 0]
            rows[key] = row + 1
            let positions = ids.map { id in centers[sets.firstIndex { $0.id == id }!] }
            let x = positions.reduce(0) { $0 + $1.x } / CGFloat(positions.count), y = positions.reduce(0) { $0 + $1.y } / CGFloat(positions.count)
            b.text(label, CGRect(x: x - 70, y: y + 22 + CGFloat(row) * 26, width: 140, height: 24), size: 13)
            b.primitives[b.primitives.count - 1].id = id; b.primitives[b.primitives.count - 1].label = label
        }
        return b.scene(width: width, height: top + bounds.height + 64)
    }

    static func cynefin(_ source: String) throws -> DiagramScene {
        let keys = ["complex", "complicated", "clear", "chaotic", "confusion"], descriptions = ["Probe → Sense → Respond", "Sense → Analyze → Respond", "Sense → Categorize → Respond", "Act → Sense → Respond", "Disorder"]
        let lines = DiagramSyntax.lines(source), b = SceneBuilder(.cynefin)
        var items: [String: [String]] = [:], current: String?, transitions: [(String, String, String)] = []
        for line in lines.dropFirst() {
            let s = line.text
            if s.hasPrefix("title ") { continue }
            if keys.contains(s) { current = s; if items[s] == nil { items[s] = [] }; continue }
            if let m = DiagramSyntax.match(#"^(complex|complicated|clear|chaotic|confusion)\s*-->\s*(complex|complicated|clear|chaotic|confusion)(?:\s*:\s*(.*))?$"#, s) { if m[1] != m[2] { transitions.append((m[1], m[2], DiagramSyntax.label(m[3]))) }; continue }
            guard let domain = current, s.first == "\"", s.last == "\"" else { throw line.error("Cynefin 条目需要所属领域和双引号标签。", code: "syntax") }
            items[domain, default: []].append(DiagramSyntax.label(s))
        }
        let centerHeight = max(72, CGFloat(items["confusion"]?.count ?? 0) * 44 + 68)
        let centerGap = max(20, centerHeight - 32)
        let cellHeight = max(230, CGFloat(items.values.map(\.count).max() ?? 0) * 52 + 80), width: CGFloat = 900
        let top = b.title(DiagramSyntax.title(lines), width: width)
        let frames = [CGRect(x: 20, y: top, width: 420, height: cellHeight), CGRect(x: 460, y: top, width: 420, height: cellHeight),
                      CGRect(x: 460, y: top + cellHeight + centerGap, width: 420, height: cellHeight), CGRect(x: 20, y: top + cellHeight + centerGap, width: 420, height: cellHeight),
                      CGRect(x: 310, y: top + cellHeight - 16, width: 280, height: centerHeight)]
        for i in keys.indices {
            let r = frames[i]
            b.rect(r, fill: .series(i), stroke: .border, radius: 12, opacity: i == 4 ? 0.6 : 0.08)
            b.text(keys[i].capitalized, CGRect(x: r.minX + 8, y: r.minY + 10, width: r.width - 16, height: 24), size: 17, bold: true)
            b.text(descriptions[i], CGRect(x: r.minX + 8, y: r.minY + 36, width: r.width - 16, height: 22), size: 12, color: .muted)
            do {
                for (j, item) in (items[keys[i]] ?? []).enumerated() { b.box(item, CGRect(x: r.minX + 20, y: r.minY + 70 + CGFloat(j) * (i == 4 ? 44 : 52), width: r.width - 40, height: 40), fill: .background, id: "\(keys[i])-\(j)", size: 14) }
            }
        }
        for (from, to, label) in transitions {
            let a = frames[keys.firstIndex(of: from)!], z = frames[keys.firstIndex(of: to)!]
            b.line([CGPoint(x: a.midX, y: a.midY), CGPoint(x: z.midX, y: z.midY)], color: .accent, width: 1.5, arrow: true)
            if !label.isEmpty { b.box(label, CGRect(x: (a.midX + z.midX) / 2 - 100, y: (a.midY + z.midY) / 2 - 14, width: 200, height: 28), fill: .background, size: 12) }
        }
        return b.scene(width: width, height: top + cellHeight * 2 + centerGap + 20)
    }

    static func wardley(_ source: String) throws -> DiagramScene {
        struct Component { let label: String; let x: Double; let y: Double; let anchor: Bool }
        let lines = DiagramSyntax.lines(source), b = SceneBuilder(.wardley)
        var components: [Component] = [], links: [(String, String)] = [], evolutions: [(String, Double)] = []
        let fraction: (String, SourceLine) throws -> Double = { text, line in
            let value = try DiagramSyntax.number(text, line: line)
            guard value >= 0, value <= 100 else { throw line.error("地图坐标需要 0 到 1 的小数或 0 到 100 的百分数。", code: "semantic") }
            return value <= 1 ? value : value / 100
        }
        for line in lines.dropFirst() {
            let s = line.text
            if s.hasPrefix("title ") { continue }
            if let m = DiagramSyntax.match(#"^(anchor|component)\s+(.+?)\s*\[([^,]+),([^\]]+)\]$"#, s) {
                guard !components.contains(where: { $0.label == m[2] }) else { throw line.error("组件名称重复。", code: "semantic") }
                components.append(Component(label: m[2], x: try fraction(m[4], line), y: try fraction(m[3], line), anchor: m[1] == "anchor"))
            } else if let m = DiagramSyntax.match(#"^(.+?)\s*->\s*(.+)$"#, s) { links.append((m[1], m[2])) }
            else if let m = DiagramSyntax.match(#"^evolve\s+(.+?)\s+([\d.]+)$"#, s) { evolutions.append((m[1], try fraction(m[2], line))) }
            else { throw line.error("暂不支持这条 Wardley 图语法。") }
        }
        try DiagramSyntax.nonempty(components.count, kind: .wardley)
        let width: CGFloat = 860, top = b.title(DiagramSyntax.title(lines), width: width), plot = CGRect(x: 72, y: top + 16, width: 740, height: 440)
        b.line([CGPoint(x: plot.minX, y: plot.minY), CGPoint(x: plot.minX, y: plot.maxY), CGPoint(x: plot.maxX, y: plot.maxY)], color: .border)
        for (i, label) in ["Genesis", "Custom-built", "Product", "Commodity"].enumerated() {
            let x = plot.minX + CGFloat(i) * plot.width / 4
            b.line([CGPoint(x: x, y: plot.minY), CGPoint(x: x, y: plot.maxY)], color: .border, dash: [3, 4])
            b.text(label, CGRect(x: x, y: plot.maxY + 8, width: plot.width / 4, height: 28), size: 13, color: .muted)
        }
        let point: (Component) -> CGPoint = { CGPoint(x: plot.minX + CGFloat($0.x) * plot.width, y: plot.maxY - CGFloat($0.y) * plot.height) }
        for (from, to) in links {
            guard let a = components.first(where: { $0.label == from }), let z = components.first(where: { $0.label == to }) else { throw DiagramRenderError(message: "地图关系引用了未知组件。", code: "semantic") }
            b.line([point(a), point(z)], color: .line)
        }
        for (name, target) in evolutions {
            guard let component = components.first(where: { $0.label == name }) else { throw DiagramRenderError(message: "演化路径引用了未知组件。", code: "semantic") }
            let a = point(component), z = CGPoint(x: plot.minX + CGFloat(target) * plot.width, y: a.y)
            b.line([a, z], color: .accent, dash: [4, 4], arrow: true)
        }
        for (i, component) in components.enumerated() {
            let p = point(component)
            if component.anchor { b.rect(CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10), fill: .foreground, stroke: .none, radius: 0, id: "component-\(i)", label: component.label) }
            else { b.ellipse(CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10), fill: .background, stroke: .foreground, id: "component-\(i)", label: component.label) }
            b.text(component.label, CGRect(x: min(max(p.x - 80, plot.minX), plot.maxX - 160), y: p.y + 8, width: 160, height: 24), size: 13)
        }
        b.text("Visible", CGRect(x: 4, y: plot.minY - 20, width: 68, height: 24), size: 12, color: .muted)
        b.text("Invisible", CGRect(x: 4, y: plot.maxY - 10, width: 68, height: 24), size: 12, color: .muted)
        return b.scene(width: width, height: plot.maxY + 60)
    }
}
