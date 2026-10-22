import Foundation

struct HierarchyItem {
    let id: Int
    let label: String
    let parent: Int?
    let depth: Int
    let weight: Double?
}

enum HierarchyDiagrams {
    static func parse(_ source: String, kind: DiagramKind) throws -> [HierarchyItem] {
        var items: [HierarchyItem] = [], stack: [(Int, Int)] = []
        for line in DiagramSyntax.lines(source).dropFirst() {
            let s = line.text
            if s.hasPrefix("title ") { continue }
            guard !s.hasPrefix("::"), !s.contains("@{"), !s.contains(":::"), !s.contains(" icon("), !s.contains(" ## ") else { throw line.error("树形图暂不支持图标、样式或元数据指令。") }
            guard kind != .treeView || !s.contains("├") && !s.contains("└") && !s.hasPrefix("│") else { throw line.error("目录树当前支持空格缩进格式。") }
            while let last = stack.last, line.indent <= last.1 { stack.removeLast() }
            guard stack.count < 16 else { throw line.error("树形结构最多嵌套 16 层。", code: "limit") }
            let title: String, weight: Double?
            if kind == .treemap {
                guard let m = DiagramSyntax.match(#"^"([^"]+)"(?:\s*:\s*([-+\d.eE]+))?$"#, s) else { throw line.error("矩形树图条目需要双引号标签和可选的正数权重。", code: "syntax") }
                title = m[1]; weight = m[2].isEmpty ? nil : try DiagramSyntax.number(m[2], line: line, positive: true)
            } else {
                if let m = DiagramSyntax.match(#"^\w+(?:\(\((.*?)\)\)|\[(.*?)\]|\((.*?)\)|\{(.*?)\})$"#, s) { title = DiagramSyntax.label(m.dropFirst().first(where: { !$0.isEmpty }) ?? s) }
                else { title = DiagramSyntax.label(s) }
                weight = nil
            }
            let item = HierarchyItem(id: items.count, label: title, parent: stack.last?.0, depth: stack.count, weight: weight)
            items.append(item); stack.append((item.id, line.indent))
        }
        try DiagramSyntax.nonempty(items.count, kind: kind)
        return items
    }

    static func tree(_ source: String) throws -> DiagramScene {
        let items = try parse(source, kind: .treeView), b = SceneBuilder(.treeView)
        let width = max(420, (items.map { CGFloat($0.depth) * 28 + TextMeasurement.width($0.label) + 78 }.max() ?? 0))
        let row: CGFloat = 30
        for item in items {
            let x = 30 + CGFloat(item.depth) * 28, y = 22 + CGFloat(item.id) * row
            if let parent = item.parent {
                let px = x - 18, py = 22 + CGFloat(parent) * row + 24
                b.line([CGPoint(x: px, y: py), CGPoint(x: px, y: y + 12), CGPoint(x: x - 5, y: y + 12)], color: .border)
            }
            if item.label.hasSuffix("/") {
                b.rect(CGRect(x: x, y: y + 5, width: 15, height: 12), fill: .surfaceAlt, radius: 2, id: "tree-\(item.id)", label: item.label)
                b.line([CGPoint(x: x + 1, y: y + 5), CGPoint(x: x + 1, y: y + 2), CGPoint(x: x + 7, y: y + 2), CGPoint(x: x + 10, y: y + 5)], color: .border)
            } else { b.rect(CGRect(x: x + 2, y: y + 2, width: 11, height: 16), fill: .background, radius: 1, id: "tree-\(item.id)", label: item.label) }
            b.text(item.label, CGRect(x: x + 24, y: y, width: width - x - 36, height: 24), size: 14, align: .leading, mono: true)
        }
        return b.scene(width: width, height: CGFloat(items.count) * row + 44)
    }

    static func mindmap(_ source: String, options: DiagramLayoutOptions = .init()) throws -> DiagramScene {
        let items = try parse(source, kind: .mindmap)
        guard items.filter({ $0.parent == nil }).count == 1 else { throw DiagramRenderError(message: "思维导图必须只有一个根节点。", code: "semantic") }
        let naturalWidth = CGFloat(items.map(\.depth).max() ?? 0) * 440 + 220
        if let width = options.maxWidth, width < naturalWidth {
            return compactMindmap(items, width: width)
        }
        let children = Dictionary(grouping: items.filter { $0.parent != nil }, by: { $0.parent! })
        var heights: [Int: CGFloat] = [:]
        func height(_ id: Int) -> CGFloat {
            if let value = heights[id] { return value }
            let kids = children[id] ?? []
            let ownHeight = max(56, CGFloat(TextMeasurement.lines(items[id].label, maxWidth: 154).count) * 22 + 16)
            let value = max(ownHeight, kids.reduce(0) { $0 + height($1.id) } + CGFloat(max(0, kids.count - 1)) * 24)
            heights[id] = value; return value
        }
        let branches = children[0] ?? [], left = Array(branches.prefix((branches.count + 1) / 2)), right = Array(branches.dropFirst(left.count))
        let maxDepth = items.map(\.depth).max() ?? 0, rootX = CGFloat(maxDepth) * 220 + 110
        let leftH = left.reduce(CGFloat(0)) { $0 + height($1.id) + 24 }, rightH = right.reduce(CGFloat(0)) { $0 + height($1.id) + 24 }
        let totalH = max(130, max(leftH, rightH) + 60), width = rootX * 2
        let b = SceneBuilder(.mindmap)
        let root = CGRect(x: rootX - 85, y: totalH / 2 - 28, width: 170, height: 56)
        func draw(_ item: HierarchyItem, x: CGFloat, centerY: CGFloat, side: CGFloat, branch: Int, parentFrame: CGRect) {
            let text = TextMeasurement.lines(item.label, maxWidth: 154).joined(separator: "\n")
            let h = max(46, CGFloat(text.components(separatedBy: "\n").count) * 22 + 16), r = CGRect(x: x - 92, y: centerY - h / 2, width: 184, height: h)
            let a = CGPoint(x: side > 0 ? parentFrame.maxX : parentFrame.minX, y: parentFrame.midY), z = CGPoint(x: side > 0 ? r.minX : r.maxX, y: r.midY)
            b.path([.move(a), .cubic(CGPoint(x: (a.x + z.x) / 2, y: a.y), CGPoint(x: (a.x + z.x) / 2, y: z.y), z)], stroke: .series(branch), width: 1.5)
            b.rect(r, fill: .series(branch), stroke: .series(branch), opacity: 0.16, id: "mindmap-\(item.id)", label: item.label)
            b.text(text, r.insetBy(dx: 10, dy: 6), size: 14)
            let kids = children[item.id] ?? []
            var top = centerY - height(item.id) / 2
            for child in kids { let childHeight = height(child.id); draw(child, x: x + side * 220, centerY: top + childHeight / 2, side: side, branch: branch, parentFrame: r); top += childHeight + 24 }
        }
        for (side, nodes, extent) in [(CGFloat(-1), left, leftH), (CGFloat(1), right, rightH)] {
            var y = (totalH - extent) / 2 + 12
            for item in nodes { let h = height(item.id); draw(item, x: rootX + side * 240, centerY: y + h / 2, side: side, branch: item.id - 1, parentFrame: root); y += h + 24 }
        }
        b.box(items[0].label, root, fill: .surfaceAlt, radius: 28, id: "mindmap-root")
        return b.scene(width: max(420, width), height: totalH)
    }

    /// A narrow container uses an indented outline, retaining full size text and every branch.
    private static func compactMindmap(_ items: [HierarchyItem], width: CGFloat) -> DiagramScene {
        let builder = SceneBuilder(.mindmap)
        let children = Dictionary(grouping: items.filter { $0.parent != nil }, by: { $0.parent! })
        let maxDepth = items.map(\.depth).max() ?? 0
        let indent = min(28, max(8, (width - 100) / CGFloat(max(1, maxDepth + 1))))
        var frames: [Int: CGRect] = [:], top: CGFloat = 8
        for item in items {
            let x = 16 + CGFloat(item.depth) * indent
            let labelWidth = max(32, width - x - 28)
            let lines = TextMeasurement.lines(item.label, maxWidth: labelWidth, size: 14)
            let h = max(46, CGFloat(lines.count) * 22 + 16)
            let measured = (lines.map { TextMeasurement.width($0, size: 14) }.max() ?? 0) + 20
            frames[item.id] = CGRect(x: x, y: top, width: min(width - x - 8, max(84, measured)), height: h)
            top += h + 22
        }
        var branches: [Int: Int] = [0: 0]
        for item in items.dropFirst() {
            let parent = item.parent!, parentFrame = frames[parent]!, frame = frames[item.id]!
            let siblings = children[parent]!, position = siblings.firstIndex { $0.id == item.id }!
            // Later children use the outer lanes, so sibling and descendant branches remain planar.
            let lane = parentFrame.minX + indent * CGFloat(siblings.count - position) / CGFloat(siblings.count + 1)
            let start = NodeGeometry.anchor(shape: .rectangle, frame: parentFrame, side: 2, offset: lane - parentFrame.midX)
            let end = CGPoint(x: frame.minX, y: frame.midY)
            let branch = parent == 0 ? position : branches[parent]!
            branches[item.id] = branch
            builder.line([start, CGPoint(x: lane, y: end.y), end], color: .series(branch), width: 1.5)
        }
        for item in items {
            let frame = frames[item.id]!
            let lines = TextMeasurement.lines(item.label, maxWidth: frame.width - 20, size: 14)
            builder.rect(frame, fill: item.id == 0 ? .surfaceAlt : .series(branches[item.id]!),
                opacity: item.id == 0 ? 1 : 0.16, id: item.id == 0 ? "mindmap-root" : "mindmap-\(item.id)", label: item.label)
            builder.text(lines.joined(separator: "\n"), frame.insetBy(dx: 10, dy: 6), size: 14)
        }
        return builder.scene(width: width, height: top - 14)
    }

    static func treemap(_ source: String, options: DiagramLayoutOptions = .init()) throws -> DiagramScene {
        let items = try parse(source, kind: .treemap), b = SceneBuilder(.treemap)
        let children = Dictionary(grouping: items.filter { $0.parent != nil }, by: { $0.parent! })
        func weight(_ item: HierarchyItem) throws -> Double {
            if let kids = children[item.id] { return try kids.reduce(0) { try $0 + weight($1) } }
            guard let weight = item.weight else { throw DiagramRenderError(message: "叶节点 \(item.label) 缺少正数权重。", code: "semantic") }
            return weight
        }
        let weights = try Dictionary(uniqueKeysWithValues: items.map { ($0.id, try weight($0)) })
        let width = options.width(820)
        let top = b.title(DiagramSyntax.title(DiagramSyntax.lines(source)), width: width)
        func tile(_ siblings: [HierarchyItem], rect: CGRect, depth: Int, series: Int) {
            let total = siblings.reduce(0) { $0 + weights[$1.id]! }, horizontal = rect.width >= rect.height
            var cursor = horizontal ? rect.minX : rect.minY
            for (index, item) in siblings.enumerated() {
                let length = (horizontal ? rect.width : rect.height) * CGFloat(weights[item.id]! / total)
                let cell = horizontal ? CGRect(x: cursor, y: rect.minY, width: length, height: rect.height) : CGRect(x: rect.minX, y: cursor, width: rect.width, height: length)
                cursor += length
                let r = cell.insetBy(dx: 2, dy: 2), colorIndex = depth == 0 ? index : series
                guard r.width > 1, r.height > 1 else { continue }
                b.rect(r, fill: .series(colorIndex), stroke: .background, radius: 2, opacity: children[item.id] == nil ? 0.45 : 0.18, id: "treemap-\(item.id)", label: "\(item.label): \(DataCharts.format(weights[item.id]!))")
                if let kids = children[item.id], r.height > 40, r.width > 24 {
                    b.text(item.label, CGRect(x: r.minX + 6, y: r.minY + 3, width: r.width - 12, height: 24), size: 14, align: .leading, bold: true)
                    tile(kids, rect: CGRect(x: r.minX + 4, y: r.minY + 30, width: r.width - 8, height: r.height - 34), depth: depth + 1, series: colorIndex)
                } else if r.width > 60, r.height > 36 {
                    let label = TextMeasurement.lines("\(item.label)\n\(DataCharts.format(weights[item.id]!))", maxWidth: max(30, r.width - 12)).joined(separator: "\n")
                    b.text(label, r.insetBy(dx: 6, dy: 6), size: 13)
                }
            }
        }
        tile(items.filter { $0.parent == nil }, rect: CGRect(x: 12, y: top, width: width - 24, height: 440), depth: 0, series: 0)
        return b.scene(width: width, height: top + 452)
    }

    static func ishikawa(_ source: String) throws -> DiagramScene {
        let items = try parse(source, kind: .ishikawa)
        guard items.filter({ $0.parent == nil }).count == 1, items.allSatisfy({ $0.depth <= 2 }) else { throw DiagramRenderError(message: "鱼骨图当前支持一个结果、主因和次因三级结构。", code: "unsupported-syntax") }
        let causes = items.filter { $0.parent == 0 }, b = SceneBuilder(.ishikawa)
        let width = max(720, CGFloat((causes.count + 1) / 2) * 230 + 280), mid: CGFloat = 250
        b.line([CGPoint(x: 30, y: mid), CGPoint(x: width - 210, y: mid)], width: 2, arrow: true)
        b.box(items[0].label, CGRect(x: width - 205, y: mid - 35, width: 185, height: 70), fill: .surfaceAlt, radius: 12, id: "fish-effect")
        for (index, item) in causes.enumerated() {
            let sign: CGFloat = index.isMultiple(of: 2) ? -1 : 1, x = 100 + CGFloat(index / 2) * 230
            let end = CGPoint(x: x + 130, y: mid), start = CGPoint(x: x + 20, y: mid + sign * 150)
            b.line([start, end], color: .series(index), width: 1.5)
            b.text(item.label, CGRect(x: x - 30, y: start.y + (sign < 0 ? -36 : 10), width: 170, height: 28), size: 16, bold: true)
            let children = items.filter { $0.parent == item.id }
            for (i, child) in children.enumerated() {
                let t = CGFloat(i + 1) / CGFloat(children.count + 1), point = CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
                b.line([CGPoint(x: point.x - 76, y: point.y), point], color: .border)
                b.text(child.label, CGRect(x: point.x - 138, y: point.y - 28, width: 132, height: 24), size: 12, align: .leading)
            }
        }
        return b.scene(width: width, height: 500)
    }

    static func kanban(_ source: String, options: DiagramLayoutOptions = .init()) throws -> DiagramScene {
        let items = try parse(source, kind: .kanban), roots = items.filter { $0.parent == nil }, b = SceneBuilder(.kanban)
        let width = options.width(max(320, CGFloat(roots.count) * 240 + 24), minimum: 264), top = b.title(DiagramSyntax.title(DiagramSyntax.lines(source)), width: width)
        let columns = min(roots.count, max(1, Int((width - 24) / 240))), columnWidth = (width - 24) / CGFloat(columns)
        var rowTop = top, rowHeight: CGFloat = 0, height: CGFloat = 200
        for (i, root) in roots.enumerated() {
            if i > 0, i % columns == 0 { rowTop += rowHeight + 24; rowHeight = 0 }
            let cards = items.filter { $0.parent == root.id }, x = 16 + CGFloat(i % columns) * columnWidth, w = columnWidth - 16
            guard items.filter({ $0.depth > 1 }).isEmpty else { throw DiagramRenderError(message: "看板当前支持列与卡片两级结构。", code: "unsupported-syntax") }
            let h = max(180, 64 + CGFloat(cards.count) * 92)
            rowHeight = max(rowHeight, h)
            b.rect(CGRect(x: x, y: rowTop, width: w, height: h), fill: .surfaceAlt, stroke: .none, opacity: 0.5)
            b.rect(CGRect(x: x, y: rowTop, width: w, height: 4), fill: .series(i), stroke: .none, radius: 2)
            b.text("\(root.label)  \(cards.count)", CGRect(x: x + 12, y: rowTop + 12, width: w - 24, height: 28), size: 16, align: .leading, bold: true)
            for (j, card) in cards.enumerated() {
                let text = TextMeasurement.lines(card.label, maxWidth: w - 48).joined(separator: "\n")
                b.box(text, CGRect(x: x + 12, y: rowTop + 58 + CGFloat(j) * 92, width: w - 24, height: 76), fill: .background, id: "card-\(card.id)", size: 14)
            }
            height = max(height, rowTop + h + 16)
        }
        return b.scene(width: width, height: height)
    }
}
